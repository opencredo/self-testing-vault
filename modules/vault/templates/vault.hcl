storage "dynamodb" {
  table = "${table_name}"
  region = "${region}"
  ha_enabled = "true"
}
listener "tcp" {
  address = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_cert_file = "${public_certificate}"
  tls_key_file = "${private_certificate}"
}
