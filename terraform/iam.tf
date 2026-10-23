data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "read_db_secret" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]

    resources = [
      aws_db_instance.mysql.master_user_secret[0].secret_arn,
      aws_secretsmanager_secret.flask.arn,
      aws_secretsmanager_secret.auth.arn,
    ]
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "execution_basic" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "read_db_secret" {
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.read_db_secret.json
}

resource "aws_iam_role" "task" {
  name               = "${local.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = local.tags
}
