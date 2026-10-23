resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_ecs_cluster" "main" {
  name = "${local.name}-cluster"
  tags = local.tags
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${aws_ecr_repository.api.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "DB_HOST", value = aws_db_instance.mysql.address },
        { name = "DB_PORT", value = "3306" },
        { name = "DB_NAME", value = var.database_name },
        { name = "DB_USER", value = var.db_username },
        { name = "INIT_DB_SCHEMA", value = "true" },
        { name = "API_ADMIN_USERNAME", value = "admin" },
      ]
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_db_instance.mysql.master_user_secret[0].secret_arn}:password::"
        },
        {
          name      = "FLASK_SECRET_KEY"
          valueFrom = aws_secretsmanager_secret.flask.arn
        },
        {
          name      = "API_ADMIN_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.auth.arn}:admin_password::"
        },
        {
          name      = "JWT_SECRET_KEY"
          valueFrom = "${aws_secretsmanager_secret.auth.arn}:jwt_secret::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "api"
        }
      }
    }
  ])

  depends_on = [
    terraform_data.bootstrap_image,
    aws_iam_role_policy_attachment.execution_basic,
    aws_iam_role_policy.read_db_secret,
    aws_secretsmanager_secret_version.flask,
    aws_secretsmanager_secret_version.auth,
  ]
  tags = local.tags
}

resource "aws_ecs_service" "api" {
  name                              = "${local.name}-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.api.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  health_check_grace_period_seconds = 180

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.api.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 5000
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.http, aws_route.nat, aws_route_table_association.private]
  tags       = local.tags
}