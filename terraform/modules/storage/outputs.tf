output "bucket_arn" {
  description = "ARN of the raw S3 bucket — used by the IAM module to scope the policy"
  value       = aws_s3_bucket.raw.arn
}

output "bucket_name" {
  description = "Name of the raw S3 bucket — used by Airflow env vars and the S3Loader"
  value       = aws_s3_bucket.raw.id
}
