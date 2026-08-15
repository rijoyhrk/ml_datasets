# modules/bedrock-knowledge-base — IAM (Step 2 content)

Currently contains only the Bedrock KB **service role** — the identity
Bedrock itself assumes at runtime. The `aws_bedrockagent_knowledge_base`
resource itself is added here in Step 4, once the OpenSearch Serverless
vector index it depends on exists (Step 3).

## What this is not

This role has no bearing on, and no permissions related to, whatever
identity runs `terraform apply`. See `../../deployer-access/README.md`
for that separate concern.

## Trust policy

Only `bedrock.amazonaws.com` may assume this role, and only for a
knowledge base in this account/region (`aws:SourceAccount` +
`aws:SourceArn` conditions) — this is AWS's documented mitigation for a
knowledge base in a *different* AWS account tricking this role into
acting on its behalf.

## Permissions (all resource-ARN-scoped, no wildcards)

| Statement | Action | Resource | Why |
|---|---|---|---|
| `ReadSourceDocuments` | `s3:GetObject`, `s3:ListBucket` | the one source bucket | ingest documents |
| `InvokeEmbeddingModel` | `bedrock:InvokeModel` | the one embedding model ARN (Titan V2) | embed chunks + queries |
| `OpenSearchServerlessDataPlaneAccess` | `aoss:APIAccessAll` | the one collection | write/query vectors |
| `DecryptWithCustomerManagedKey` (conditional) | `kms:Decrypt`, `kms:GenerateDataKey` | the CMK, if one is used | decrypt KMS-encrypted objects/collection data |

`aoss:APIAccessAll` looks broad, but it's AWS's only available action
for the OpenSearch Serverless data plane — there's no finer-grained
action to request (unlike S3's `GetObject`/`ListBucket` split). The
actual narrowing happens by scoping it to one collection ARN and by
what the *collection's own data access policy* (Step 3) allows this
principal to do inside that collection.
