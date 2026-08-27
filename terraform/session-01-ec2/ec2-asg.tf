data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.env}-app-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl enable nginx
    systemctl start nginx

    cat > /usr/share/nginx/html/index.html <<HTML
    <!DOCTYPE html>
    <html>
      <head><title>${var.env} - VNTechies Demo</title></head>
      <body>
        <h1>VNTechies DevOps - Session 01: EC2 + ALB + ASG</h1>
        <p>Environment: ${var.env}</p>
        <p>Release: ${var.release_version}</p>
        <p>Instance: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
        <p>AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
      </body>
    </html>
    HTML
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.env}-app"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${var.env}-app-volume"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.env}-app-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = [aws_subnet.private-subnet-A.id, aws_subnet.private-subnet-B.id]
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.env}-app"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  depends_on = [aws_lb_listener.https]
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.env}-app-scale-out"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.env}-app-scale-in"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.env}-app-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out when CPU > 70% for 4 minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.env}-app-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "Scale in when CPU < 20% for 4 minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = local.common_tags
}
