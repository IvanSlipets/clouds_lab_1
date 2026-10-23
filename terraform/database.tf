resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.private[*].id
  tags       = local.tags
}

resource "aws_db_instance" "mysql" {
  identifier                  = "${local.name}-mysql"
  engine                      = "mysql"
  engine_version              = "8.4"
  instance_class              = var.db_instance_class
  allocated_storage           = 20
  storage_type                = "gp3"
  db_name                     = var.database_name
  username                    = var.db_username
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  publicly_accessible         = false
  storage_encrypted           = true
  backup_retention_period     = 1
  multi_az                    = false
  skip_final_snapshot         = true
  deletion_protection         = false
  apply_immediately           = true
  tags                        = local.tags
}

# Disable automatic RDS master password rotation for the lab
resource "aws_secretsmanager_secret_rotation" "db_master" {
  secret_id = aws_db_instance.mysql.master_user_secret[0].secret_arn

  rotation_enabled = false

  depends_on = [aws_db_instance.mysql]
}
