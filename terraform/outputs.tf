output "api_url" {
  description = "HTTP-only public address for lab verification"
  value       = "http://${aws_lb.main.dns_name}"
}

output "health_url" {
  value = "http://${aws_lb.main.dns_name}/health"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.api.name
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}

output "github_oidc_role_arn" {
  value = aws_iam_role.github.arn
}
