resource "aws_security_group" "alb" {
  name_prefix = "${local.name}-alb-"
  vpc_id      = aws_vpc.main.id
  tags        = local.tags
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_api" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 5000
  to_port                      = 5000
  ip_protocol                  = "tcp"
}

resource "aws_security_group" "api" {
  name_prefix = "${local.name}-api-"
  vpc_id      = aws_vpc.main.id
  tags        = local.tags
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "api_from_alb" {
  security_group_id            = aws_security_group.api.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 5000
  to_port                      = 5000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "api_out" {
  security_group_id = aws_security_group.api.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "db" {
  name_prefix = "${local.name}-db-"
  vpc_id      = aws_vpc.main.id
  tags        = local.tags
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_api" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
