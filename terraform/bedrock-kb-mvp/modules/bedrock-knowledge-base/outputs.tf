output "role_arn" {
  description = "ARN of the Bedrock KB service role — pass this as role_arn when creating the aws_bedrockagent_knowledge_base resource (Step 4)."
  value       = aws_iam_role.bedrock_kb.arn
}

output "role_name" {
  value = aws_iam_role.bedrock_kb.name
}
