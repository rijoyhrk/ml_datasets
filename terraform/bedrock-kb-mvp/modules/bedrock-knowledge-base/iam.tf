# --- Step 2: Bedrock's runtime identity — deliberately separate from ---
# --- whatever identity is running `terraform apply` (see              ---
# --- ../../deployer-access/README.md for that side of the split).     ---

# Trust policy: only the Bedrock service may assume this role, and only
# when acting on behalf of a knowledge base in *this* account/region —
# the SourceAccount/SourceArn condition is AWS's documented mitigation
# for the "confused deputy" problem (some other account's Bedrock KB
# tricking this role into acting for them).
# https://docs.aws.amazon.com/bedrock/latest/userguide/kb-permissions.html
data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AllowBedrockToAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.aws_account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:${var.aws_region}:${var.aws_account_id}:knowledge-base/*"]
    }
  }
}

resource "aws_iam_role" "bedrock_kb" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

# Permissions: exactly three things this role needs to do its job, each
# scoped to a single resource ARN — no wildcards, no "just in case" actions.
data "aws_iam_policy_document" "permissions" {
  statement {
    sid       = "ReadSourceDocuments"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [var.s3_bucket_arn, "${var.s3_bucket_arn}/*"]
  }

  statement {
    sid       = "InvokeEmbeddingModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = [var.embedding_model_arn]
  }

  statement {
    sid       = "OpenSearchServerlessDataPlaneAccess"
    effect    = "Allow"
    actions   = ["aoss:APIAccessAll"]
    resources = [var.opensearch_collection_arn]
  }

  dynamic "statement" {
    for_each = var.kms_key_arn == null ? [] : [var.kms_key_arn]
    content {
      sid       = "DecryptWithCustomerManagedKey"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [statement.value]
    }
  }
}

resource "aws_iam_role_policy" "bedrock_kb" {
  name   = "${var.role_name}-permissions"
  role   = aws_iam_role.bedrock_kb.id
  policy = data.aws_iam_policy_document.permissions.json
}
