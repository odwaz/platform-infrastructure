locals {
  name = "wallet-dev"
}

module "networking" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/networking?ref=networking-v1.0.0"

  name = local.name
  cidr = "10.10.0.0/16" # wallet 10.10, gimba 10.20, spaza 10.30, sme 10.40
}

module "eks" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/eks?ref=eks-v1.0.0"

  name                         = local.name
  vpc_id                       = module.networking.vpc_id
  subnet_ids                   = module.networking.private_subnets
  endpoint_public_access_cidrs = var.api_allowed_cidrs
  admin_principal_arn          = var.admin_principal_arn
}

module "rds" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/rds?ref=rds-v1.0.0"

  name                       = local.name
  vpc_id                     = module.networking.vpc_id
  db_subnet_group_name       = module.networking.database_subnet_group_name
  allowed_security_group_ids = [module.eks.node_security_group_id]
  db_name                    = "wallet_db"
  username                   = "wallet_admin"
  password                   = var.db_password
}

module "ecr" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/ecr?ref=ecr-v1.0.0"

  name = "wallet-microservices"
}

module "github_ci_role" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/github-oidc-role?ref=github-oidc-role-v1.0.0"

  name               = "${local.name}-github-ecr-push"
  github_repo        = "odwaz/wallet-micro-dev"
  branch             = "main"
  ecr_repository_arn = module.ecr.repository_arn
}
