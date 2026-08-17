variable "function_name" {
  type    = string
  default = "bedrock-kb-mvp-qa-test"
}

variable "knowledge_base_id" {
  type = string
}

variable "knowledge_base_arn" {
  description = "Used to scope this role's IAM permissions to exactly this KB."
  type        = string
}

variable "data_source_id" {
  type = string
}

variable "source_bucket_name" {
  type = string
}

variable "source_bucket_arn" {
  type = string
}

variable "generation_model_arn" {
  description = "Foundation model used for the RetrieveAndGenerate half of the test."
  type        = string
}

variable "test_s3_key" {
  type    = string
  default = "qa-test/RAG-TEST-001.pdf"
}

variable "expected_fact" {
  type    = string
  default = "90 days"
}

variable "test_question" {
  type    = string
  default = "What is the password rotation period?"
}

variable "ingestion_timeout_seconds" {
  type    = number
  default = 240
  validation {
    # Lambda's hard ceiling is 900s; main.tf adds 60s of headroom on top of
    # this value for the retrieve/generate calls, so this must leave room.
    condition     = var.ingestion_timeout_seconds <= 840
    error_message = "ingestion_timeout_seconds + 60s headroom must not exceed Lambda's 900s maximum timeout."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
