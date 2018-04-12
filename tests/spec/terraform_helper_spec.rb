# frozen_string_literal: true

require 'ruby_terraform'
require 'securerandom'
require_relative 'terraform_helper'
require_relative 'vault_helper'
require_relative 'ec2_helper'

envs_dir = File.expand_path(ENV['TF_ENVS_DIR'] || File.join(File.dirname(__FILE__), '..', '..', 'envs'))
production_envs_dir = File.expand_path(ENV['TF_PROD_ENVS_DIR'] || raise)
template_dir = "#{envs_dir}/template"
production_template_dir = "#{production_envs_dir}/template"

describe 'Vault Terraform code' do
  it 'should successfully spin up a brand new infrastructure' do
    @terraform = TerraformHelper.new("#{envs_dir}/#{random_name}", load_variables)
    @terraform.apply(template_dir)

    @vault = VaultHelper.new(
      @terraform.output('vault_asg'),
      @terraform.output('vault_url'),
      @terraform.output('vault_ca')
    )

    @vault.initialise_vault
    @vault.configure

    @vault.verify
  end

  it 'should successfully upgrade existing infrastructure' do
    terraform_state = Tempfile.new

    # Spin up a production-like environment...
    @terraform = TerraformHelper.new(
      "#{production_envs_dir}/#{random_name}",
      load_production_variables,
      "path": terraform_state.path
    )
    @terraform.apply(production_template_dir)

    @vault = VaultHelper.new(
      @terraform.output('vault_asg'),
      @terraform.output('vault_url'),
      @terraform.output('vault_ca')
    )

    @vault.initialise_vault
    @vault.configure

    @vault.verify

    @vault.start_monitor

    # Now upgrade the production environment...
    #   Note that the directory name is again picking a random name
    #   in case production_envs_dir is the same as envs_dir, i.e. there is no production version yet
    @terraform.dir = "#{envs_dir}/#{random_name}"
    @terraform.vars = load_variables
    @terraform.apply(template_dir)

    puts "Monitor saw #{@vault.failures} failure(s) when applying terraform changes"
    raise 'Vault failed while applying terraform changes' unless @vault.failures == 0

    @vault.instances.each do |instance|
      @vault.replace_instance(instance)
    end

    puts "Monitor saw #{@vault.failures} failure(s) when replacing all Vault instances"

    # One failure is allowed for re-election when destroying the leader
    raise "More than allowed failures occurred when updating the Vault instances! #{@vault.failures}" \
      if @vault.failures > 1
  end

  after(:each) do
    @vault&.stop_monitor
    @terraform&.destroy
  end
end

def load_production_variables
  contents = File.read(File.join(File.expand_path(ENV['TF_PROD_VARS_DIR'] || raise), 'tf-vars.json'))
  JSON.parse(contents)
end

def load_variables
  contents = File.read(File.join(File.dirname(__FILE__), 'tf-vars.json'))
  json = JSON.parse(contents)
  json['vault_ami'] = ENV['AMI_TO_TEST'] if ENV['AMI_TO_TEST']
  json
end

def random_name
  SecureRandom.hex
end
