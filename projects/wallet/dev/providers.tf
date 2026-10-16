provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "wallet"
      Environment = "dev"
      ManagedBy   = "platform-infrastructure/projects/wallet/dev"
    }
  }
}
