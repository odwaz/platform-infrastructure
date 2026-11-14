provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "convoy"
      Environment = "dev"
      ManagedBy   = "platform-infrastructure/projects/convoy/dev"
    }
  }
}
