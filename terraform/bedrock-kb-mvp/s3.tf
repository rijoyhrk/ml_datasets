# --- Step 1: S3 source bucket for the Knowledge Base data source ---
# Bucket names are globally unique across all of AWS, so we append a random
# suffix rather than forcing you to hand-pick a unique name.
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "kb_source" {
  bucket = "${var.project_name}-source-${random_id.bucket_suffix.hex}"
}

# Versioning is not required by Bedrock KB ingestion — it's included here so
# that overwriting/deleting a test policy document is recoverable while you
# experiment. Safe to set to "Disabled" if you don't want the extra copies.
resource "aws_s3_bucket_versioning" "kb_source" {
  bucket = aws_s3_bucket.kb_source.id
  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AES256) is the minimum-friction encryption-at-rest option for the
# MVP. SSE-KMS with a customer-managed key is a post-MVP hardening step (it
# adds a kms:Decrypt permission requirement to the KB's IAM role).
resource "aws_s3_bucket_server_side_encryption_configuration" "kb_source" {
  bucket = aws_s3_bucket.kb_source.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# The Knowledge Base reaches this bucket exclusively via the IAM role we
# create in Step 2 — nothing here needs to be publicly reachable.
resource "aws_s3_bucket_public_access_block" "kb_source" {
  bucket = aws_s3_bucket.kb_source.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
