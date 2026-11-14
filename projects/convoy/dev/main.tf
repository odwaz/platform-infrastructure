# Convoy's development environment. Everything is built by the shared app-stack module; this file holds only
# Convoy's settings.
module "app" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/app-stack?ref=app-stack-v1.0.0"

  name                = "convoy-dev"
  cidr                = "10.50.0.0/16" # wallet 10.10, gimba 10.20, spaza 10.30, sme 10.40, convoy 10.50
  api_allowed_cidrs   = var.api_allowed_cidrs
  admin_principal_arn = var.admin_principal_arn

  github_repo = "odwaz/convoy"
  images      = ["gateway", "ingest-service", "tracking-service", "operations-service", "simulator", "web"]

  database = {
    db_name  = "convoy"
    username = "convoy"
  }
  db_password = var.db_password

  # Convoy's first environment is a local kind cluster, which pulls the same images from outside AWS.
  external_pull_user = true
}
