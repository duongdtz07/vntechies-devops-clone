resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.env}.local"
  description = "Private DNS namespace for ${var.env} ECS services"
  vpc         = aws_vpc.main.id

  tags = local.common_tags
}

resource "aws_service_discovery_service" "backend" {
  name = "backend"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {}

  tags = local.common_tags
}
