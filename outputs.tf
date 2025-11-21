output "instance_public_ip_change" {
  value = aws_instance.ubuntu_instance.public_ip
}
