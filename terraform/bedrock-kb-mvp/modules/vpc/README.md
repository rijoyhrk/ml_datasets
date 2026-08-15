# modules/vpc

Private-subnets-only VPC whose sole purpose is hosting the OpenSearch
Serverless VPC endpoint's network interface (Step 3, next module). No NAT
gateway, no internet gateway — nothing in this VPC needs outbound internet,
because Bedrock reaches the private collection via AWS-internal service
private access, not through this VPC. See main.tf for the full reasoning.

## Open question this module doesn't resolve on its own

Whatever runs `terraform apply` for the OpenSearch Serverless vector index
(the `opensearch_index` resource, a **data-plane** call) needs network
access to the collection's endpoint. If the collection's network policy is
private, that means the Terraform executor itself must be reachable from
inside *this* VPC (or connected to it) — not just anyone with valid IAM
credentials. This is a real CI/CD design constraint, not just a security
setting, and it's being surfaced to you as an explicit decision rather than
assumed. See the chat for the question.
