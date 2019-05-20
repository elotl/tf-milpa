variable "ssh-key-name" {}

variable "namespace" {
    default = "vilmos"
}

variable "stage" {
    default = "dev"
}

variable "cluster-name" {}

variable "aws-access-key-id" {
    default = ""
}

variable "aws-secret-access-key" {
    default = ""
}

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
