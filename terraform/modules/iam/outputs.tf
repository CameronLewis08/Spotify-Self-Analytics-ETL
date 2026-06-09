output "instance_profile_name" {
  description = "Instance profile name — passed to the compute module to attach to the EC2 instance"
  value       = aws_iam_instance_profile.ec2.name
}
