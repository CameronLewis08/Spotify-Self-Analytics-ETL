variable "vpc_id" {
  description = "VPC ID from the networking module"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID — EC2 needs to be here to receive a public IP"
  type        = string
}

variable "your_ip" {
  description = "Your public IP in CIDR notation — restricts SSH to only you"
  type        = string
}

variable "instance_profile" {
  description = "IAM instance profile name — grants EC2 access to S3 and RDS"
  type        = string
}
