# Wallet's dev environment. Everything is built by the shared app-stack module, so every resource is named after the
# workspace and the workspace can run with the least-privilege role in account/stack.tf. This file holds only the
# wallet's settings.
module "app" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/app-stack?ref=app-stack-v1.0.0"

  name                = "wallet-dev"
  cidr                = "10.10.0.0/16" # wallet 10.10, gimba 10.20, spaza 10.30, sme 10.40, convoy 10.50
  api_allowed_cidrs   = var.api_allowed_cidrs
  admin_principal_arn = var.admin_principal_arn

  # One repository per service, named wallet-dev/<service>, with immutable tags.
  github_repo = "odwaz/wallet-micro-dev"
  images      = ["api-gateway", "auth-service", "wallet-service", "transaction-service", "webhook-service"]

  database = {
    db_name  = "wallet_db"
    username = "wallet_admin"
  }
  db_password = var.db_password
}
