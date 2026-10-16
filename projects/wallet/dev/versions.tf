terraform {
  required_version = ">= 1.5.7"

  cloud {
    organization = "devwork"

    workspaces {
      name = "wallet-dev"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
