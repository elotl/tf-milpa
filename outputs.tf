output "milpa_ip" {
  value = "${aws_instance.milpa-server.public_ip}"
}
