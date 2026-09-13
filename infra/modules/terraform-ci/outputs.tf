output "role_arn" {
  description = "ARN of the GitHub Actions Terraform CI role"
  value       = aws_iam_role.terraform_ci.arn
}
