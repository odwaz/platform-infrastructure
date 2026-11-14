output "cluster_name" {
  value = module.eks.cluster_name
}

output "rds_endpoint" {
  description = "address:port, or null without a database"
  value       = one(module.rds[*].endpoint)
}

output "ecr_repository_urls" {
  value = { for image, repository in module.ecr : image => repository.repository_url }
}

output "github_ci_role_arn" {
  description = "The role the app's CI assumes to push images, or null without images"
  value       = one(module.github_ci_role[*].role_arn)
}

output "external_pull_user" {
  description = "IAM user for a cluster outside AWS to pull images with, or null"
  value       = one(aws_iam_user.external_pull[*].name)
}
