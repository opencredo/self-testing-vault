module "vault" {
  source = "../../modules/vault"
  ami_id = "${var.vault_ami}"
  instance_type = "${var.instance_type}"
  vpc_id = "${var.vpc_id}"
  dynamodb_read_capacity = "${var.dynamodb_read_capacity}"
  dynamodb_write_capacity = "${var.dynamodb_write_capacity}"
  ip_address = "${var.ip_address}"
}
