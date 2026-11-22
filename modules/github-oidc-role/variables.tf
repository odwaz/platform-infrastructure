variable "name" {
  description = "IAM role name"
  type        = string
}

variable "github_repo" {
  description = "owner/repo allowed to assume the role, e.g. owner/app"
  type        = string
}

variable "subject_prefix" {
  description = <<-EOT
    The repository part of the OIDC subject the role trusts. Leave null for "repo:<github_repo>". A repository with
    GitHub's immutable subject sends "repo:<owner>@<owner id>/<repo>@<repo id>" instead; read it with
    `gh api repos/<owner>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix`.
  EOT
  type        = string
  default     = null

  validation {
    condition     = startswith(coalesce(var.subject_prefix, "repo:"), "repo:")
    error_message = "subject_prefix must start with \"repo:\"."
  }
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
