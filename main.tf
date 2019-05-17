provider "aws" {
  region     = "${var.region}"
}

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true

    tags {
        Name = "milpa-vpc"
    }

    provisioner "local-exec" {
        # Remove any leftover instance, security group etc Milpa created. They
        # would prevent terraform from destroying the VPC.
        when    = "destroy"
        command = "./cleanup-vpc.sh ${self.id} ${var.cluster-name}"
        interpreter = ["/bin/bash", "-c"]
        environment = {
            AWS_ACCESS_KEY_ID = "${var.aws-access-key-id}"
            AWS_SECRET_ACCESS_KEY = "${var.aws-secret-access-key}"
            AWS_REGION = "${var.region}"
            AWS_DEFAULT_REGION = "${var.region}"
        }
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.main.id}"

    tags {
        Name = "milpa-gw"
    }

    provisioner "local-exec" {
        # Remove any leftover instance, security group etc Milpa created. They
        # would prevent terraform from destroying the VPC.
        when    = "destroy"
        command = "./cleanup-vpc.sh ${self.vpc_id} ${var.cluster-name}"
        interpreter = ["/bin/bash", "-c"]
        environment = {
            AWS_ACCESS_KEY_ID = "${var.aws-access-key-id}"
            AWS_SECRET_ACCESS_KEY = "${var.aws-secret-access-key}"
            AWS_REGION = "${var.region}"
            AWS_DEFAULT_REGION = "${var.region}"
        }
    }
}

resource "aws_route_table" "route-table" {
    vpc_id = "${aws_vpc.main.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }

    depends_on = ["aws_internet_gateway.gw"]

    tags {
        Name = "milpa-route-table"
    }
}

resource "aws_route_table_association" "public" {
    subnet_id = "${aws_subnet.public.id}"
    route_table_id = "${aws_route_table.route-table.id}"
}

resource "aws_subnet" "public" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "10.0.100.0/24"
    availability_zone = "us-east-1c"
    map_public_ip_on_launch = true

    tags {
        Name = "milpa-subnet"
    }
}

resource "aws_security_group" "milpa-server" {
  name = "milpa-server"
  description = "Milpa server security group"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["10.0.0.0/16"]
  }


  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "milpa-server"
  }
}

data "template_file" "milpa-userdata" {
    template = "${file("${var.userdata}")}"

    vars {
        cluster_name = "${var.cluster-name}"
        aws_access_key_id = "${var.aws-access-key-id}"
        aws_secret_access_key = "${var.aws-secret-access-key}"
        ssh_key_name = "${var.ssh-key-name}"
        license_key = "${var.license-key}"
        license_id = "${var.license-id}"
        license_username = "${var.license-username}"
        license_password = "${var.license-password}"
    }
}

resource "aws_instance" "milpa-server" {
  ami           = "ami-028d6461780695a43"
  instance_type = "t3.small"
  subnet_id = "${aws_subnet.public.id}"
  user_data = "${data.template_file.milpa-userdata.rendered}"
  key_name = "${var.ssh-key-name}"
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.milpa-server.id}"]

  depends_on = ["aws_internet_gateway.gw"]

  tags {
      Name = "milpa-server"
  }
}
