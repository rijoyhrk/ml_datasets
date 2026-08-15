output "kb_source_bucket_name" {
  description = "Name of the S3 bucket holding test policy documents for the Knowledge Base."
  value       = aws_s3_bucket.kb_source.id
}

output "kb_source_bucket_arn" {
  description = "ARN of the S3 bucket — will be referenced by the IAM policy (Step 2) and the data source (Step 5)."
  value       = aws_s3_bucket.kb_source.arn
}
