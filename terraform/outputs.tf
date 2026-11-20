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

output "worker_service_name" {
  value = aws_ecs_service.worker.name
}

output "sqs_queue_url" {
  value = aws_sqs_queue.jobs.url
}

output "api_task_definition_arn" {
  value = aws_ecs_task_definition.api.arn
}

output "worker_task_definition_arn" {
  value = aws_ecs_task_definition.worker.arn
}