# modules/opensearch-vector-index

Creates the Bedrock-compatible vector index (Story 4) inside an
existing OpenSearch Serverless collection, via a Lambda invoked once by
Terraform at apply time — **not** part of the QA test cycle
(`../kb-qa-lambda` is testing; this is provisioning).

## Why a Lambda instead of the `opensearch` Terraform provider

The alternative considered earlier was the community `opensearch`
provider's `opensearch_index` resource, SigV4-signed from wherever
`terraform apply` runs. That has a real problem: if the collection's
network policy is private (our Step 3 decision), whatever makes that
data-plane call must be reachable from inside the VPC — and a CI/CD
pipeline runner usually isn't, without extra infrastructure (a
VPC-attached self-hosted agent, VPN, etc.).

A Lambda sidesteps this cleanly: it can be VPC-attached
(`vpc_subnet_ids`), so it reaches the collection's VPC endpoint
directly regardless of where the pipeline itself runs. This module
adopts that pattern instead.

## Why hand-signed SigV4 instead of `opensearch-py`

`opensearch-py` + `requests-aws4auth` aren't in the default Lambda
Python runtime, which means a Lambda layer just to make one PUT
request. `boto3`/`botocore` **are** already in the runtime, and
`botocore.auth.SigV4Auth` can sign the request directly — one fewer
moving part, no layer to build/version.

## Two-factor authorization, again

Same pattern as the Bedrock KB role (Story 1): IAM permission
(`aoss:APIAccessAll` on the collection ARN) is necessary but not
sufficient. This Lambda's role ARN (`lambda_role_arn` output) must
*also* be added to the OpenSearch Serverless **data access policy**
(Story 3) — the collection will reject the request with a 403 from its
own side otherwise, even with a perfectly correct IAM policy.

## Scope cut: no index deletion

`lifecycle_scope = "CREATE_ONLY"` on the `aws_lambda_invocation` means
`terraform destroy` does not attempt to delete the index — the handler
doesn't implement a delete path. For an MVP/test environment this is
an acceptable, deliberate gap; a production module would need a DELETE
branch in `src/handler.py` and `lifecycle_scope = "CRUD"` before this
gap could be closed.

## Unverified assumption

`aws_lambda_invocation`'s `lifecycle_scope` argument and its
`CREATE_ONLY` value are from training knowledge, not a live-checked
provider doc (this session can't reach registry.terraform.io) — run
`terraform providers schema -json | jq` against your actual provider
version to confirm before relying on it.
