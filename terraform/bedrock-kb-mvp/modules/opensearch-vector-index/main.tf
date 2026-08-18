locals {
  is_vpc_attached      = length(var.vpc_subnet_ids) > 0
  collection_hostname  = replace(var.collection_endpoint, "https://", "")
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/lambda.zip"
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

# Basic logging (and, when VPC-attached, ENI management) come from AWS
# managed policies rather than hand-written statements -- these are
# standard Lambda execution requirements, not application-specific
# permissions worth re-deriving here.
resource "aws_iam_role_policy_attachment" "logging" {
  role       = aws_iam_role.this.name
  policy_arn = local.is_vpc_attached ? "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole" : "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# This is the OTHER principal (besides the Bedrock KB role) that must
# also be listed in the OpenSearch Serverless data access policy --
# IAM permission alone is not sufficient for AOSS, see modules/bedrock-
# knowledge-base/README.md for the same point made about the KB role.
data "aws_iam_policy_document" "aoss_access" {
  statement {
    sid       = "CreateVectorIndex"
    effect    = "Allow"
    actions   = ["aoss:APIAccessAll"]
    resources = [var.collection_arn]
  }
}

resource "aws_iam_role_policy" "aoss_access" {
  name   = "${var.function_name}-aoss-access"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.aoss_access.json
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = aws_iam_role.this.arn
  handler          = "handler.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 30
  memory_size      = 128

  dynamic "vpc_config" {
    for_each = local.is_vpc_attached ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  environment {
    variables = {
      COLLECTION_ENDPOINT = local.collection_hostname
      INDEX_NAME           = var.index_name
      VECTOR_FIELD_NAME    = var.vector_field_name
      TEXT_FIELD_NAME      = var.text_field_name
      METADATA_FIELD_NAME  = var.metadata_field_name
      VECTOR_DIMENSION     = tostring(var.vector_dimension)
    }
  }

  tags = var.tags
}

# Invokes the Lambda once, at apply time, before anything that depends
# on this module's outputs (i.e. before the Knowledge Base resource).
# lifecycle_scope = CREATE_ONLY because the handler only implements
# index *creation* -- deletion on `terraform destroy` isn't handled,
# an intentional scope cut rather than an oversight (see README).
resource "aws_lambda_invocation" "create_index" {
  function_name = aws_lambda_function.this.function_name
  input          = jsonencode({})
  lifecycle_scope = "CREATE_ONLY"

  triggers = {
    index_name       = var.index_name
    vector_dimension = tostring(var.vector_dimension)
    source_hash      = data.archive_file.lambda.output_base64sha256
  }
}
