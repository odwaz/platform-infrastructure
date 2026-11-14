output "cluster_name" {
  value = module.eks.cluster_name
}

output "kubectl_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "ecr_repository_urls" {
  value = { for image, repository in module.ecr : image => repository.repository_url }
}

output "github_ci_role_arn" {
  value = module.github_ci_role.role_arn
}

output "kind_pull_user" {
  description = "IAM user whose access key lets the kind cluster pull from ECR"
  value       = aws_iam_user.kind_pull.name
}
