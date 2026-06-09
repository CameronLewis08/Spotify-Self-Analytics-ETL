output "public_ip" {
  description = "EC2 public IP — SSH target and root module output"
  value       = aws_instance.etl.public_ip
}

output "ec2_sg_id" {
  description = "EC2 security group ID — passed to the database module to allow port 5432 from EC2 only"
  value       = aws_security_group.ec2.id
}
