output "cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.notes.repository_url
}

output "db_endpoint" {
  value = aws_db_instance.notes.address
}

output "db_secret_arn" {
  value = aws_db_instance.notes.master_user_secret[0].secret_arn
}