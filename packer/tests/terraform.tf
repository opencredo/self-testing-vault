variable "unique_identifier" {
  description = "An identifier that will be unique to this run of the tests"
}
variable "artifact_under_test" {
  description = "AMI that is being tested"
}
variable "ip_address" {
  description = "Public IP address where the test is being run from"
}

resource "aws_key_pair" "test" {
  public_key = "${tls_private_key.ssh.public_key_openssh}"
  key_name_prefix = "${var.unique_identifier}"
}

resource "aws_instance" "test" {
  associate_public_ip_address = true
  subnet_id = "${aws_subnet.dmz.id}"
  ami = "${var.artifact_under_test}"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.test.id}"]
  key_name = "${aws_key_pair.test.id}"
  tags {
    Name = "${var.unique_identifier}"
    artifact_under_test = "${var.artifact_under_test}"
    unique_identifier = "${var.unique_identifier}"
  }

  # Wait for this instance to be available before handing over to the next step
  provisioner "remote-exec" {
    inline = ["true"]
    connection {
      type = "ssh"
      user = "centos"
      agent = false
      private_key = "${tls_private_key.ssh.private_key_pem}"
    }
  }

  # Now the instance is up and available, execute the serverspec tests
  #   Run this inside terraform to avoid complications around what directory terraform is being run from
  provisioner "local-exec" {
    command = "cd ${path.module} && SSH_USER=centos TARGET_HOST='${aws_instance.test.public_ip}' SSH_PRIVATE_KEY='${local_file.ssh_private_key.filename}' bundle exec rake"
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "local_file" "ssh_private_key" {
  content = "${tls_private_key.ssh.private_key_pem}"
  filename = "${path.module}/ssh_key"
}

### Output

output "ip_address" {
  value = "${aws_instance.test.public_ip}"
}

output "ssh_private_key_file" {
  value = "${local_file.ssh_private_key.filename}"
}


### Network

resource "aws_vpc" "core" {
  cidr_block = "10.20.0.0/16"
  tags {
    Name = "${var.unique_identifier}-core-vpc"
    artifact_under_test = "${var.artifact_under_test}"
    unique_identifier = "${var.unique_identifier}"
  }
}

resource "aws_subnet" "dmz" {
  vpc_id = "${aws_vpc.core.id}"
  cidr_block = "10.20.250.0/24"
  depends_on = ["aws_internet_gateway.gateway"]
  tags {
    Name = "${var.unique_identifier}-dmz"
    artifact_under_test = "${var.artifact_under_test}"
    unique_identifier = "${var.unique_identifier}"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = "${aws_vpc.core.id}"
  tags {
    Name = "${var.unique_identifier}-gateway"
    artifact_under_test = "${var.artifact_under_test}"
    unique_identifier = "${var.unique_identifier}"
  }
}

resource "aws_route_table" "table" {
  vpc_id = "${aws_vpc.core.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }
  tags {
    Name = "${var.unique_identifier}-table"
    artifact_under_test = "${var.artifact_under_test}"
    unique_identifier = "${var.unique_identifier}"
  }
}

resource "aws_route_table_association" "association" {
  subnet_id = "${aws_subnet.dmz.id}"
  route_table_id = "${aws_route_table.table.id}"
}

resource "aws_security_group" "test" {
  name_prefix = "${var.unique_identifier}-test"
  description = "Security Group for testing ${var.artifact_under_test} (${var.unique_identifier})"
  vpc_id = "${aws_vpc.core.id}"
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["${var.ip_address}/32"]
  }
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    self = "true"
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "${var.unique_identifier}-test"
    artifact_under_test = "${var.artifact_under_test}"
    unique_identifier = "${var.unique_identifier}"
  }
}
