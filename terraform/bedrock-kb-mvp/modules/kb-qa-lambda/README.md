# modules/kb-qa-lambda

One Lambda function, one bundled test PDF, no test framework — the
simplest end-to-end proof that ingestion → embedding → vector storage →
retrieval → generation actually works, using a synthetic fact
("password rotation period: 90 days") that can't be answered by an
unaugmented foundation model, so a passing test proves grounding, not
just fluency.

## Requires

- `hashicorp/archive` provider (for zipping `src/`) — add to the root
  `versions.tf` alongside `aws` and `random`.
- Python 3.13 available at build time is *not* required locally — the
  Lambda runtime provides it; `src/handler.py` only uses `boto3`, which
  ships in the Lambda Python runtime already.

## Not verified against a live API reference

I could not fetch `docs.aws.amazon.com` from this session, so the
`bedrock-agent` / `bedrock-agent-runtime` field names in `src/handler.py`
(`retrievalResults`, `retrieveAndGenerateConfiguration`, `citations`,
etc.) come from training knowledge, not a live-checked doc. First run
will surface any drift as a `KeyError` — check that against the current
boto3 `bedrock-agent-runtime` docs before assuming the pipeline itself
is broken.

## Wiring (once Stories 6-8 exist)

```hcl
module "kb_qa" {
  source                = "../modules/kb-qa-lambda"
  knowledge_base_id     = module.bedrock_knowledge_base.knowledge_base_id
  knowledge_base_arn    = module.bedrock_knowledge_base.knowledge_base_arn
  data_source_id        = module.bedrock_data_source.data_source_id
  source_bucket_name    = aws_s3_bucket.kb_source.id
  source_bucket_arn     = aws_s3_bucket.kb_source.arn
  generation_model_arn  = local.generation_model_arn
  tags                  = local.tags
}
```

## Running it

```bash
aws lambda invoke --function-name $(terraform output -raw qa_function_name) \
  --cli-read-timeout 900 --payload '{}' out.json
cat out.json   # {"passed": true, "checks": {...}}
```

Wire that into the Azure DevOps pipeline as a post-`apply` stage that
fails on `passed == false` — no additional test framework needed for
this MVP. If the assertion surface needs to grow later (metadata
filtering, multiple documents, negative tests for "document doesn't
exist"), that's the point to introduce pytest instead of hand-rolled
`if`s — not before.
