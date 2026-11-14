provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "convoy"
      Environment = "staging"
      ManagedBy   = "platform-infrastructure/projects/convoy/staging"
    }
  }
}
