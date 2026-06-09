variable "s3_bucket_arn" {
  description = "ARN of the raw S3 bucket — used to scope the IAM policy to this bucket only"
  type        = string
}
