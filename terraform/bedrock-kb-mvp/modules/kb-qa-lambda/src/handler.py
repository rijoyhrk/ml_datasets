"""
End-to-end QA for the Bedrock Knowledge Base RAG pipeline.

Uploads a known test PDF, triggers ingestion, then verifies both raw
retrieval and RetrieveAndGenerate return the synthetic fact the PDF
contains. Field names for the bedrock-agent / bedrock-agent-runtime
responses are from training knowledge, not a live-verified API
reference (this session couldn't reach docs.aws.amazon.com) --
cross-check against the boto3 docs if anything here throws a KeyError.

Environment variables (set by Terraform from KB/data-source outputs):
  KNOWLEDGE_BASE_ID        - Story 7 output
  DATA_SOURCE_ID           - Story 8 output
  SOURCE_BUCKET_NAME       - Step 1 output
  GENERATION_MODEL_ARN     - the FM used for RetrieveAndGenerate
  TEST_S3_KEY              - defaults to qa-test/RAG-TEST-001.pdf
  EXPECTED_FACT            - substring that must appear in results
  TEST_QUESTION            - the question to ask
  INGESTION_TIMEOUT_SECONDS - default 240
"""
import json
import os
import time

import boto3

s3 = boto3.client("s3")
bedrock_agent = boto3.client("bedrock-agent")
bedrock_agent_runtime = boto3.client("bedrock-agent-runtime")

TEST_S3_KEY = os.environ.get("TEST_S3_KEY", "qa-test/RAG-TEST-001.pdf")
EXPECTED_FACT = os.environ.get("EXPECTED_FACT", "90 days")
TEST_QUESTION = os.environ.get("TEST_QUESTION", "What is the password rotation period?")
INGESTION_TIMEOUT_SECONDS = int(os.environ.get("INGESTION_TIMEOUT_SECONDS", "240"))
PDF_PATH = os.path.join(os.path.dirname(__file__), "RAG-TEST-001.pdf")


def _fail(checks, reason):
    return {"passed": False, "reason": reason, "checks": checks}


def handler(event, context):
    kb_id = os.environ["KNOWLEDGE_BASE_ID"]
    ds_id = os.environ["DATA_SOURCE_ID"]
    bucket = os.environ["SOURCE_BUCKET_NAME"]
    model_arn = os.environ["GENERATION_MODEL_ARN"]

    checks = {}

    # --- 1. Seed: upload the known test document ---
    with open(PDF_PATH, "rb") as f:
        s3.put_object(Bucket=bucket, Key=TEST_S3_KEY, Body=f.read(), ContentType="application/pdf")
    checks["s3_upload"] = "ok"

    # --- 2. Trigger ingestion and wait for it to finish ---
    start = bedrock_agent.start_ingestion_job(knowledgeBaseId=kb_id, dataSourceId=ds_id)
    job_id = start["ingestionJob"]["ingestionJobId"]

    deadline = time.time() + INGESTION_TIMEOUT_SECONDS
    status = None
    while time.time() < deadline:
        job = bedrock_agent.get_ingestion_job(
            knowledgeBaseId=kb_id, dataSourceId=ds_id, ingestionJobId=job_id
        )["ingestionJob"]
        status = job["status"]
        if status in ("COMPLETE", "FAILED"):
            break
        time.sleep(10)

    checks["ingestion_status"] = status
    if status != "COMPLETE":
        return _fail(checks, f"ingestion did not complete (status={status})")

    # --- 3. Retrieve: prove grounding independent of generation ---
    retrieval = bedrock_agent_runtime.retrieve(
        knowledgeBaseId=kb_id,
        retrievalQuery={"text": TEST_QUESTION},
        retrievalConfiguration={"vectorSearchConfiguration": {"numberOfResults": 3}},
    )
    results = retrieval.get("retrievalResults", [])
    matched = [r for r in results if EXPECTED_FACT in r.get("content", {}).get("text", "")]
    checks["retrieve_result_count"] = len(results)
    checks["retrieve_matched_expected_fact"] = bool(matched)
    source_uris = [r.get("location", {}).get("s3Location", {}).get("uri", "") for r in matched]
    checks["retrieve_source_matches_upload"] = any(TEST_S3_KEY in uri for uri in source_uris)

    if not matched:
        return _fail(checks, "Retrieve did not return the expected fact")

    # --- 4. RetrieveAndGenerate: prove the full RAG loop ---
    rag = bedrock_agent_runtime.retrieve_and_generate(
        input={"text": TEST_QUESTION},
        retrieveAndGenerateConfiguration={
            "type": "KNOWLEDGE_BASE",
            "knowledgeBaseConfiguration": {
                "knowledgeBaseId": kb_id,
                "modelArn": model_arn,
            },
        },
    )
    generated_text = rag.get("output", {}).get("text", "")
    checks["generated_contains_expected_fact"] = EXPECTED_FACT in generated_text
    citations = rag.get("citations", [])
    checks["citation_count"] = len(citations)

    if EXPECTED_FACT not in generated_text:
        return _fail(checks, "RetrieveAndGenerate answer did not contain the expected fact")
    if not citations:
        return _fail(checks, "RetrieveAndGenerate returned no citations")

    return {"passed": True, "checks": checks}


if __name__ == "__main__":
    print(json.dumps(handler({}, None), indent=2))
