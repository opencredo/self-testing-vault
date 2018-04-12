variable "vpc_id" {
  description = "ID of the VPC that the Vault instances will be launched in"
}

variable "vault_ami" {
  default = ""
  description = "(Optional) AMI that the Vault instances will be launched from. Defaults to the latest Vault AMI"
}

variable "instance_type" {
  description = "Type of instance that the Vault instances will be"
}

variable "dynamodb_read_capacity" {
  default = "5"
  description = "The read capacity that the DynamoDB table behind Vault will have"
}

variable "dynamodb_write_capacity" {
  default = "5"
  description = "The read capacity that the DynamoDB table behind Vault will have"
}

variable "ip_address" {
  description = "IP address that will be allowed access to Vault"
}
