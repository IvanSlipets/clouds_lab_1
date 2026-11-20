resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "http_5xx" {
  alarm_name          = "${local.name}-http-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.api.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = local.tags
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${local.name}-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.api.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = local.tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      # 1. Desired vs. running ECS tasks.
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          region  = var.aws_region
          title   = "ECS tasks: desired vs running"
          view    = "timeSeries"
          period  = 60
          stacked = false
          metrics = [
            ["ECS/ContainerInsights", "DesiredTaskCount", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.api.name, { stat = "Maximum", label = "Desired tasks" }],
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.api.name, { stat = "Maximum", label = "Running tasks" }],
          ]
        }
      },
      # 2. ECS service CPU: average utilization and target line.
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          region  = var.aws_region
          title   = "ECS CPU utilization (%)"
          view    = "timeSeries"
          period  = 60
          stacked = false
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.api.name, { stat = "Average", label = "CPU (avg %)" }],
          ]
          annotations = {
            horizontal = [
              { label = "Auto Scaling target (60%)", value = 60 }
            ]
          }
        }
      },
      # 3. Requests per minute via Application Load Balancer.
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          region  = var.aws_region
          title   = "HTTP requests per minute"
          view    = "timeSeries"
          period  = 60
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "Requests / minute" }],
          ]
        }
      },
      # 4. 95th percentile of ALB target response time (unit: seconds).
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          region  = var.aws_region
          title   = "API latency p95 (seconds)"
          view    = "timeSeries"
          period  = 60
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, "TargetGroup", aws_lb_target_group.api.arn_suffix, { stat = "p95", label = "Target response p95 (s)" }],
          ]
        }
      },
      # 5. HTTP 5xx server errors.
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          region  = var.aws_region
          title   = "HTTP 5xx errors per minute"
          view    = "timeSeries"
          period  = 60
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix, "TargetGroup", aws_lb_target_group.api.arn_suffix, { stat = "Sum", label = "Application 5xx" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "ALB 5xx" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          region = var.aws_region
          title  = "SQS queue backlog"
          view   = "timeSeries"
          period = 60

          metrics = [
            [
              "AWS/SQS",
              "ApproximateNumberOfMessagesVisible",
              "QueueName",
              aws_sqs_queue.jobs.name,
              {
                stat  = "Average"
                label = "Pending messages"
              }
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6

        properties = {
          region = var.aws_region
          title  = "ECS worker instances"
          view   = "timeSeries"
          period = 60

          metrics = [
            [
              "ECS/ContainerInsights",
              "RunningTaskCount",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.worker.name,
              {
                stat  = "Maximum"
                label = "Running workers"
              }
            ],
            [
              "ECS/ContainerInsights",
              "DesiredTaskCount",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.worker.name,
              {
                stat  = "Maximum"
                label = "Desired workers"
              }
            ]
          ]
        }
      },
    ]
  })
}


resource "aws_budgets_budget" "monthly" {
  count        = var.create_budget ? 1 : 0
  name         = "${local.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}


resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name        = "${local.name}-high-cpu"
  alarm_description = "ECS CPU utilization above 70% for 2 minutes"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 70

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"
  statistic   = "Average"
  period      = 60

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.api.name
  }

  treat_missing_data = "missing"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  ok_actions = [
    aws_sns_topic.alerts.arn
  ]

  tags = local.tags
}
