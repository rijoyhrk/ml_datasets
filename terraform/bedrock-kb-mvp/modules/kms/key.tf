data "aws_caller_identity" "current" {}

# Key policy deliberately does NOT list the Bedrock KB role ARN directly.
# Statement 1 delegates key *usage* decisions to IAM policy (the standard
# AWS-recommended pattern) — this is what lets modules/bedrock-knowledge-base
# grant itself kms:Decrypt via its own IAM role policy without this module
# needing to know that role's ARN, avoiding a circular module dependency
# (bedrock-knowledge-base needs this key's ARN; this key would otherwise
# need that role's ARN back).
#
# Statement 2 is the one KMS permission IAM policy *cannot* substitute for:
# OpenSearch Serverless creates a KMS grant on your behalf when the
# collection's encryption policy references this key, and that requires an
# explicit service-principal statement in the key policy itself.
# https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless-encryption.html
data "aws_iam_policy_document" "key_policy" {
  statement {
    sid     = "EnableIamPolicyDelegation"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }

  statement {
    sid    = "AllowKeyAdministration"
    effect = "Allow"
    actions = [
      "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
      "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
      "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
      "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
    ]
    principals {
      type        = "AWS"
      identifiers = var.key_admin_arns
    }
    resources = ["*"]
  }

  statement {
    sid     = "AllowOpenSearchServerlessToUseKey"
    effect  = "Allow"
    actions = ["kms:DescribeKey", "kms:CreateGrant"]
    principals {
      type        = "Service"
      identifiers = ["aoss.amazonaws.com"]
    }
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = var.description
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.key_policy.json
  tags                    = var.tags
}

resource "aws_kms_alias" "this" {
  name          = var.alias_name
  target_key_id = aws_kms_key.this.key_id
}
