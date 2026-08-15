# --- Minimal VPC: private subnets only, no NAT/IGW ---
# Nothing in this VPC runs compute. Its sole purpose is to host the network
# interface for the OpenSearch Serverless VPC endpoint (Step 3, next file).
# Bedrock itself reaches the private collection via AWS-internal service
# private access (the network policy's SourceServices field), NOT through
# this VPC — so there is no path here that ever needs internet egress.
# If a future step adds compute (e.g. a Lambda for custom ingestion
# triggers) that needs outbound internet, a NAT gateway becomes a real,
# separate cost/complexity decision at that point — not assumed now.

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = merge(var.tags, { Name = "${var.name_prefix}-private-${count.index}" })
}

# Endpoint-only security group: allows HTTPS from within the VPC's own CIDR.
# No 0.0.0.0/0 anywhere — nothing outside this VPC should ever reach the
# endpoint directly (Bedrock's path bypasses it entirely, as noted above).
resource "aws_security_group" "opensearch_endpoint" {
  name_prefix = "${var.name_prefix}-aoss-endpoint-"
  description = "Allows HTTPS to the OpenSearch Serverless VPC endpoint from within this VPC only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from within the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
