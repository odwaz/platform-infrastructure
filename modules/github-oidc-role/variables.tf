variable "name" {
  description = "IAM role name"
  type        = string
}

variable "github_repo" {
  description = "owner/repo allowed to assume the role, e.g. odwaz/wallet-micro-dev"
  type        = string
}

variable "branch" {
  description = "Only workflow runs on this branch can assume the role"
  type        = string
  default     = "main"
}

variable "ecr_repository_arn" {
  type = string
}
