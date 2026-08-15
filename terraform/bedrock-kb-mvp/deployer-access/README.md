# Terraform deployer permissions (reference only — not applied by this stack)

This policy is for the **human or CI/CD identity that runs `terraform apply`**
against `terraform/bedrock-kb-mvp/` — it is deliberately separate from the
Bedrock Knowledge Base service role that Terraform provisions in
`modules/bedrock-knowledge-base/`.

## Why this isn't a Terraform resource in this repo

Terraform cannot grant itself the permissions it needs to run — whatever
identity executes `terraform apply` for the very first time must already
have rights to create IAM roles, S3 buckets, etc. That's a one-time
account-bootstrap action, taken by an account/org admin outside this
module, not something this MVP's `terraform apply` can do to itself.

## Who to attach this to

- **Local/learning use:** your own IAM user or an assumed SSO role.
- **CI/CD (e.g., Azure DevOps):** the OIDC-federated service connection role
  used by the pipeline — attach this policy (or fold it into a permission
  boundary) to that role, not to a long-lived access key.

## Scope notes

- `iam:PassRole` is restricted with `iam:PassedToService = bedrock.amazonaws.com`
  so this identity can hand off the Bedrock KB role *only* to Bedrock — not
  attach it to, say, an EC2 instance or Lambda function.
- `aoss:APIAccessAll` is included here because creating the **vector index**
  (Step 3) is a data-plane call made via the `opensearch` Terraform provider
  using this identity's SigV4 credentials — the OpenSearch Serverless data
  access policy will need to list this identity for that reason, separately
  from why it lists the Bedrock KB role.
- No DynamoDB permissions: Terraform >= 1.11's native S3 state locking
  (`use_lockfile = true`) is used instead of a DynamoDB lock table. See
  [S3 backend locking](https://developer.hashicorp.com/terraform/language/backend/s3#state-locking).
- Resource ARNs use this project's naming prefix (`bedrock-kb-mvp-*`) where
  policy-language allows scoping by name; a handful of actions (e.g.
  `ec2:CreateVpc`, `aoss:CreateCollection`) are account/type-level create
  calls that AWS does not support resource-ARN-scoping for at creation time.

## Verify before use

I have not been able to load the live IAM Action reference in this session
(outbound fetches to `docs.aws.amazon.com` are proxy-blocked here), so
treat the action list as a reasonable, search-grounded starting point —
run `terraform plan` and let AWS's own `AccessDenied` errors tell you if
any action name or resource pattern is wrong, then tighten/correct here.
