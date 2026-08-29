resource "aws_security_group" "alb" {
  name        = "${var.env}-alb-sg"
  description = "Allow HTTP and HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.env}-alb-sg"
  })
}

resource "aws_security_group" "ec2" {
  name        = "${var.env}-app-ec2-sg"
  description = "Allow HTTP/HTTPS traffic to EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.env}-app-ec2-sg"
  })
}

resource "aws_lb" "app" {
  name               = "${var.env}-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public-subnet-A.id, aws_subnet.public-subnet-B.id]

  tags = merge(local.common_tags, {
    Name = "${var.env}-app-lb"
  })
}

resource "aws_lb_target_group" "app" {
  name     = "${var.env}-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "${var.env}-app-target-group"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.app.arn
#   port                = 443
#   protocol            = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = data.aws_acm_certificate.wildcard.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app.arn
#   }
# }
