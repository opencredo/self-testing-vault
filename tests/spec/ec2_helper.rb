# frozen_string_literal: true

require 'time'
require 'aws-sdk-ec2'
require 'aws-sdk-autoscaling'
require 'aws-sdk-elasticloadbalancing'

# Utility designed to make it easier to interact with an autoscaling group, such as destroying an instance and waiting
# for a replacement to spin up.
class AsgHelper
  def initialize(name)
    @ec2 = Aws::EC2::Client.new
    @asg = Aws::AutoScaling::Client.new
    @elb = Aws::ElasticLoadBalancing::Client.new
    @name = name || raise
    @elb_names = @asg.describe_load_balancers(auto_scaling_group_name: @name)
                     .load_balancers
                     .flat_map(&:load_balancer_name)
  end

  # Retrieve instance ids for all instances within this autoscaling group
  # @return [Array<String>] IDs of all instances within this autoscaling group
  def instances
    @ec2.describe_instances(filters: [{ name: 'tag:aws:autoscaling:groupName', values: [@name] }])
        .reservations
        .flat_map(&:instances)
        .reject { |i| i.state.name == 'terminated' }
        .map(&:instance_id)
  end

  # Terminate an instance and wait for it's replacement to start up and become healthy
  # @return [Array<String>] IP addresses of the replacement instance(s)
  def replace_instance(instance)
    existing_instances = instances
    kill_instance(instance)

    wait_until_instance_replaced(instance, existing_instances.length)
    instances - existing_instances
  end

  # Wait until the given instance is able to serve requests for the ELBs attached to this ASG.
  # @param [String] instance Instance that should be present in the ELBs attached to this ASG
  def wait_until_instance_in_elb(instance)
    expire_at = Time.now.utc + 5 * 60
    loop do
      puts "Waiting for instance #{instance} to be available in the ELB"

      current_state = @elb_names.map { |n| @elb.describe_instance_health(load_balancer_name: n) }
                                .flat_map(&:instance_states)
                                .select { |i| i.instance_id == instance }
                                .map(&:state)
      break if current_state.all? { |h| h == 'InService' }
      raise "Time out waiting for #{instance} to be in the ELB; current state is #{current_state}" \
          if Time.now.utc >= expire_at
      sleep 5
    end
  end

  protected

  # Retrieve the public IP address for an instance within this autoscaling group
  # @param [String] instance Instance ID to look up
  def instance_ip_address(instance)
    @ec2.describe_instances(
      instance_ids: [instance],
      filters: [{ name: 'tag:aws:autoscaling:groupName', values: [@name] }]
    )
        .reservations[0].instances[0].public_ip_address
  end

  private

  def kill_instance(instance)
    @ec2.terminate_instances(instance_ids: [instance])
  end

  def wait_until_instance_replaced(instance, instance_count)
    expire_at = Time.now.utc + 5 * 60
    loop do
      puts "Waiting for instance #{instance} to be replaced"

      current = instances
      break if !current.include?(instance) && current.length >= instance_count
      raise "Time out waiting for #{instance} to be replaced" if Time.now.utc >= expire_at
      sleep 5
    end
  end

  def elb_hosts
    @elb.describe_load_balancers(load_balancer_names: @elb_names).load_balancer_descriptions.map(&:dns_name)
  end
end
