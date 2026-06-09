output "endpoint" {
  description = "RDS endpoint hostname — used in dbt profiles.yml and the ETL connection string"
  value       = aws_db_instance.postgres.endpoint
}
