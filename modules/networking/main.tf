data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.name
  cidr = var.cidr
  azs  = local.azs

  # /24 subnets: private x.x.1-3.0, public x.x.101-103.0, database x.x.201-203.0
  private_subnets  = [for i in range(var.az_count) : cidrsubnet(var.cidr, 8, i + 1)]
  public_subnets   = [for i in range(var.az_count) : cidrsubnet(var.cidr, 8, i + 101)]
  database_subnets = [for i in range(var.az_count) : cidrsubnet(var.cidr, 8, i + 201)]

  create_database_subnet_group = true

  # One NAT gateway, not one per AZ: cheaper; outbound traffic depends on one AZ.
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
