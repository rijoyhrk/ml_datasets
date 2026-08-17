output "function_name" {
  description = "Invoke this from the Azure DevOps pipeline: aws lambda invoke --function-name <this> --cli-read-timeout 900 out.json, then fail the stage on out.json .passed == false."
  value       = aws_lambda_function.qa.function_name
}

output "function_arn" {
  value = aws_lambda_function.qa.arn
}

output "role_arn" {
  description = "The QA harness's own role — not the Story 9 application role. Do not reuse this ARN for the production consuming application."
  value       = aws_iam_role.qa.arn
}
