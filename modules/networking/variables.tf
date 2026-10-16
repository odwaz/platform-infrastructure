variable "name" {
  description = "Prefix for every resource, e.g. wallet-dev"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR, unique per project, e.g. 10.10.0.0/16"
  type        = string

  # main.tf carves /24 subnets with cidrsubnet(var.cidr, 8, n) for n up to 203, which only
  # works out for a /16. Reject anything else at plan time, before AWS sees it.
  validation {
    # TODO(human): replace `true` with the rule a project CIDR must satisfy.
        condition     = can(cidrhost(var.cidr, 0)) && endswith(var.cidr, "/16") && startswith(var.cidr, "10.")
    error_message = "cidr must be a /16 inside 10.0.0.0/8, e.g. 10.10.0.0/16."
  }
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 3
}
