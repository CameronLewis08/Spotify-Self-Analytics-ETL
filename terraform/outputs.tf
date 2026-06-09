# Outputs are printed after `terraform apply` and can be read with `terraform output`.
# These three are the values you'll need to configure Airflow and dbt on EC2.

output "ec2_public_ip" {
  description = "SSH to your Airflow instance: ssh -i your-key.pem ec2-user@<this value>"
  value       = module.compute.public_ip
  # TODO: make sure your compute module exports a `public_ip` output
}

output "rds_endpoint" {
  description = "PostgreSQL host for dbt profiles.yml and the RDSLoader DSN"
  value       = module.database.endpoint
  # TODO: make sure your database module exports an `endpoint` output
}

output "s3_bucket_name" {
  description = "S3 bucket name for the S3Loader and Airflow env vars"
  value       = module.storage.bucket_name
  # TODO: make sure your storage module exports a `bucket_name` output
}
