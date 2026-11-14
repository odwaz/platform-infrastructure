locals {
  name = "convoy-dev"

  # The images Convoy's Images workflow builds, one ECR repository each, named like their GHCR packages
  # (ghcr.io/odwaz/convoy-gateway -> convoy-gateway). ECR is Convoy's only registry: kind and EKS both pull from it,
  # so a tag promoted from one to the other is the same image.
  images = ["gateway", "ingest-service", "tracking-service", "operations-service", "simulator", "web"]
}

module "networking" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/networking?ref=networking-v1.0.0"

  name = local.name
  cidr = "10.50.0.0/16" # wallet 10.10, gimba 10.20, spaza 10.30, sme 10.40, convoy 10.50
}

# eks-v1.1.0 adds the EBS CSI driver, which Convoy's in-cluster Kafka needs for its volume.
module "eks" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/eks?ref=eks-v1.1.0"

  name                         = local.name
  vpc_id                       = module.networking.vpc_id
  subnet_ids                   = module.networking.private_subnets
  endpoint_public_access_cidrs = var.api_allowed_cidrs
  admin_principal_arn          = var.admin_principal_arn
}

# PostgreSQL 17, as Convoy runs locally (postgis/postgis:17). PostGIS is an extension RDS provides; it is enabled
# from the cluster, not here. RDS for PostgreSQL 15 and later requires TLS, so the apps must connect with SSL.
module "rds" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/rds?ref=rds-v1.0.0"

  name                       = local.name
  vpc_id                     = module.networking.vpc_id
  db_subnet_group_name       = module.networking.database_subnet_group_name
  allowed_security_group_ids = [module.eks.node_security_group_id]
  engine_version             = "17"
  db_name                    = "convoy"
  username                   = "convoy"
  password                   = var.db_password
}

# ecr-v1.1.0 makes tags immutable: a commit's tag can never be pushed again with different contents.
module "ecr" {
  for_each = toset(local.images)
  source   = "git::https://github.com/odwaz/platform-infrastructure.git//modules/ecr?ref=ecr-v1.1.0"

  name = "convoy-${each.key}"
}

# kind runs outside AWS, so it cannot pull with the EKS nodes' role. This user may only pull Convoy's images. Its
# access key is created by hand and kept in the kind cluster, so it never appears in Terraform state.
resource "aws_iam_user" "kind_pull" {
  name = "${local.name}-kind-ecr-pull"
}

data "aws_iam_policy_document" "kind_pull" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    resources = [for repository in module.ecr : repository.repository_arn]
  }
}

resource "aws_iam_user_policy" "kind_pull" {
  name   = "ecr-pull"
  user   = aws_iam_user.kind_pull.name
  policy = data.aws_iam_policy_document.kind_pull.json
}

# Lets Convoy's Images workflow push to the repositories above, from main only, without a stored AWS key.
module "github_ci_role" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/github-oidc-role?ref=github-oidc-role-v1.1.0"

  name                = "${local.name}-github-ecr-push"
  github_repo         = "odwaz/convoy"
  branch              = "main"
  ecr_repository_arns = [for repository in module.ecr : repository.repository_arn]
}
