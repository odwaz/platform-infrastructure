# One application's isolated environment: its own network, cluster, optional database, image repositories and the
# role its CI pushes with. A project calls this once per environment; nothing here is specific to one application.
#
# The modules below are referenced by relative path, so they always come from the same commit as this one: tag this
# module (app-stack-vX.Y.Z) and every part of the stack is pinned together.

module "networking" {
  source = "../networking"

  name = var.name
  cidr = var.cidr
}

module "eks" {
  source = "../eks"

  name                         = var.name
  vpc_id                       = module.networking.vpc_id
  subnet_ids                   = module.networking.private_subnets
  endpoint_public_access_cidrs = var.api_allowed_cidrs
  admin_principal_arn          = var.admin_principal_arn
  instance_types               = var.instance_types
  min_size                     = var.node_count
  desired_size                 = var.node_count
  max_size                     = var.node_count * 2
}

# RDS for PostgreSQL 15 and later accepts only encrypted connections, so apps must connect with TLS.
module "rds" {
  count  = var.database == null ? 0 : 1
  source = "../rds"

  name                       = var.name
  vpc_id                     = module.networking.vpc_id
  db_subnet_group_name       = module.networking.database_subnet_group_name
  allowed_security_group_ids = [module.eks.node_security_group_id]
  engine_version             = var.database.engine_version
  instance_class             = var.database.instance_class
  db_name                    = var.database.db_name
  username                   = var.database.username
  password                   = var.db_password
}

# A database needs its password; fail at plan time rather than in the RDS API.
resource "terraform_data" "database_password" {
  count = var.database == null ? 0 : 1

  lifecycle {
    precondition {
      condition     = var.db_password != null && length(coalesce(var.db_password, "")) >= 8
      error_message = "database is set, so db_password must be set too, with at least 8 characters."
    }
  }
}

# Immutable tags (the ecr module's default): a pushed tag always names the same image, so a tag promoted from one
# environment to the next is the image that was tested.
module "ecr" {
  for_each = toset(var.images)
  source   = "../ecr"

  name = "${var.name}/${each.key}"
}

# Lets the app's CI push to its repositories from var.branch only, without a stored AWS key.
module "github_ci_role" {
  count  = length(var.images) > 0 ? 1 : 0
  source = "../github-oidc-role"

  name                = "${var.name}-github-ecr-push"
  github_repo         = var.github_repo
  branch              = var.branch
  ecr_repository_arns = [for repository in module.ecr : repository.repository_arn]
}

# A cluster outside AWS cannot pull with the nodes' role. This user may only pull this app's images.
resource "aws_iam_user" "external_pull" {
  count = var.external_pull_user && length(var.images) > 0 ? 1 : 0
  name  = "${var.name}-external-ecr-pull"
}

data "aws_iam_policy_document" "external_pull" {
  count = length(aws_iam_user.external_pull)

  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    resources = [for repository in module.ecr : repository.repository_arn]
  }
}

resource "aws_iam_user_policy" "external_pull" {
  count  = length(aws_iam_user.external_pull)
  name   = "ecr-pull"
  user   = aws_iam_user.external_pull[0].name
  policy = data.aws_iam_policy_document.external_pull[0].json
}
