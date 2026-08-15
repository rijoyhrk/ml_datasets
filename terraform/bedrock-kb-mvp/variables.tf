variable "aws_region" {
  description = "AWS region to deploy into. Must support Bedrock Knowledge Bases, Titan Text Embeddings V2, and OpenSearch Serverless."
  type        = string
  default     = "us-east-1" # ASSUMPTION — override if you need a different region.
}

variable "project_name" {
  description = "Short name used as a resource-naming prefix and tag value."
  type        = string
  default     = "bedrock-kb-mvp"
}

variable "environment" {
  description = "Environment tag (dev/test/uat/prod). MVP assumes a single 'dev' environment."
  type        = string
  default     = "dev"
}
