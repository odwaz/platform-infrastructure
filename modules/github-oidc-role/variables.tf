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
  description = "One ECR repository the role may push to. For several, use ecr_repository_arns"
  type        = string
  default     = null
}

variable "ecr_repository_arns" {
  description = "ECR repositories the role may push to, for a project that builds several images"
  type        = list(string)
  default     = []
}
