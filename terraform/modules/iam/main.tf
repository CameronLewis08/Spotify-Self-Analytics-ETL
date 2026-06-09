# ── Trust Policy ─────────────────────────────────────────────────────────────
# This data block generates the JSON that says "EC2 is allowed to assume this role".
# Without it, the role exists but no service can pick it up.

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ── IAM Role ──────────────────────────────────────────────────────────────────
# TODO: Create resource "aws_iam_role" "ec2"
#   - name               = "spotify-etl-ec2-role"
#   - assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

# ── Inline Policy (S3 + RDS access) ──────────────────────────────────────────
# TODO: Create resource "aws_iam_role_policy" "ec2_s3_rds"
#   - name = "spotify-etl-ec2-policy"
#   - role = aws_iam_role.ec2.id
#   - policy = jsonencode({
#       Version = "2012-10-17"
#       Statement = [
#         {
#           Effect   = "Allow"
#           Action   = ["s3:GetObject", "s3:PutObject"]
#           Resource = "${var.s3_bucket_arn}/*"
#           -- The /* is important: the ARN points to the bucket; adding /* covers all objects inside it.
#         },
#         {
#           Effect   = "Allow"
#           Action   = ["rds-db:connect"]
#           Resource = "*"
#         }
#       ]
#     })

# ── Instance Profile ──────────────────────────────────────────────────────────
# TODO: Create resource "aws_iam_instance_profile" "ec2"
#   - name = "spotify-etl-ec2-profile"
#   - role = aws_iam_role.ec2.name
#   - Why: EC2 instances don't attach roles directly — they attach an "instance profile"
#          which is a container that holds exactly one IAM role.
