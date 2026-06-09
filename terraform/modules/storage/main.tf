# ── S3 Bucket ──────────────────────────────────────────────────────────────────
# TODO: Create resource "aws_s3_bucket" "raw"
#   - bucket: "spotify-analytics-${var.account_id}"
#   - S3 bucket names are globally unique across ALL AWS accounts worldwide.
#     Appending your account ID is the standard pattern to avoid name collisions.


# ── Versioning ─────────────────────────────────────────────────────────────────
# TODO: Create resource "aws_s3_bucket_versioning" "raw"
#   - bucket: aws_s3_bucket.raw.id
#   - versioning_configuration { status = "Enabled" }
#   - NOTE: Since AWS provider v4+, versioning is a separate resource, not a nested block
#     inside aws_s3_bucket. The Terraform docs will show you the correct structure.
#   - Why version? Protects against accidental overwrites of raw JSON files.

# ── Server-Side Encryption ─────────────────────────────────────────────────────
# TODO: Create resource "aws_s3_bucket_server_side_encryption_configuration" "raw"
#   - bucket: aws_s3_bucket.raw.id
#   - Use SSE-S3 (AES256) — no extra cost, no KMS key to manage.
#   - rule block → apply_server_side_encryption_by_default { sse_algorithm = "AES256" }