resource "random_password" "flask" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "flask" {
  name_prefix             = "${local.name}-flask-"
  recovery_window_in_days = 0
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "flask" {
  secret_id     = aws_secretsmanager_secret.flask.id
  secret_string = random_password.flask.result
}

# JWT signing key
resource "random_password" "jwt_signing" {
  length  = 64
  special = false
}

# API administrator password
resource "random_password" "api_admin" {
  length  = 32
  special = false
}

# Secret for API authentication
resource "aws_secretsmanager_secret" "auth" {
  name_prefix             = "${local.name}-auth-"
  recovery_window_in_days = 0

  tags = local.tags
}

# JWT key and administrator password
resource "aws_secretsmanager_secret_version" "auth" {
  secret_id = aws_secretsmanager_secret.auth.id

  secret_string = jsonencode({
    jwt_secret     = random_password.jwt_signing.result
    admin_password = random_password.api_admin.result
  })
}