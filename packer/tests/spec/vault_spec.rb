# frozen_string_literal: true

require 'serverspec'
require 'spec_helper'

# Check that the drivers for enchanced networking are present
describe command('modinfo ena') do
  its(:exit_status) { should eq 0 }
end

describe command('modinfo ixgbevf') do
  its(:exit_status) { should eq 0 }
end

describe selinux do
  it { should be_enforcing }
end

# Check that Vault isn't set to come up yet, as it will only get configured _after_ cloud-init has run
describe service('vault') do
  it { should_not be_enabled }
  it { should_not be_running }
end

describe command('vault version') do
  its(:stdout) { should match(/Vault v0.9.6/) }
end

# SSH keys that AWS fills in should only contain the SSH key for /this/ instance and no others
%w[/root/.ssh/authorized_keys /home/centos/.ssh/authorized_keys].each do |f|
  describe file(f) do
    its(:content) { should match(/^[^\n]*\n$/) }
  end
end

# Certain users should definitely not have a password
%w[root centos].each do |u|
  describe user(u) do
    its(:encrypted_password) { should match(/^.{0,2}$/) }
  end
end
