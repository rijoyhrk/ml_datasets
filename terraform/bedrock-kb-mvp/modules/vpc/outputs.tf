output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "opensearch_endpoint_security_group_id" {
  value = aws_security_group.opensearch_endpoint.id
}
