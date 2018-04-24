## Vault Cluster

This repository contains the [Packer](https://www.packer.io/) and [Terraform](https://www.terraform.io/) code to
build, test and create a [Vault](https://www.vaultproject.io/) cluster running in AWS. It is an example repository
for a blog post on 
[creating self-testing builds for infrastructure-as-code](https://opencredo.com/self-testing-infrastructure-as-code).

To build and test the necessary components, run `make`.

When running on a CI server, run `make tag_ami` to create, test (both the Packer and Terraform) and
tag an AMI from the master branch

### Contents
* `envs/` - individual environments that the Terraform code has been applied to
* `envs/template` - a template that can be used to quickly spin up a new environment
* `modules/vault`  - A Terraform module for a Vault cluster
* `packer/` - code needed to create and test an AMI that is used by the Terraform code
* `packer/ansible` - Ansible code that is used when creating the AMI
* `packer/tests` - serverspec tests to ensure the Vault AMI was created correctly
* `tests/` - RSpec tests to ensure that the Terraform code behaves correctly

### Notes about this repository
Some of the things to be fixed in this repository before it should be used in a production setting, some of
which may require changes to the tests:
* Private half of the SSL certificate is sent to the Vault instances using `user_data` which would be 
accessible by anyone who can access the AWS console or the instance metadata API.
* VPC is currently being fed into Terraform as a variable; a better way would be to have the VPC Terraform
state remotely hosted somewhere and then the VPC id fetched by `remote_state` (see Terraservices).
* Backend currently used by Terraform should be changed from `local` to something more resilient.
* The Vault AMI should be hardened, such as ensuring no unexpected ports are open or not allowing SSH 
access as root (remember to test it!).
* SSL Certificate used to protect Vault is only valid for 10 hours and is generated within Terraform
* The integration test experiences 1 monitoring failure most of the time which occurs when requests
are made while the leader is being elected; forcing the leader to step down before terminating it
means the failure window is larger.
* `tests/spec/tf-vars.json` will need to be filled out with real values before it can be used.
* ELB and EC2 instances have public IP addresses.
* Vault uses DynamoDB has a backend which HashiCorp only provides community support for
* Uncomment the `tested` filter from `modules/vault/input.tf` once there is a tested AMI
* Lack of anywhere to store Vault audit logs
