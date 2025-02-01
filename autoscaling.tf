# Launch Template - Defines configuration for EC2 instances in the Auto Scaling Group
resource "aws_launch_template" "example" {
  name          = "example-launch-template"
  image_id      = var.ami_id # Specifies the Amazon Machine Image (AMI) ID for the instance
  instance_type = "t2.micro" # Defines the instance type

  vpc_security_group_ids = [aws_security_group.sg["public_sg"].id] # Associates the instance with a security group

  tag_specifications {
    resource_type = "instance"
    tags          = var.tags # Applies defined tags to instances created from this template
  }
}

# Auto Scaling Group - Manages the EC2 instances and dynamically adjusts capacity
resource "aws_autoscaling_group" "example" {
  vpc_zone_identifier = [aws_subnet.public.id] # Specifies the subnets where instances will be launched
  max_size            = 5  # Maximum number of instances in the group
  min_size            = 1  # Minimum number of instances in the group

  launch_template {
    id      = aws_launch_template.example.id # Uses the launch template for instance configuration
    version = aws_launch_template.example.latest_version
  }

  # Applies tags to all instances within the Auto Scaling Group
  dynamic "tag" {
    for_each = { for k, v in var.tags : k => v }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Auto Scaling Policy (Scale Out) - Increases instance count when triggered
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale_out"
  scaling_adjustment     = 1  # Adds one instance when triggered
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300 # Time to wait before another scaling action
  autoscaling_group_name = aws_autoscaling_group.example.name
}

# Auto Scaling Policy (Scale In) - Decreases instance count when triggered
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale_in"
  scaling_adjustment     = -1  # Removes one instance when triggered
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300 # Time to wait before another scaling action
  autoscaling_group_name = aws_autoscaling_group.example.name
}

# CloudWatch Alarm (High CPU Usage) - Triggers scale-out action if CPU usage exceeds 70%
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "HighCPUUsage"
  comparison_operator = "GreaterThanThreshold" # Alarm triggers when CPU exceeds threshold
  evaluation_periods  = 2  # Number of periods before triggering
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 # Check CPU every 5 minutes
  statistic           = "Average"
  threshold           = 70 # CPU usage threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn] # Triggers scale-out policy
}

# CloudWatch Alarm (Low CPU Usage) - Triggers scale-in action if CPU usage drops below 30%
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "LowCPUUsage"
  comparison_operator = "LessThanThreshold" # Alarm triggers when CPU drops below threshold
  evaluation_periods  = 2  # Number of periods before triggering
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 # Check CPU every 5 minutes
  statistic           = "Average"
  threshold           = 30 # CPU usage threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn] # Triggers scale-in policy
}