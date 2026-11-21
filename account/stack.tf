# The permissions of a least-privilege Terraform Cloud role: what one workspace needs to build and destroy its
# modules/app-stack stack, and nothing outside it. Every resource app-stack creates is named after the workspace
# (its `name`, e.g. <app>-<env>), so:
#
#   - IAM, EKS, RDS, ECR and the EKS log group are limited to that name;
#   - EC2 networking and new KMS keys, which AWS addresses by generated IDs, are limited to the stack's region, and
#     KMS key management to keys carrying the stack's ManagedBy tag;
#   - reads are open, because Terraform refreshes state before every plan;
#   - access keys, console passwords, admin policies, Organizations and account settings are always denied.
#
# A missing permission shows as an AccessDenied error naming the action on the next plan or apply; add it here.

locals {
  account_id = data.aws_caller_identity.current.account_id
  admin_policies = [
    "arn:aws:iam::aws:policy/AdministratorAccess",
    "arn:aws:iam::aws:policy/PowerUserAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
  ]
}

data "aws_iam_policy_document" "stack" {
  for_each = { for k, w in local.workspaces : k => w if w.least_privilege }

  statement {
    sid = "Read"
    actions = [
      "ec2:Describe*", "eks:Describe*", "eks:List*", "rds:Describe*", "rds:ListTagsForResource",
      "ecr:Describe*", "ecr:List*", "ecr:Get*", "kms:Describe*", "kms:Get*", "kms:List*",
      "logs:Describe*", "logs:ListTagsForResource", "logs:ListTagsLogGroup", "iam:Get*", "iam:List*",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "EksPublicParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${each.value.region}::parameter/aws/service/*"]
  }

  statement {
    sid = "Ec2NetworkingInRegion"
    actions = [
      "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
      "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute",
      "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
      "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:AssociateAddress", "ec2:DisassociateAddress",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress", "ec2:ModifySecurityGroupRules",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress", "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
      "ec2:CreateNetworkAcl", "ec2:DeleteNetworkAcl", "ec2:CreateNetworkAclEntry", "ec2:DeleteNetworkAclEntry",
      "ec2:ReplaceNetworkAclEntry", "ec2:ReplaceNetworkAclAssociation",
      "ec2:CreateLaunchTemplate", "ec2:CreateLaunchTemplateVersion", "ec2:ModifyLaunchTemplate",
      "ec2:DeleteLaunchTemplate", "ec2:DeleteLaunchTemplateVersions",
      "ec2:RunInstances",
      "ec2:CreateTags", "ec2:DeleteTags",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [each.value.region]
    }
  }

  statement {
    sid     = "EksCluster"
    actions = ["eks:*"]
    resources = [
      "arn:aws:eks:${each.value.region}:${local.account_id}:cluster/${each.key}",
      "arn:aws:eks:${each.value.region}:${local.account_id}:nodegroup/${each.key}/*",
      "arn:aws:eks:${each.value.region}:${local.account_id}:addon/${each.key}/*",
      "arn:aws:eks:${each.value.region}:${local.account_id}:access-entry/${each.key}/*",
      "arn:aws:eks:${each.value.region}:${local.account_id}:podidentityassociation/${each.key}/*",
    ]
  }

  statement {
    sid     = "RdsInstance"
    actions = ["rds:*"]
    resources = [
      "arn:aws:rds:${each.value.region}:${local.account_id}:db:${each.key}-*",
      "arn:aws:rds:${each.value.region}:${local.account_id}:subgrp:${each.key}*",
    ]
  }

  # Creating an instance also authorizes against the default parameter and option groups it uses.
  statement {
    sid     = "RdsDefaultGroups"
    actions = ["rds:CreateDBInstance", "rds:ModifyDBInstance"]
    resources = [
      "arn:aws:rds:${each.value.region}:${local.account_id}:pg:default.*",
      "arn:aws:rds:${each.value.region}:${local.account_id}:og:default:*",
    ]
  }

  statement {
    sid       = "EcrRepositories"
    actions   = ["ecr:*"]
    resources = ["arn:aws:ecr:${each.value.region}:${local.account_id}:repository/${each.key}/*"]
  }

  statement {
    sid = "EksLogGroup"
    actions = [
      "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
      "logs:TagResource", "logs:UntagResource", "logs:TagLogGroup", "logs:UntagLogGroup",
      "logs:AssociateKmsKey", "logs:DisassociateKmsKey",
    ]
    resources = ["arn:aws:logs:${each.value.region}:${local.account_id}:log-group:/aws/eks/${each.key}/*"]
  }

  statement {
    sid       = "KmsCreateTaggedKey"
    actions   = ["kms:CreateKey", "kms:TagResource"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [each.value.region]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/ManagedBy"
      values   = [each.value.managed_by]
    }
  }

  statement {
    sid = "KmsManageOwnKeys"
    actions = [
      "kms:CreateAlias", "kms:DeleteAlias", "kms:UpdateAlias", "kms:CreateGrant", "kms:RetireGrant",
      "kms:EnableKeyRotation", "kms:DisableKeyRotation", "kms:PutKeyPolicy", "kms:TagResource",
      "kms:UntagResource", "kms:UpdateKeyDescription", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
      "kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*",
    ]
    resources = ["arn:aws:kms:${each.value.region}:${local.account_id}:key/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/ManagedBy"
      values   = [each.value.managed_by]
    }
  }

  statement {
    sid       = "KmsOwnAliases"
    actions   = ["kms:CreateAlias", "kms:DeleteAlias", "kms:UpdateAlias"]
    resources = ["arn:aws:kms:${each.value.region}:${local.account_id}:alias/eks/${each.key}*"]
  }

  statement {
    sid = "IamStackNames"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy", "iam:TagRole",
      "iam:UntagRole", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion", "iam:TagPolicy", "iam:UntagPolicy",
      "iam:CreateUser", "iam:DeleteUser", "iam:TagUser", "iam:UntagUser", "iam:PutUserPolicy",
      "iam:DeleteUserPolicy",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${each.key}-*",
      "arn:aws:iam::${local.account_id}:policy/${each.key}-*",
      "arn:aws:iam::${local.account_id}:user/${each.key}-*",
    ]
  }

  statement {
    sid       = "PassStackRoles"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${each.key}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["eks.amazonaws.com", "pods.eks.amazonaws.com", "ec2.amazonaws.com"]
    }
  }

  statement {
    sid       = "ServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["eks.amazonaws.com", "eks-nodegroup.amazonaws.com", "rds.amazonaws.com", "autoscaling.amazonaws.com"]
    }
  }

  statement {
    sid    = "DenyAccountWide"
    effect = "Deny"
    actions = [
      "iam:CreateAccessKey", "iam:UpdateAccessKey", "iam:CreateLoginProfile", "iam:UpdateLoginProfile",
      "organizations:*", "account:*",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenyAdminPolicies"
    effect    = "Deny"
    actions   = ["iam:AttachRolePolicy", "iam:AttachUserPolicy", "iam:AttachGroupPolicy"]
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = local.admin_policies
    }
  }
}
