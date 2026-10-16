output "cluster_name" {
  value = module.eks.cluster_name
}

output "kubectl_command" {
  value = "aws eks update-kubeconfig --region us-east-1 --name ${module.eks.cluster_name}"
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "github_ci_role_arn" {
  value = module.github_ci_role.role_arn
}
