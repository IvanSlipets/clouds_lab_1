resource "aws_appautoscaling_scheduled_action" "day" {
  name               = "${local.name}-day"
  service_namespace  = aws_appautoscaling_target.api.service_namespace
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  resource_id        = aws_appautoscaling_target.api.resource_id

  schedule = "cron(0 8 * * ? *)"
  timezone = "Europe/Kyiv"

  scalable_target_action {
    min_capacity = 2
    max_capacity = 3
  }
}

resource "aws_appautoscaling_scheduled_action" "night" {
  name               = "${local.name}-night"
  service_namespace  = aws_appautoscaling_target.api.service_namespace
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  resource_id        = aws_appautoscaling_target.api.resource_id

  schedule = "cron(0 22 * * ? *)"
  timezone = "Europe/Kyiv"

  scalable_target_action {
    min_capacity = 1
    max_capacity = 3
  }
}
