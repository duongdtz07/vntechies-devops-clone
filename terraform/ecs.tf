data "aws_region" "current" {}

resource "aws_ecs_cluster" "main" {
  name = "${var.env}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = merge(local.common_tags, {
    Name = "${var.env}-cluster"
  })
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.env}/frontend"
  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.env}/backend"
  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.env}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.backend_cpu
  memory                   = var.backend_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    # FireLens log router — must start before app containers
    {
      name      = "log_router"
      image     = "amazon/aws-for-fluent-bit:stable"
      essential = true
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          "enable-ecs-log-metadata" = "true"
        }
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.log_router.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "backend"
        }
      }
      memoryReservation = 64
    },
    # Datadog Agent — metrics, APM traces, health checks
    {
      name      = "datadog-agent"
      image     = "public.ecr.aws/datadog/agent:latest"
      essential = false
      environment = [
        { name = "DD_SITE", value = var.datadog_site },
        { name = "ECS_FARGATE", value = "true" },
        { name = "DD_APM_ENABLED", value = "true" },
        { name = "DD_APM_NON_LOCAL_TRAFFIC", value = "true" },
        { name = "DD_PROCESS_AGENT_ENABLED", value = "true" },
        { name = "DD_LOGS_ENABLED", value = "false" },
        { name = "DD_ENV", value = var.env },
        { name = "DD_SERVICE", value = "backend" }
      ]
      secrets = [
        { name = "DD_API_KEY", valueFrom = aws_secretsmanager_secret.datadog_api_key.arn }
      ]
      portMappings = [
        { containerPort = 8126, protocol = "tcp" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.datadog_agent.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "backend"
        }
      }
      memoryReservation = 256
    },
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:${var.backend_image_tag}"
      essential = true
      portMappings = [
        { containerPort = 3001, protocol = "tcp" }
      ]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "3001" }
      ]
      dependsOn = [
        { containerName = "log_router", condition = "START" }
      ]
      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          "Name"       = "datadog"
          "Host"       = local.dd_log_intake_host
          "TLS"        = "on"
          "dd_service" = "backend"
          "dd_source"  = "nodejs"
          "dd_tags"    = "env:${var.env}"
          "provider"   = "ecs"
          "compress"   = "gzip"
        }
        secretOptions = [
          { name = "apikey", valueFrom = aws_secretsmanager_secret.datadog_api_key.arn }
        ]
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${var.env}-backend"
  })
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.env}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.frontend_cpu
  memory                   = var.frontend_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    # FireLens log router — must start before app containers
    {
      name      = "log_router"
      image     = "amazon/aws-for-fluent-bit:stable"
      essential = true
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          "enable-ecs-log-metadata" = "true"
        }
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.log_router.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "frontend"
        }
      }
      memoryReservation = 64
    },
    # Datadog Agent — metrics, APM traces, health checks
    {
      name      = "datadog-agent"
      image     = "public.ecr.aws/datadog/agent:latest"
      essential = false
      environment = [
        { name = "DD_SITE", value = var.datadog_site },
        { name = "ECS_FARGATE", value = "true" },
        { name = "DD_APM_ENABLED", value = "true" },
        { name = "DD_APM_NON_LOCAL_TRAFFIC", value = "true" },
        { name = "DD_PROCESS_AGENT_ENABLED", value = "true" },
        { name = "DD_LOGS_ENABLED", value = "false" },
        { name = "DD_ENV", value = var.env },
        { name = "DD_SERVICE", value = "frontend" }
      ]
      secrets = [
        { name = "DD_API_KEY", valueFrom = aws_secretsmanager_secret.datadog_api_key.arn }
      ]
      portMappings = [
        { containerPort = 8126, protocol = "tcp" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.datadog_agent.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "frontend"
        }
      }
      memoryReservation = 256
    },
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.frontend.repository_url}:${var.frontend_image_tag}"
      essential = true
      portMappings = [
        { containerPort = 3000, protocol = "tcp" }
      ]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "3000" },
        { name = "API_URL", value = "http://backend.${var.env}.local:3001" }
      ]
      dependsOn = [
        { containerName = "log_router", condition = "START" }
      ]
      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          "Name"       = "datadog"
          "Host"       = local.dd_log_intake_host
          "TLS"        = "on"
          "dd_service" = "frontend"
          "dd_source"  = "nodejs"
          "dd_tags"    = "env:${var.env}"
          "provider"   = "ecs"
          "compress"   = "gzip"
        }
        secretOptions = [
          { name = "apikey", valueFrom = aws_secretsmanager_secret.datadog_api_key.arn }
        ]
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${var.env}-frontend"
  })
}

# Backend: private, registered with Cloud Map — no ALB attachment
resource "aws_ecs_service" "backend" {
  name            = "${var.env}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private-subnet-A.id, aws_subnet.private-subnet-B.id]
    security_groups = [aws_security_group.ecs_backend.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.backend.arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = local.common_tags
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.env}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private-subnet-A.id, aws_subnet.private-subnet-B.id]
    security_groups = [aws_security_group.ecs_frontend.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 3000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.https]

  tags = local.common_tags
}
