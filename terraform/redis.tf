resource "aws_elasticache_subnet_group" "idempotency" {
  name       = "${local.name}-redis-subnets"
  subnet_ids = aws_subnet.private[*].id

  tags = local.tags
}

resource "aws_security_group" "redis" {
  name_prefix = "${local.name}-redis-"
  vpc_id      = aws_vpc.main.id

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_api" {
  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = aws_security_group.api.id

  from_port   = 6379
  to_port     = 6379
  ip_protocol = "tcp"
}

resource "aws_elasticache_replication_group" "idempotency" {
  replication_group_id = "${local.name}-idem"
  description          = "Redis idempotency keys for lab2"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = "cache.t4g.micro"

  num_cache_clusters = 1
  port               = 6379

  subnet_group_name  = aws_elasticache_subnet_group.idempotency.name
  security_group_ids = [aws_security_group.redis.id]

  automatic_failover_enabled = false
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  apply_immediately = true

  tags = local.tags
}
