data "template_file" "vault_hcl" {
  template = "${file("${path.module}/templates/vault.hcl")}"
  vars {
    table_name = "${aws_dynamodb_table.vault_storage.name}"
    region = "${data.aws_region.current.name}"
    public_certificate = "${local.public_certificate_location}"
    private_certificate = "${local.private_certificate_location}"
  }
}

data "template_file" "vault_cloud_config" {
  template = "${file("${path.module}/templates/cloud_config.yml")}"
  vars {
    vault_hcl = "${base64encode(data.template_file.vault_hcl.rendered)}"
    public_certificate = "${base64encode(tls_locally_signed_cert.signing.cert_pem)}"
    private_certificate = "${base64encode(tls_private_key.cert.private_key_pem)}"
    public_certificate_location = "${local.public_certificate_location}"
    private_certificate_location = "${local.private_certificate_location}"
  }
}
