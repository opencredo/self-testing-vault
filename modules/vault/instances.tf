resource "aws_launch_configuration" "vault" {
  image_id = "${element(concat(data.aws_ami.ami.*.image_id, list(var.ami_id)), 0)}"
  instance_type = "${var.instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.vault_assume_role.id}"
  key_name = "${aws_key_pair.vault.id}"
  security_groups = [
    "${aws_security_group.internal_access.id}",
    "${aws_security_group.external_access.id}",
    "${aws_security_group.ssh_access.id}",
  ]
  root_block_device {
    volume_size = "8"
    volume_type = "gp2"
  }
  user_data = "${data.template_file.vault_cloud_config.rendered}"

  lifecycle {
    # Adding this stops terraform from messing up when the launch configuration has changed
    # https://github.com/hashicorp/terraform/issues/1109
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "vault" {
  name_prefix = "vault"
  launch_configuration = "${aws_launch_configuration.vault.id}"
  max_size = "${length(data.aws_subnet_ids.subnets.ids)}"
  min_size = "${length(data.aws_subnet_ids.subnets.ids)}"

  health_check_type = "EC2"
  health_check_grace_period = 300
  load_balancers = ["${aws_elb.vault.id}"]
  termination_policies = ["OldestLaunchConfiguration"]
  vpc_zone_identifier = ["${data.aws_subnet_ids.subnets.ids}"]
}

resource "aws_elb" "vault" {
  name_prefix = "vault"
  subnets = ["${data.aws_subnet_ids.subnets.ids}"]
  internal = false
  security_groups = [
    "${aws_security_group.internal_access.id}",
    "${aws_security_group.external_access.id}",
  ]
  "listener" {
    instance_port = 8200
    instance_protocol = "tcp"
    lb_port = 8200
    lb_protocol = "tcp"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout = 4
    target = "HTTPS:8200/v1/sys/health?standbyok=true"
    interval = 5
  }
}


resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "vault" {
  public_key = "${tls_private_key.ssh.public_key_openssh}"
  key_name_prefix = "vault"
}
