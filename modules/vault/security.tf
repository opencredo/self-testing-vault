resource "aws_security_group" "internal_access" {
  name_prefix = "vault_internal"
  vpc_id = "${var.vpc_id}"
  ingress {
    # Vault
    from_port   = 8200
    to_port     = 8201
    protocol    = "tcp"
    self = true
  }
  # Allow outbound to all
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "external_access" {
  name_prefix = "vault_access"
  vpc_id = "${var.vpc_id}"
  ingress {
    # Vault
    from_port = 8200
    to_port = 8200
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    # Ping
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["${var.ip_address}/32"]
  }
  # Allow outbound to all
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh_access" {
  name_prefix = "vault_ssh_access"
  vpc_id = "${var.vpc_id}"
  ingress {
    # SSH
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${var.ip_address}/32"]
  }
  # Allow outbound to all
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "vault_assume_role" {
  "statement" {
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "vault_assume_role" {
  name_prefix = "vault-vms"
  assume_role_policy = "${data.aws_iam_policy_document.vault_assume_role.json}"
}

resource "aws_iam_instance_profile" "vault_assume_role" {
  name_prefix = "vault_vms_assume_role"
  role = "${aws_iam_role.vault_assume_role.name}"
}

data "aws_iam_policy_document" "vault_vms" {
  # Allow VMs to find other instances within the security group
  statement {
    actions = [
      "ec2:DescribeInstances",
    ]
    effect = "Allow"
    resources = ["*"]
  }
  # Allow read/write access to the DynamoDB table
  statement {
    actions = [
      "dynamodb:Batch*",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:UpdateItem",
      "dynamodb:UpdateTable",
    ]
    effect = "Allow"
    resources = ["${aws_dynamodb_table.vault_storage.arn}"]
  }
}

resource "aws_iam_policy" "vault_vms" {
  name_prefix = "vault-vms"
  policy = "${data.aws_iam_policy_document.vault_vms.json}"
}

resource "aws_iam_policy_attachment" "vault_vms" {
  name       = "vault-vms"
  roles      = ["${aws_iam_role.vault_assume_role.name}"]
  policy_arn = "${aws_iam_policy.vault_vms.arn}"
}
