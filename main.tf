terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.6"
}

provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------------------------------
# Variables / locals
# ---------------------------------------------------------------------------

variable "project" {
  description = "Project prefix used to name resources."
  type        = string
  default     = "oyd-exercise-8-2"
}

variable "github_org" {
  description = "GitHub organization or username that owns the repository."
  type        = string
  default     = "SebastianAlecio"
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = "oyd-exercise-8-2"
}

locals {
  # Exact subject claim the OIDC token must present: only main branch of this repo.
  github_sub = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
}

# ---------------------------------------------------------------------------
# Task 1 — GitHub OIDC provider
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ---------------------------------------------------------------------------
# Task 2 — CI runner role trusted via OIDC
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ci_runner" {
  name = "${var.project}-ci-runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          # StringEquals (not StringLike): no wildcard, only this exact repo+branch.
          StringEquals = {
            "token.actions.githubusercontent.com:sub" = local.github_sub
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Minimal read-only policy: enough for `terraform validate`/`plan` to authenticate.
resource "aws_iam_role_policy" "ci_runner_read" {
  name = "${var.project}-ci-runner-read"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "iam:GetOpenIDConnectProvider",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetResourcePolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Task 3 — Database password stored in Secrets Manager
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.project}-db-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = "changeme-in-rotation"

  lifecycle {
    # Future rotations change the value out-of-band; ignore it to avoid drift.
    ignore_changes = [secret_string]
  }
}
