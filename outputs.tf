output "ci_runner_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC."
  value       = aws_iam_role.ci_runner.arn
}

output "db_password_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the DB password."
  value       = aws_secretsmanager_secret.db_password.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider."
  value       = aws_iam_openid_connect_provider.github.arn
}
