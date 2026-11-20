# Dead-letter queue
resource "aws_sqs_queue" "jobs_dlq" {
  name                      = "${local.name}-jobs-dlq"
  message_retention_seconds = 604800

  tags = local.tags
}

# Основна черга
resource "aws_sqs_queue" "jobs" {
  name                       = "${local.name}-jobs"
  visibility_timeout_seconds = 120
  receive_wait_time_seconds  = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.tags
}

# API може надсилати повідомлення в SQS
resource "aws_iam_role_policy" "api_send_jobs" {
  name = "${local.name}-api-sqs-send"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "sqs:SendMessage"
      ]

      Resource = aws_sqs_queue.jobs.arn
    }]
  })
}

# Окрема IAM роль для Worker
resource "aws_iam_role" "worker" {
  name               = "${local.name}-ecs-worker-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

  tags = local.tags
}

# Worker може отримувати та видаляти повідомлення
resource "aws_iam_role_policy" "worker_read_jobs" {
  name = "${local.name}-worker-sqs-read"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]

      Resource = aws_sqs_queue.jobs.arn
    }]
  })
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${local.name}-worker"
  retention_in_days = 7

  tags = local.tags
}

# ECS Task Definition для Worker
resource "aws_ecs_task_definition" "worker" {
  family                   = "${local.name}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.execution.arn
  task_role_arn      = aws_iam_role.worker.arn

  container_definitions = jsonencode([
    merge(
      jsondecode(
        aws_ecs_task_definition.api.container_definitions
      )[0],
      {
        name         = "worker"
        command      = ["python", "worker.py"]
        portMappings = []

        environment = concat(
          jsondecode(
            aws_ecs_task_definition.api.container_definitions
          )[0].environment,
          [
            {
              name  = "WORKER_DELAY_SECONDS"
              value = "3"
            }
          ]
        )

        logConfiguration = {
          logDriver = "awslogs"

          options = {
            awslogs-group         = aws_cloudwatch_log_group.worker.name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "worker"
          }
        }
      }
    )
  ])

  depends_on = [
    aws_iam_role_policy.worker_read_jobs
  ]

  tags = local.tags
}

# Окремий ECS Service
resource "aws_ecs_service" "worker" {
  name            = "${local.name}-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn

  desired_count = 1
  launch_type   = "FARGATE"

  network_configuration {
    subnets = aws_subnet.private[*].id

    security_groups = [
      aws_security_group.api.id
    ]

    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count
    ]
  }

  depends_on = [
    aws_route.nat,
    aws_route_table_association.private
  ]

  tags = local.tags
}

# Autoscaling Worker: від 1 до 3 tasks
resource "aws_appautoscaling_target" "worker" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"

  resource_id = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.worker.name}"

  min_capacity = 1
  max_capacity = 3
}

# Збільшення кількості Worker
resource "aws_appautoscaling_policy" "worker_up" {
  name = "${local.name}-worker-scale-out"

  service_namespace  = aws_appautoscaling_target.worker.service_namespace
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  resource_id        = aws_appautoscaling_target.worker.resource_id

  policy_type = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

# Зменшення кількості Worker
resource "aws_appautoscaling_policy" "worker_down" {
  name = "${local.name}-worker-scale-in"

  service_namespace  = aws_appautoscaling_target.worker.service_namespace
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  resource_id        = aws_appautoscaling_target.worker.resource_id

  policy_type = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 180
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

# Масштабування вгору: >= 10 повідомлень
resource "aws_cloudwatch_metric_alarm" "queue_high" {
  alarm_name = "${local.name}-queue-high"

  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"

  statistic          = "Average"
  period             = 60
  evaluation_periods = 2

  threshold = 10

  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    QueueName = aws_sqs_queue.jobs.name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_appautoscaling_policy.worker_up.arn
  ]

  tags = local.tags
}

# Масштабування вниз: <= 2 повідомлення
resource "aws_cloudwatch_metric_alarm" "queue_low" {
  alarm_name = "${local.name}-queue-low"

  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"

  statistic          = "Average"
  period             = 60
  evaluation_periods = 3

  threshold = 2

  comparison_operator = "LessThanOrEqualToThreshold"

  dimensions = {
    QueueName = aws_sqs_queue.jobs.name
  }

  treat_missing_data = "breaching"

  alarm_actions = [
    aws_appautoscaling_policy.worker_down.arn
  ]

  tags = local.tags
}
