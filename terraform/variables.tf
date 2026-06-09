# Variables are declared here and passed in via terraform.tfvars (never commit that file)
# or environment variables prefixed with TF_VAR_ (e.g. TF_VAR_db_password).

variable "aws_region" {
  description = "AWS region to deploy into (e.g. us-east-1)"
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "account_id" {
  description = "Your AWS account ID — used to make the S3 bucket name globally unique"
  type        = string
  nullable    = false
  
}

variable "your_ip" {
  description = "Your public IP in CIDR notation (e.g. 1.2.3.4/32) — restricts SSH to only you"
  type        = string
  nullable    = false
  
}

variable "db_password" {
  description = "RDS PostgreSQL master password"
  type        = string
  sensitive   = true
  nullable    = false
  
}
