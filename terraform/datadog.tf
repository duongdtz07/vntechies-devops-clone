# Datadog API key — store the actual key value after terraform apply:
#   aws secretsmanager put-secret-value \
#     --secret-id $(terraform output -raw datadog_api_key_secret_arn) \
#     --secret-string "<YOUR_DD_API_KEY>"
resource "aws_secretsmanager_secret" "datadog_api_key" {
  name        = "${var.env}/datadog/api-key"
  description = "Datadog API key for ECS log and metric forwarding"

  tags = merge(local.common_tags, {
    Name = "${var.env}-datadog-api-key"
  })
}

# Placeholder version — replace secret_string value via CLI or console before deploying tasks.
resource "aws_secretsmanager_secret_version" "datadog_api_key" {
  secret_id     = aws_secretsmanager_secret.datadog_api_key.id
  secret_string = var.datadog_api_key
}

# CloudWatch log group for FireLens (Fluent Bit) sidecar own logs
resource "aws_cloudwatch_log_group" "log_router" {
  name              = "/ecs/${var.env}/log-router"
  retention_in_days = 7

  tags = local.common_tags
}

# CloudWatch log group for Datadog Agent sidecar own logs
resource "aws_cloudwatch_log_group" "datadog_agent" {
  name              = "/ecs/${var.env}/datadog-agent"
  retention_in_days = 7

  tags = local.common_tags
}
