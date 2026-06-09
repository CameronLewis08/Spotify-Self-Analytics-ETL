variable "vpc_id" {
  description = "VPC ID from the networking module"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs in ≥2 AZs — required by the RDS subnet group"
  type        = list(string)
}

variable "ec2_sg_id" {
  description = "EC2 security group ID — RDS ingress allows port 5432 from this SG only"
  type        = string
}

variable "db_password" {
  description = "RDS PostgreSQL master password"
  type        = string
  sensitive   = true
}
