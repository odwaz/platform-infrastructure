# Convoy's staging environment, the cloud one: releases arrive here by promotion after they pass on dev, a local
# cluster. Everything is built by the shared app-stack module; this file holds only Convoy's settings.
module "app" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/app-stack?ref=app-stack-v1.1.0"

  name                = "convoy-staging"
  cidr                = "10.50.0.0/16" # wallet 10.10, gimba 10.20, spaza 10.30, sme 10.40, convoy 10.50
  api_allowed_cidrs   = var.api_allowed_cidrs
  admin_principal_arn = var.admin_principal_arn

  github_repo = "odwaz/convoy"
  # The repository uses GitHub's immutable OIDC subject (owner and repository IDs), so its builds are trusted by ID.
  github_subject_prefix = "repo:odwaz@4050682/convoy@1437309448"
  images                = ["gateway", "ingest-service", "tracking-service", "operations-service", "simulator", "web"]

  database = {
    db_name  = "convoy"
    username = "convoy"
  }
  db_password = var.db_password

  # Convoy's dev environment is a local kind cluster, which can pull the same images from outside AWS.
  external_pull_user = true
}
