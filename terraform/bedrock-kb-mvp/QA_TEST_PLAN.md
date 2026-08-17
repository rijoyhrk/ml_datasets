# QA Test Plan — Bedrock Knowledge Base RAG Pipeline

## Purpose

Validate, end to end, that a document uploaded to S3 is actually
retrievable and groundable through the deployed Bedrock Knowledge Base —
not just that Terraform applied without error. Each step below is
independently verifiable so a failure points at *which* stage broke,
not just "the Lambda returned false."

## Scope

**Covers:** S3 ingestion path, IAM permissions (KB service role + QA
role), vector index compatibility, `Retrieve`, `RetrieveAndGenerate`.
**Does not cover:** load/performance testing, multi-document corpus
behavior, metadata filtering, the application-facing role from Story 9
(that's a separate test plan once that role exists).

## Prerequisites

- `terraform apply` has completed successfully against
  `terraform/bedrock-kb-mvp/envs/dev` (or wherever the root config
  lives once Steps 4/5/9 are wired up).
- AWS CLI configured with credentials that can invoke the QA Lambda and
  read its CloudWatch Logs (this does **not** need to be the QA role
  itself — it needs `lambda:InvokeFunction` and `logs:GetLogEvents` on
  this function, which is an operator/CI permission, not part of any
  role this stack provisions).
- These `terraform output` values available: `qa_lambda_function_name`,
  `knowledge_base_id`, `data_source_id`, `source_bucket_name`.

Every step below states what to run, what you should see, where the
evidence lives if you need to dig deeper, and what a failure at that
specific step tells you.

---

### Step 1 — Confirm infrastructure is actually deployed

**Setup:** none beyond a completed `terraform apply`.
**Action:**
```bash
terraform output
```
**Expected result:** `qa_lambda_function_name`, `knowledge_base_id`,
`data_source_id`, and `source_bucket_name` are all non-empty.
**Evidence:** the `terraform output` text itself.
**If it fails:** an empty/missing output means that resource never
applied cleanly — check `terraform apply` history before touching the
QA Lambda at all; nothing past this step is meaningful until it's green.

---

### Step 2 — Confirm the QA Lambda deployed with the right code

**Setup:** after Step 1.
**Action:**
```bash
aws lambda get-function --function-name $(terraform output -raw qa_lambda_function_name)
```
**Expected result:** `Configuration.State == "Active"`,
`Configuration.Runtime == "python3.13"`, `Configuration.Timeout` matches
`ingestion_timeout_seconds + 60` from the module's variables.
**Evidence:** the CLI's JSON response.
**If it fails:** `State != Active` usually means the deployment package
failed to build — check `archive_file`'s output path
(`modules/kb-qa-lambda/build/lambda.zip`) actually contains
`handler.py` and `RAG-TEST-001.pdf` (`unzip -l build/lambda.zip`).

---

### Step 3 — Run the end-to-end test

**Setup:** after Step 2.
**Action:**
```bash
aws lambda invoke \
  --function-name $(terraform output -raw qa_lambda_function_name) \
  --cli-read-timeout 900 --payload '{}' out.json
cat out.json
```
**Expected result:** `{"passed": true, "checks": {...}}`. This single
call exercises the entire pipeline — treat it as the headline result;
Steps 4-7 below are how you find out *which* stage broke if it's `false`.
**Evidence:** `out.json`, plus full execution trace in CloudWatch Logs
group `/aws/lambda/<function-name>`.
**If it fails:** read `out.json`'s `"reason"` and `"checks"` fields
first — they name the exact stage that broke (`ingestion_status`,
`retrieve_matched_expected_fact`, `generated_contains_expected_fact`,
etc.) before you go running the manual steps below.

---

### Step 4 — Verify the S3 upload independently

**Setup:** after Step 3 (or standalone — this checks the QA role's own
S3 write, decoupled from everything downstream).
**Action:**
```bash
aws s3 ls s3://$(terraform output -raw source_bucket_name)/qa-test/
```
**Expected result:** `RAG-TEST-001.pdf` listed, with a `LastModified`
timestamp matching your last invoke.
**Evidence:** CLI listing output.
**If it fails:** this isolates an IAM problem specifically — check
CloudWatch Logs for `AccessDenied` on `s3:PutObject`, then check
`modules/kb-qa-lambda/main.tf`'s `SeedTestDocument` statement resource
ARN matches the actual bucket/key.

---

### Step 5 — Verify the ingestion job independently

**Setup:** after Step 4 confirms the document landed in S3.
**Action:**
```bash
aws bedrock-agent list-ingestion-jobs \
  --knowledge-base-id $(terraform output -raw knowledge_base_id) \
  --data-source-id $(terraform output -raw data_source_id)

aws bedrock-agent get-ingestion-job \
  --knowledge-base-id $(terraform output -raw knowledge_base_id) \
  --data-source-id $(terraform output -raw data_source_id) \
  --ingestion-job-id <id from above>
```
**Expected result:** `status == "COMPLETE"`; the `statistics` block
shows `numberOfDocumentsScanned >= 1` and
`numberOfNewDocumentsIndexed >= 1` (or `numberOfModifiedDocumentsIndexed`
on a re-run against the same key).
**Evidence:** the job's `failureReasons` field, if present.
**If it fails:** a `FAILED` status with a permission-shaped
`failureReasons` entry points at the **KB service role** (Step 2 of the
build, not this QA harness) — most commonly missing S3 read, missing
KMS `Decrypt`, or the vector index/field-mapping not matching what the
KB resource expects.

---

### Step 6 — Verify raw retrieval independently (bypass generation)

**Setup:** after Step 5 confirms ingestion completed.
**Action:**
```bash
aws bedrock-agent-runtime retrieve \
  --knowledge-base-id $(terraform output -raw knowledge_base_id) \
  --retrieval-query '{"text":"What is the password rotation period?"}'
```
**Expected result:** `retrievalResults` contains a chunk whose
`content.text` includes "90 days", and `location.s3Location.uri`
contains `qa-test/RAG-TEST-001.pdf`.
**Evidence:** the CLI's JSON output — read the actual chunk boundaries
here to sanity-check the chunking strategy isn't splitting the fact
away from its context.
**If it fails:** empty/irrelevant results with ingestion showing
`COMPLETE` points at the **vector index** — field-mapping name mismatch
between the index and the KB's `storage_configuration`, or an embedding
dimension mismatch (this would usually have failed ingestion outright,
but a silent mismatch is exactly what this step is designed to catch).

---

### Step 7 — Verify RetrieveAndGenerate independently

**Setup:** after Step 6 confirms retrieval works on its own.
**Action:**
```bash
aws bedrock-agent-runtime retrieve-and-generate \
  --input '{"text":"What is the password rotation period?"}' \
  --retrieve-and-generate-configuration '{
    "type": "KNOWLEDGE_BASE",
    "knowledgeBaseConfiguration": {
      "knowledgeBaseId": "'"$(terraform output -raw knowledge_base_id)"'",
      "modelArn": "<generation model ARN>"
    }
  }'
```
**Expected result:** `output.text` contains "90 days"; `citations` is
non-empty and references the test document.
**Evidence:** CLI JSON output.
**If it fails, but Step 6 passed:** the problem is isolated to the
**generation model**, not retrieval — check `bedrock:InvokeModel`
permission on the specific model ARN, and confirm the model is
enabled/authorized in this account+region (model access is granted
per-model, per-region in the Bedrock console and doesn't always match
IAM permissions being correct).

---

### Step 8 — Negative test: irrelevant question shouldn't fabricate the fact

**Setup:** stack in the same state as Step 7.
**Action:** repeat Step 6/7 with an unrelated question, e.g.
`"What is the capital of France?"`
**Expected result:** retrieval returns low-relevance or no results tied
to the password-policy document; the generated answer does not surface
"90 days" in an unrelated context, and does not cite `RAG-TEST-001.pdf`.
**Evidence:** response text + citations, compared against Step 6/7's.
**If it fails:** the model citing the test document for an unrelated
question suggests retrieval is returning too many/too-low-relevance
chunks — tune `numberOfResults` or add a similarity-score threshold in
`retrievalConfiguration`, this is a retrieval-quality tuning issue, not
a correctness bug.

---

### Step 9 — Cleanup (optional)

The test is idempotent — re-running Step 3 overwrites the same S3 key
and re-triggers ingestion, so cleanup isn't required between runs.
If you want the bucket back to an empty baseline:
```bash
aws s3 rm s3://$(terraform output -raw source_bucket_name)/qa-test/RAG-TEST-001.pdf
```
Note this does not remove the vectors already indexed for that
document — a subsequent KB sync with the object deleted is what
actually removes them (this is itself worth its own test once Story 8's
`data_deletion_policy` is configured — not covered by this plan).

---

## Pass/fail summary

| Step | Proves | A failure here means |
|---|---|---|
| 1-2 | Infra deployed | Terraform apply issue, unrelated to Bedrock |
| 3 | Full pipeline (headline result) | See `out.json.reason` |
| 4 | QA role's S3 write | IAM on the QA harness role |
| 5 | Ingestion | KB service role permissions, or KMS |
| 6 | Retrieval/vector index | Field mapping / embedding dimension mismatch |
| 7 | Generation | Model access/permission, not retrieval |
| 8 | Retrieval precision | Tuning, not correctness |

## Automating this

Step 3 alone (the Lambda invoke) is what belongs in the Azure DevOps
pipeline as an automated post-`apply` gate. Steps 4-8 are the manual
diagnostic playbook for when Step 3 goes red — don't run them on every
pipeline execution, they're for a human tracing down a failure.
