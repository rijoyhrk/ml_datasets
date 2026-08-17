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

resource "aws_iam_role" "qa" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

# Deliberately NOT the Story 9 application role's policy shape: this QA
# harness also needs s3:PutObject and StartIngestionJob to seed and drive
# the test, which the real consuming application must never receive
# (see modules/bedrock-application-access, Story 9). Keep these separate.
data "aws_iam_policy_document" "qa_permissions" {
  statement {
    sid       = "SeedTestDocument"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${var.source_bucket_arn}/${var.test_s3_key}"]
  }

  statement {
    sid    = "DriveIngestion"
    effect = "Allow"
    actions = [
      "bedrock:StartIngestionJob",
      "bedrock:GetIngestionJob",
    ]
    resources = [
      var.knowledge_base_arn,
      "${var.knowledge_base_arn}/data-source/*",
    ]
  }

  statement {
    sid    = "QueryKnowledgeBase"
    effect = "Allow"
    actions = [
      "bedrock:Retrieve",
      "bedrock:RetrieveAndGenerate",
    ]
    resources = [var.knowledge_base_arn]
  }

  statement {
    sid    = "InvokeGenerationModel"
    effect = "Allow"
    actions = ["bedrock:InvokeModel"]
    resources = [var.generation_model_arn]
  }

  statement {
    sid    = "LambdaLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${var.function_name}:*"]
  }
}

resource "aws_iam_role_policy" "qa" {
  name   = "${var.function_name}-permissions"
  role   = aws_iam_role.qa.id
  policy = data.aws_iam_policy_document.qa_permissions.json
}

resource "aws_lambda_function" "qa" {
  function_name    = var.function_name
  role              = aws_iam_role.qa.arn
  handler           = "handler.handler"
  runtime           = "python3.13"
  filename          = data.archive_file.lambda.output_path
  source_code_hash  = data.archive_file.lambda.output_base64sha256
  timeout           = var.ingestion_timeout_seconds + 60
  memory_size       = 256

  environment {
    variables = {
      KNOWLEDGE_BASE_ID         = var.knowledge_base_id
      DATA_SOURCE_ID            = var.data_source_id
      SOURCE_BUCKET_NAME        = var.source_bucket_name
      GENERATION_MODEL_ARN      = var.generation_model_arn
      TEST_S3_KEY               = var.test_s3_key
      EXPECTED_FACT             = var.expected_fact
      TEST_QUESTION             = var.test_question
      INGESTION_TIMEOUT_SECONDS = tostring(var.ingestion_timeout_seconds)
    }
  }

  tags = var.tags
}
