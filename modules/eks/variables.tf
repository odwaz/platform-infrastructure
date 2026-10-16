variable "name" {
  description = "Cluster name, e.g. wallet-dev"
  type        = string
}

variable "kubernetes_version" {
  description = "EKS version in standard support"
  type        = string
  default     = "1.37"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets for the control plane ENIs and the nodes"
  type        = list(string)
}

variable "endpoint_public_access_cidrs" {
  description = "Only these CIDRs can reach the Kubernetes API from the internet"
  type        = list(string)
}

variable "admin_principal_arn" {
  description = "IAM role or user that gets cluster-admin (you)"
  type        = string
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 4
}

variable "desired_size" {
  type    = number
  default = 2
}
