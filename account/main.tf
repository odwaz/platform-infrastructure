terraform {
  required_version = ">= 1.5.7"

  cloud {
    organization = "devwork"

    workspaces {
      name = "account"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# One OIDC provider per issuer per AWS account.
resource "aws_iam_openid_connect_provider" "tfc" {
  url            = "https://app.terraform.io"
  client_id_list = ["aws.workload.identity"]
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# One Terraform Cloud role per project workspace.
# To add a project later, add its workspace name to this list.
locals {
  workspaces = ["wallet-dev"]
}

resource "aws_iam_role" "tfc" {
  for_each = toset(local.workspaces)
  name     = "tfc-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.tfc.arn }
      Condition = {
        StringEquals = { "app.terraform.io:aud" = "aws.workload.identity" }
        StringLike   = { "app.terraform.io:sub" = "organization:devwork:project:*:workspace:${each.key}:run_phase:*" }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "tfc_admin" {
  for_each   = aws_iam_role.tfc
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "tfc_role_arns" {
  value = { for k, r in aws_iam_role.tfc : k => r.arn }
}
