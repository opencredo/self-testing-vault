output "vault_url" {
  value = "https://${aws_elb.vault.dns_name}:8200"
}

output "vault_asg" {
  value = "${aws_autoscaling_group.vault.name}"
}

output "vault_ca" {
  value = "${tls_self_signed_cert.ca.cert_pem}"
}

output "vault_ssh_key" {
  value = "${tls_private_key.ssh.private_key_pem}"
}
