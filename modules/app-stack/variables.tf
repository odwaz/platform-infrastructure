variable "name" {
  description = "Prefix for every resource of this app and environment, e.g. shop-dev"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR, unique per project: a /16 inside 10.0.0.0/8, e.g. 10.10.0.0/16"
  type        = string
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API, e.g. [\"66.251.128.3/32\"]"
  type        = list(string)
}

variable "admin_principal_arn" {
  description = "IAM role or user given cluster-admin"
  type        = string
}

variable "instance_types" {
  description = "Node instance types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_count" {
  description = "Nodes to run; the node group may grow to twice this"
  type        = number
  default     = 2
}

variable "github_repo" {
  description = "owner/repo whose builds on branch push the images, e.g. owner/shop"
  type        = string
}

variable "branch" {
  description = "Only builds on this branch may push images"
  type        = string
  default     = "main"
}

variable "github_subject_prefix" {
  description = "The OIDC subject prefix github_repo's builds send, when it uses GitHub's immutable subject; null for repo:<github_repo>"
  type        = string
  default     = null
}

variable "images" {
  description = "One ECR repository per image the app builds, named <name>/<image>. Empty for no registry"
  type        = list(string)
  default     = []
}

variable "database" {
  description = "PostgreSQL for the app, reachable only from the cluster nodes, or null for none"
  type = object({
    db_name        = string
    username       = string
    engine_version = optional(string, "17")
    instance_class = optional(string, "db.t3.micro")
  })
  default = null
}

variable "db_password" {
  description = "Master password for database (sensitive). Required when database is set"
  type        = string
  sensitive   = true
  default     = null
}

variable "external_pull_user" {
  description = "Create an IAM user that may only pull this app's images, for a cluster outside AWS such as a local one. Its access key is created by hand, so it never appears in Terraform state"
  type        = bool
  default     = false
}
