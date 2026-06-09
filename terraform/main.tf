terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # TODO: after your first `terraform apply`, add an S3 backend here so state is
  # stored remotely instead of in the local terraform.tfstate file.
  # Docs: https://developer.hashicorp.com/terraform/language/backend/s3
}

provider "aws" {
  region = var.aws_region
  # Terraform will use your local AWS credentials (from `aws configure`) or the
  # EC2 instance role if running on EC2.
}

# TODO: fill in each module block after you've created the corresponding module directory.
# Each module is a folder under terraform/modules/ with its own .tf files.
# Call order matters — compute and database both depend on networking outputs.

module "networking" {
  source = "./modules/networking"
  # TODO: this module should create: VPC, public subnet, private subnet, internet gateway, route tables
}

module "storage" {
  source     = "./modules/storage"
  account_id = var.account_id
  # TODO: this module should create: the S3 bucket for raw JSON landing
}

module "iam" {
  source        = "./modules/iam"
  s3_bucket_arn = module.storage.bucket_arn
  # TODO: this module should create: an EC2 instance role + policy that allows
  #   s3:GetObject, s3:PutObject on the raw bucket, and rds-db:connect
}

module "database" {
  source             = "./modules/database"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  ec2_sg_id          = module.compute.ec2_sg_id
  db_password        = var.db_password
  # TODO: this module should create: RDS PostgreSQL instance, DB subnet group, security group
  #   (allow port 5432 from the EC2 security group only — never from 0.0.0.0/0)
}

module "compute" {
  source             = "./modules/compute"
  vpc_id             = module.networking.vpc_id
  public_subnet_id   = module.networking.public_subnet_id
  your_ip            = var.your_ip
  instance_profile   = module.iam.instance_profile_name
  # TODO: this module should create: EC2 instance (t3.medium), security group
  #   (SSH from your_ip only, all outbound), key pair, instance profile attachment
}
