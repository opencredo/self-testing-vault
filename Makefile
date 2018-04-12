# Default the 'production' version of the repository to this repository
PRODUCTION_DIR ?= $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

default: clean terraform

packer: .packer-tested

terraform: .terraform-tested

clean:
	rm -f packer/packer-manifest.json .terraform-tested .packer-tested

# Run packer to generate the manifest file
packer/packer-manifest.json: packer/vault.json packer/ansible/ansible.yml $(wildcard packer/ansible/**/*)
	cd packer && packer build -var 'image_name=vault' vault.json

# Test the built image
.packer-tested: packer/packer-manifest.json $(wildcard packer/tests/**/*)
	# Read the latest AMI from the Packer manifest file
	$(eval ami = $(shell jq -r '.builds[].last_run_uuid = .last_run_uuid | .builds[] | select(.last_run_uuid == .packer_run_uuid) | .artifact_id | split(":")[1]' packer/packer-manifest.json))
	# Run the serverspec tests using Terraform
	packer/tests/test.sh $(ami)
	@touch .packer-tested

# Test the built image and Terraform code
.terraform-tested: .packer-tested $(wildcard modules/**/* envs/template/* tests/**/*)
	# Read the latest AMI from the Packer manifest file
	$(eval ami = $(shell jq -r '.builds[].last_run_uuid = .last_run_uuid | .builds[] | select(.last_run_uuid == .packer_run_uuid) | .artifact_id | split(":")[1]' packer/packer-manifest.json))
	# Run the Terraform tests using Rake
	cd tests && TF_PROD_VARS_DIR=$(PRODUCTION_DIR)/tests/spec TF_PROD_ENVS_DIR=$(PRODUCTION_DIR)/envs AMI_TO_TEST=$(ami) bundle exec rake
	@touch .terraform-tested

# Tag the image as tested
tag_ami: .terraform-tested
	# Read the latest AMI from the Packer manifest file
	$(eval ami = $(shell jq -r '.builds[].last_run_uuid = .last_run_uuid | .builds[] | select(.last_run_uuid == .packer_run_uuid) | .artifact_id | split(":")[1]' packer/packer-manifest.json))
	# Tag the AMI as tested
	aws ec2 create-tags --resources $(ami) --tags Key=tested,Value=true

.PHONEY: clean tag_ami terraform packer
