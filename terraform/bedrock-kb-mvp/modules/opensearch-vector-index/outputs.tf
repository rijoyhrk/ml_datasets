output "index_name" {
  value = var.index_name
}

output "vector_field_name" {
  value = var.vector_field_name
}

output "text_field_name" {
  value = var.text_field_name
}

output "metadata_field_name" {
  value = var.metadata_field_name
}

output "lambda_role_arn" {
  description = "Add this to the OpenSearch Serverless data access policy alongside the Bedrock KB role -- this Lambda needed its own aoss:APIAccessAll grant to create the index."
  value       = aws_iam_role.this.arn
}

output "index_creation_result" {
  description = "Forces anything referencing this output (i.e. the Knowledge Base resource) to wait until index creation has actually run."
  value       = aws_lambda_invocation.create_index.result
}
