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

  user_data = filebase64("${path.module}/user-data.sh")

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

//  Auto Scaling Policy & CloudWatch Alarm (đã tắt scale tự động)
# resource "aws_autoscaling_policy" "scale_out" {
#   name                   = "${var.env}-app-scale-out"
#   autoscaling_group_name = aws_autoscaling_group.app.name
#   adjustment_type        = "ChangeInCapacity"
#   scaling_adjustment     = 1
#   cooldown               = 300
# }

# resource "aws_autoscaling_policy" "scale_in" {
#   name                   = "${var.env}-app-scale-in"
#   autoscaling_group_name = aws_autoscaling_group.app.name
#   adjustment_type        = "ChangeInCapacity"
#   scaling_adjustment     = -1
#   cooldown               = 300
# }

# resource "aws_cloudwatch_metric_alarm" "high_cpu" {
#   alarm_name          = "${var.env}-app-high-cpu"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = 120
#   statistic           = "Average"
#   threshold           = 70
#   alarm_description   = "Scale out when CPU > 70% for 4 minutes"
#   alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.app.name
#   }

#   tags = local.common_tags
# }

# resource "aws_cloudwatch_metric_alarm" "low_cpu" {
#   alarm_name          = "${var.env}-app-low-cpu"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = 120
#   statistic           = "Average"
#   threshold           = 20
#   alarm_description   = "Scale in when CPU < 20% for 4 minutes"
#   alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.app.name
#   }

#   tags = local.common_tags
# }
