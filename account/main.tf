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

data "aws_caller_identity" "current" {}

# One Terraform Cloud role per project workspace. To add a project, add its workspace here.
#
#   region          - the region its stack is built in
#   managed_by      - its provider's ManagedBy default tag, which marks the KMS keys it may manage
#   least_privilege - true for stacks built with modules/app-stack: the role may change only resources named after
#                     its workspace (see stack.tf). false keeps AdministratorAccess, for stacks built on the older
#                     pinned modules, whose names don't follow that rule.
locals {
  workspaces = {
    "wallet-dev" = {
      region          = "us-east-1"
      managed_by      = "platform-infrastructure/projects/wallet/dev"
      least_privilege = true
    }
    "convoy-staging" = {
      region          = "af-south-1"
      managed_by      = "platform-infrastructure/projects/convoy/staging"
      least_privilege = true
    }
  }
}

resource "aws_iam_role" "tfc" {
  for_each = local.workspaces
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
  for_each   = { for k, w in local.workspaces : k => aws_iam_role.tfc[k] if !w.least_privilege }
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy" "tfc_stack" {
  for_each = { for k, w in local.workspaces : k => w if w.least_privilege }
  name     = "stack"
  role     = aws_iam_role.tfc[each.key].name
  policy   = data.aws_iam_policy_document.stack[each.key].json
}

output "tfc_role_arns" {
  value = { for k, r in aws_iam_role.tfc : k => r.arn }
}
