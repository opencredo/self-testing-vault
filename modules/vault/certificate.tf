resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits = "4096"
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm = "${tls_private_key.ca.algorithm}"
  private_key_pem = "${tls_private_key.ca.private_key_pem}"
  validity_period_hours = "720"
  is_ca_certificate = true
  ip_addresses = ["127.0.0.1"]
  allowed_uses = ["cert_signing"]
  subject {
    common_name = "vault-ca"
  }
}

resource "tls_private_key" "cert" {
  algorithm = "RSA"
  rsa_bits = "4096"
}

resource "tls_cert_request" "cert" {
  key_algorithm = "${tls_private_key.cert.algorithm}"
  private_key_pem = "${tls_private_key.cert.private_key_pem}"
  ip_addresses = ["127.0.0.1"]
  dns_names = ["${aws_elb.vault.dns_name}"]
  subject {
    common_name = "${aws_elb.vault.dns_name}"
  }
}

resource "tls_locally_signed_cert" "signing" {
  cert_request_pem = "${tls_cert_request.cert.cert_request_pem}"

  ca_key_algorithm = "${tls_private_key.ca.algorithm}"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = "10"
  allowed_uses = ["server_auth"]

}
