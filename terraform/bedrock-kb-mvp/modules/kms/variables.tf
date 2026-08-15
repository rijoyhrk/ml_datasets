variable "alias_name" {
  description = "Alias for the CMK, e.g. alias/bedrock-kb-mvp."
  type        = string
}

variable "key_admin_arns" {
  description = "IAM principals allowed to manage (not just use) this key — typically your account's admin/break-glass role. Kept separate from key *usage*, which is delegated to IAM policy (see key.tf comments)."
  type        = list(string)
}

variable "description" {
  type    = string
  default = "Customer-managed key for the Bedrock Knowledge Base MVP (S3 source bucket + OpenSearch Serverless collection)."
}

variable "tags" {
  type    = map(string)
  default = {}
}
