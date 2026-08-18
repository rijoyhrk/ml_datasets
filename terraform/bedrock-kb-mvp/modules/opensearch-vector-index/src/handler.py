"""
Creates the Bedrock-compatible vector index inside an OpenSearch
Serverless collection. This is a provisioning-time action, invoked once
by Terraform (via aws_lambda_invocation) before the Knowledge Base
resource is created -- NOT part of the QA test cycle (see
../../kb-qa-lambda for that).

Deliberately uses only boto3/botocore (both ship in the Lambda Python
runtime already) to hand-sign the request with SigV4, rather than
pulling in opensearch-py + requests-aws4auth as external dependencies --
avoids needing a Lambda layer for two packages just to do one PUT.

Idempotent: a re-run against an index that already exists with this
definition is treated as success, so re-applying Terraform doesn't fail.
"""
import json
import os
import urllib.request
import urllib.error

import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest


def _index_body():
    dimension = int(os.environ["VECTOR_DIMENSION"])
    return json.dumps({
        "settings": {"index.knn": True},
        "mappings": {
            "properties": {
                os.environ["VECTOR_FIELD_NAME"]: {
                    "type": "knn_vector",
                    "dimension": dimension,
                    "method": {
                        "name": "hnsw",
                        "engine": "faiss",
                        "space_type": "l2",
                    },
                },
                os.environ["TEXT_FIELD_NAME"]: {"type": "text"},
                os.environ["METADATA_FIELD_NAME"]: {"type": "text", "index": False},
            }
        },
    }).encode("utf-8")


def _signed_put(url, body, region):
    request = AWSRequest(method="PUT", url=url, data=body,
                          headers={"Content-Type": "application/json"})
    credentials = boto3.Session().get_credentials()
    # Service name for OpenSearch Serverless SigV4 signing is "aoss",
    # not "es" (that's the older managed-cluster OpenSearch service).
    SigV4Auth(credentials, "aoss", region).add_auth(request)
    return urllib.request.Request(url, data=body, method="PUT",
                                   headers=dict(request.headers))


def handler(event, context):
    endpoint = os.environ["COLLECTION_ENDPOINT"]  # e.g. <id>.<region>.aoss.amazonaws.com
    index_name = os.environ["INDEX_NAME"]
    region = os.environ["AWS_REGION"]

    url = f"https://{endpoint}/{index_name}"
    body = _index_body()
    req = _signed_put(url, body, region)

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return {"statusCode": resp.status, "body": resp.read().decode(), "created": True}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode()
        if e.code == 400 and "resource_already_exists_exception" in err_body:
            return {"statusCode": 200, "body": "index already exists", "created": False}
        raise RuntimeError(f"Index creation failed ({e.code}): {err_body}") from e


if __name__ == "__main__":
    print(json.dumps(handler({}, None), indent=2))
