output "cluster_name" {
  value = module.app.cluster_name
}

output "kubectl_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.app.cluster_name}"
}

output "rds_endpoint" {
  value = module.app.rds_endpoint
}

output "ecr_repository_urls" {
  value = module.app.ecr_repository_urls
}

output "github_ci_role_arn" {
  value = module.app.github_ci_role_arn
}

output "external_pull_user" {
  value = module.app.external_pull_user
}
