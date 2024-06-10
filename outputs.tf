output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.minecraft_server.id
}

output "instance_public_ipv4" {
  description = "Public IPv4 address of the EC2 instance"
  value       = aws_instance.minecraft_server.public_ip
}

output "instance_public_ipv6" {
  description = "Public IPv6 addresses of the EC2 instance"
  value       = aws_instance.minecraft_server.ipv6_addresses
}
