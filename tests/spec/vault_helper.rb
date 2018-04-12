# frozen_string_literal: true

require 'base64'
require 'vault'
require 'securerandom'
require_relative 'ec2_helper'

# Utility designed to make it easier to manage a Vault cluster, e.g. initialising the cluster or unsealing instances.
class VaultHelper < AsgHelper
  attr_reader :failures

  # @param [String] name Name of the autoscaling group behind the Vault cluster
  # @param [String] url URL to access the Vault cluster
  # @param [String] ca_pem Public CA certificate that the Vault cluster HTTPS connection is protected by
  def initialize(name, url, ca_pem)
    super(name)
    @url = url || raise
    @ca_pem = Tempfile.new
    @ca_pem.write ca_pem
    @ca_pem.flush

    @random_string = SecureRandom.hex
    @failures = 0
  end

  # Initialise a Vault cluster by initialising it and unsealing all instances.
  def initialise_vault
    puts 'Setting up Vault'
    hosts = instances
    initialise_vault_instance(hosts.first)

    hosts.each do |instance|
      throw "Couldn't unseal #{instance}" unless unseal(instance)
    end

    wait_until_domain_available
  end

  def replace_instance(instance)
    super(instance)
      .each { |i| unseal(i) }
  end

  # Put arbitrary configuration into Vault, for later retrieval and verification.
  # @see #verify
  def configure
    puts 'Configuring Vault'
    vault = secure_vault
    vault.sys.mount('testing', 'kv', 'Mount used for testing purposes only')
    vault.logical.write('testing/test', value: @random_string)
  end

  # Verify that Vault has successfully retained the configuration already stored in it.
  # @see #configure
  def verify
    puts 'Verifying Vault'
    vault = secure_vault
    actual_secret = vault.logical.read('testing/test').data[:value]
    raise "Stored secret incorrect! Actual: #{actual_secret}, expected: #{@random_string}" \
      unless actual_secret == @random_string
  end

  # Begin asynchronously monitoring Vault to ensure that it continues to respond correctly.
  # @see #verify
  # @see #stop_monitor
  # @see #failures
  def start_monitor
    @thread = Thread.start { monitor }
  end

  # Stop asynchronously monitoring Vault
  # @see #start_monitor
  def stop_monitor
    @thread&.exit
  end

  private

  def wait_until_domain_available
    vault = secure_vault
    puts "Waiting for Vault at #{@url} to be resolvable by local DNS"
    vault.with_retries(Vault::HTTPConnectionError, attempts: 150) do
      puts 'Attempting to query Vault to check DNS'
      vault.sys.seal_status
    end
  end

  def monitor
    loop do
      begin
        verify
        sleep 5
      rescue StandardError => e
        puts "Failed when monitoring Vault: #{e}"
        @failures += 1
      end
    end
  end

  def unseal(instance)
    puts "Unsealing #{instance}"
    vault = insecure_vault(instance)
    # 150 attempts with ~2 seconds between is roughly 5 minutes
    status = vault.with_retries(StandardError, attempts: 150) do
      vault.sys.unseal(@unsealing_key)
    end

    wait_until_instance_in_elb(instance) unless status.sealed?
    !status.sealed?
  end

  def initialise_vault_instance(instance)
    puts "Initialising Vault through #{instance}"
    vault = insecure_vault(instance)
    # 150 attempts with ~2 seconds between is roughly 5 minutes
    response = vault.with_retries(StandardError, attempts: 150) do
      vault.sys.init(secret_shares: 1, secret_threshold: 1)
    end

    @unsealing_key = response.keys[0]
    @root_token = response.root_token
  end

  # @return [Vault::Client]
  def insecure_vault(instance)
    Vault::Client.new(address: "https://#{instance_ip_address(instance)}:8200", ssl_verify: false)
  end

  # @return [Vault::Client]
  def secure_vault
    Vault::Client.new(address: @url, token: @root_token, ssl_ca_cert: @ca_pem.path)
  end
end
