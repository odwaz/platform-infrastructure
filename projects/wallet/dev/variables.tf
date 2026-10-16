variable "db_password" {
  description = "RDS master password (set in Terraform Cloud, sensitive)"
  type        = string
  sensitive   = true
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API, e.g. [\"66.251.128.3/32\"]"
  type        = list(string)
}

variable "admin_principal_arn" {
  description = "Your IAM role/user ARN, given cluster-admin"
  type        = string
}
