variable "function_name" {
  type    = string
  default = "bedrock-kb-mvp-create-vector-index"
}

variable "collection_endpoint" {
  description = "The OpenSearch Serverless collection's collection_endpoint attribute (full https:// URL is fine, the scheme is stripped internally)."
  type        = string
}

variable "collection_arn" {
  type = string
}

variable "index_name" {
  description = "Follow your enterprise naming standard here (Story 4's acceptance criteria) -- this module doesn't enforce a pattern itself."
  type        = string
}

variable "vector_field_name" {
  type    = string
  default = "bedrock-knowledge-base-default-vector"
}

variable "text_field_name" {
  type    = string
  default = "AMAZON_BEDROCK_TEXT_CHUNK"
}

variable "metadata_field_name" {
  type    = string
  default = "AMAZON_BEDROCK_METADATA"
}

variable "vector_dimension" {
  description = "Must match the embedding model's output dimension exactly (Titan V2 default: 1024)."
  type        = number
  default     = 1024
}

variable "vpc_subnet_ids" {
  description = "If set, the Lambda is VPC-attached so it can reach a network-private collection. Leave empty for a public-network-policy collection."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
