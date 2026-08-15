terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60.0" # ASSUMPTION: revisit at Step 4 (KB resource) — verify against
                             # the changelog for aws_bedrockagent_knowledge_base's
                             # embedding_model_configuration argument before pinning tighter.
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}
