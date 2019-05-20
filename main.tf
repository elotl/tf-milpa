provider "aws" {
  region     = "${var.region}"
}

data "http" "my-ip-address" {
   url = "http://ipv4.icanhazip.com"
}

locals {
  my-cidr = "${chomp(data.http.my-ip-address.body)}/32"
}

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true

    tags {
        Name = "${var.namespace}-${var.stage}-milpa-vpc"
    }

    provisioner "local-exec" {
        # Remove any leftover instance, security group etc Milpa created. They
        # would prevent terraform from destroying the VPC.
        when    = "destroy"
        command = "./cleanup-vpc.sh ${self.id} ${var.cluster-name}"
        interpreter = ["/bin/bash", "-c"]
        environment = {
          AWS_REGION = "${var.region}"
          AWS_DEFAULT_REGION = "${var.region}"
        }
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.main.id}"

    tags {
        Name = "${var.namespace}-${var.stage}-milpa-gw"
    }

    provisioner "local-exec" {
        # Remove any leftover instance, security group etc Milpa created. They
        # would prevent terraform from destroying the VPC.
        when    = "destroy"
        command = "./cleanup-vpc.sh ${self.vpc_id} ${var.cluster-name}"
        interpreter = ["/bin/bash", "-c"]
        environment = {
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
        Name = "${var.namespace}-${var.stage}-milpa-route-table"
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
        Name = "${var.namespace}-${var.stage}-milpa-subnet"
    }
}

resource "aws_security_group" "milpa-server" {
  name = "${var.namespace}-${var.stage}-milpa-server"
  description = "Milpa server security group"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["${local.my-cidr}"]
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
    Name = "${var.namespace}-${var.stage}-milpa-server"
  }
}

resource "aws_iam_role" "milpa" {
  name = "${var.namespace}-${var.stage}-milpa"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "milpa" {
  name = "${var.namespace}-${var.stage}-milpa"
  role = "${aws_iam_role.milpa.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ec2",
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateRoute",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteRoute",
        "ec2:DeleteSecurityGroup",
        "ec2:DescribeAddresses",
        "ec2:DescribeElasticGpus",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSpotPriceHistory",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DescribeVpcAttribute",
        "ec2:DescribeVpcs",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyInstanceCreditSpecification",
        "ec2:ModifyVolume",
        "ec2:ModifyVpcAttribute",
        "ec2:RequestSpotInstances",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ecr:BatchGetImage",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTags",
        "route53:ChangeResourceRecordSets",
        "route53:CreateHostedZone",
        "route53:GetChange",
        "route53:ListHostedZonesByName",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "*"
    },
    {
      "Sid": "dynamo",
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:PutItem",
        "dynamodb:DescribeTable",
        "dynamodb:GetItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/MilpaClusters"
    },
    {
      "Sid": "elb",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:RemoveTags",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:ConfigureHealthCheck",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancerListeners",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:CreateLoadBalancerListeners"
      ],
      "Resource": "arn:aws:elasticloadbalancing:*:*:loadbalancer/milpa-*"
    }
  ]
}
EOF
}

resource  "aws_iam_instance_profile" "milpa" {
  name = "${var.namespace}-${var.stage}-milpa"
  role = "${aws_iam_role.milpa.name}"
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
  iam_instance_profile = "${aws_iam_instance_profile.milpa.id}"

  depends_on = ["aws_internet_gateway.gw"]

  tags {
      Name = "${var.namespace}-${var.stage}-milpa-server"
  }
}
