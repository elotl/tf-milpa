variable "ssh-key-name" {}

variable "cluster-name" {}

variable "aws-access-key-id" {}

variable "aws-secret-access-key" {}

variable "license-key" {}

variable "license-id" {}

variable "license-username" {}

variable "license-password" {}

variable "region" {
    default = "us-east-1"
}

variable "userdata" {
    default = "setup.sh"
}
