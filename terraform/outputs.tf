output "frontend_url" {
  value = "https://${var.env}-app.cloudacad.help"
}

output "backend_url" {
  value = "https://${var.env}-api.cloudacad.help"
}

output "ecr_frontend_repo" {
  value = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_repo" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}
