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

// launch template: là chỉ cấu hình lưu trên aws, không tự sinh ra máy ảo ec2 
resource "aws_launch_template" "app" {
  name_prefix   = "${var.env}-app-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    security_groups = [aws_security_group.ec2.id]
  }

  user_data = base64encode(<<-EOF
        #!/bin/bash
        yum update -y
        yum install -y nginx
        systemctl enable nginx
        systemctl start nginx
        # Lấy Token IMDSv2
        TOKEN=$(curl -s -X PUT "http://[IP_ADDRESS]/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
        INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://[IP_ADDRESS]/latest/meta-data/instance-id)
        AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://[IP_ADDRESS]/latest/meta-data/placement/availability-zone)
        cat > /usr/share/nginx/html/index.html <<HTML
        <!DOCTYPE html>
        <html>
        <head><title>${var.env} - VNTechies Demo</title></head>
        <body style="font-family: Arial; padding: 20px;">
            <h1 style="color: #0066cc;">VNTechies DevOps - Session 01</h1>
            <p>Environment: <b>${var.env}</b></p>
            <p>Serving from Instance: <b style="color: red;">$INSTANCE_ID</b></p>
            <p>Availability Zone: <b style="color: green;">$AZ</b></p>
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
  min_size                  = var.min_size                                                     // số lượng máy ảo tối thiểu (khi ít traffic => scale in), ASG sẽ không giảm xuống dưới mức này
  max_size                  = var.max_size                                                     // số lượng máy ảo tối đa (khi nhiều traffic => scale out), ASG sẽ không tăng vượt quá mức này
  desired_capacity          = var.desired_capacity                                             // số lượng máy ảo mong muốn chạy thực tế (mặc định)
  vpc_zone_identifier       = [aws_subnet.private-subnet-A.id, aws_subnet.private-subnet-B.id] // vùng miền cần triển khai
  target_group_arns         = [aws_lb_target_group.app.arn]                                    // load balancer target group
  health_check_type         = "ELB"                                                            // ELB: kiểm tra sức khỏe qua Load Balancer, EC2: kiểm tra sức khỏe qua EC2
  health_check_grace_period = 300                                                              // thời gian chờ sau khi khởi tạo máy ảo trước khi kiểm tra sức khỏe

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling" // cập nhật cuốn chiếu: khi bạn deploy code mới hoặc đổi AMI, ASG sẽ lần lượt tắt từng máy cũ và bật máy mới lên
    preferences {
      min_healthy_percentage = 50  // đảm bảo ít nhất 50% máy ảo luôn hoạt động
      instance_warmup        = 300 // thời gian chờ sau khi khởi tạo máy ảo trước khi kiểm tra sức khỏe
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.env}-app"
    propagate_at_launch = true // khi máy ảo được tạo ra, tag này sẽ được áp dụng cho máy ảo và ổ đĩa EBS
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  depends_on = [aws_lb_listener.http] // đảm bảo ASG được tạo sau khi Load Balancer Listener được tạo
}

//  Auto Scaling Policy: chính sách tự động tăng giảm số lượng máy ảo
//  - scale_out: tăng số lượng máy ảo khi CPU > 70%
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.env}-app-scale-out"     // tên chính sách
  autoscaling_group_name = aws_autoscaling_group.app.name // tên ASG
  adjustment_type        = "ChangeInCapacity"             // ChangeInCapacity: tăng giảm số lượng máy ảo, PercentChangeInCapacity: tăng giảm theo phần trăm
  scaling_adjustment     = 1                              // tăng 1 máy ảo
  cooldown               = 300                            // thời gian chờ sau khi scale out trước khi scale out tiếp
}

// Auto Scaling Policy: chính sách tự động tăng giảm số lượng máy ảo
//  - scale_in: giảm số lượng máy ảo khi CPU < 20%
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.env}-app-scale-in"      // tên chính sách
  autoscaling_group_name = aws_autoscaling_group.app.name // tên ASG
  adjustment_type        = "ChangeInCapacity"             // ChangeInCapacity: tăng giảm số lượng máy ảo, PercentChangeInCapacity: tăng giảm theo phần trăm
  scaling_adjustment     = -1                             // giảm 1 máy ảo
  cooldown               = 300                            // thời gian chờ sau khi scale in trước khi scale in tiếp
}

// CloudWatch Alarm: báo động khi CPU > 40%
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.env}-app-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out when CPU > 40% for 4 minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = local.common_tags
}

// CloudWatch Alarm: báo động khi CPU < 20%
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
