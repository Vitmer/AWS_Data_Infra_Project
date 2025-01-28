# 18. AWS KMS Key
resource "random_id" "unique_suffix" {
  byte_length = 4
}

resource "aws_kms_key" "key" {
  description         = "KMS key for managing secrets"
  deletion_window_in_days = 7
  tags = var.tags
}

resource "aws_kms_alias" "key_alias" {
  name          = "alias/kms-central-${substr(random_id.unique_suffix.hex, 0, 10)}"
  target_key_id = aws_kms_key.key.id
}

# 19. IAM Policy for Terraform Access
resource "aws_iam_policy" "terraform_access" {
  name        = "terraform-key-access"
  description = "Policy for Terraform to manage secrets in Secrets Manager"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecrets",
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:PutSecretValue"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ],
        Effect   = "Allow",
        Resource = aws_kms_key.key.arn
      }
    ]
  })

  tags = var.tags
}

# 21. Synapse SQL Password Secret
resource "aws_secretsmanager_secret" "synapse_sql_password" {
  name                     = "synapse-sql-password"
  description              = "Synapse SQL Password Secret"
  kms_key_id               = aws_kms_key.key.id
  recovery_window_in_days  = 7
  tags                     = var.tags
}

resource "aws_secretsmanager_secret_version" "synapse_sql_password_value" {
  secret_id     = aws_secretsmanager_secret.synapse_sql_password.id
  secret_string = var.synapse_sql_password

}

# 22. Example Secret
resource "aws_secretsmanager_secret" "example_secret" {
  name                     = "example-password"
  description              = "Example password secret"
  kms_key_id               = aws_kms_key.key.id
  recovery_window_in_days  = 7
  tags                     = var.tags
}

resource "aws_secretsmanager_secret_version" "example_secret_value" {
  secret_id     = aws_secretsmanager_secret.example_secret.id
  secret_string = var.example_password
}

resource "aws_kms_key" "example" {
  description             = "Example key"
  deletion_window_in_days = 10

  tags = var.tags
}

resource "aws_iam_role" "example_emr" {
  name               = "example-emr-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "elasticmapreduce.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role" "example" {
  name               = "example-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role" "emr_service" {
  name               = "emr-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "elasticmapreduce.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_cloudtrail" "example" {
  name           = "example-cloudtrail"
  s3_bucket_name = "example-cloudtrail-bucket"

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::example-bucket/"]
    }
  }

  is_multi_region_trail = true
  enable_logging        = true

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "example" {
  alarm_name          = "ExampleAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = "i-1234567890abcdef0"
  }

  alarm_actions = [aws_sns_topic.example.arn]
  ok_actions    = [aws_sns_topic.example.arn]
  insufficient_data_actions = [aws_sns_topic.example.arn]

  tags = var.tags
}

resource "aws_sns_topic" "example" {
  name = "example-topic"

  tags = var.tags
}