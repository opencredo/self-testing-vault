variable "vpc_id" {
  description = "ID of the VPC that the Vault instances will be launched in"
}

variable "ami_id" {
  default = ""
  description = "(Optional) AMI that the Vault instances will be launched from. Defaults to the latest Vault AMI"
}

variable "instance_type" {
  description = "Type of instance that the Vault instances will be"
}

variable "dynamodb_write_capacity" {
  description = "The write capacity that the DynamoDB table behind Vault will have"
}

variable "dynamodb_read_capacity" {
  description = "The read capacity that the DynamoDB table behind Vault will have"
}

variable "ip_address" {
  description = "IP address that will be allowed access to Vault"
}

data "aws_subnet_ids"  "subnets" {
  vpc_id = "${var.vpc_id}"
}

data "aws_region" "current" {}

data "aws_ami" "ami" {
  most_recent = true
  filter {
    name = "tag:purpose"
    values = ["vault"]
  }
// This needs to be uncommented once there is a tested version of the AMI
//  filter {
//    name = "tag:tested"
//    values = ["true"]
//  }
  count = "${var.ami_id == "" ? 1 : 0}"
}

locals {
  public_certificate_location = "/usr/local/etc/vault/ssl.crt"
  private_certificate_location = "/usr/local/etc/vault/ssl.key"
}
