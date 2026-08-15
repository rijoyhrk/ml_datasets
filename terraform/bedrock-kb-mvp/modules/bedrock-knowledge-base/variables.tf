variable "role_name" {
  description = "Name for the IAM role Bedrock assumes at runtime. Not the Terraform deployer identity — see deployer-access/README.md."
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket holding source documents. The role is scoped to exactly this bucket, nothing broader."
  type        = string
}

variable "embedding_model_arn" {
  description = "ARN of the single embedding model this KB is allowed to invoke (e.g. Titan Text Embeddings V2). Never wildcarded to foundation-model/*."
  type        = string
}

variable "opensearch_collection_arn" {
  description = "ARN of the OpenSearch Serverless collection used as the vector store. Populated once Step 3 (OpenSearch Serverless) exists."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used to encrypt the source bucket / collection, if any. Null falls back to AWS-owned keys (no extra IAM statement needed)."
  type        = string
  default     = null
}

variable "aws_account_id" {
  description = "Account ID used in the trust policy's confused-deputy condition (aws:SourceAccount)."
  type        = string
}

variable "aws_region" {
  description = "Region used in the trust policy's confused-deputy condition (aws:SourceArn pattern) and to scope the knowledge-base ARN pattern."
  type        = string
}

variable "tags" {
  description = "Tags applied to the IAM role."
  type        = map(string)
  default     = {}
}
