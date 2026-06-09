output "vpc_id" {
  description = "VPC ID — passed to compute and database modules"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID — EC2 instance goes here"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs in ≥2 AZs — required by the RDS subnet group"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}