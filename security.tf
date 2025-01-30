# 18. AWS KMS Key
resource "random_id" "unique_suffix" {
  byte_length = 4
}

resource "aws_kms_key" "key" {
  description             = "KMS key for managing secrets"
  deletion_window_in_days = 7
  tags                    = var.tags
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

# Генерируем случайные суффиксы для имен секретов
resource "random_string" "synapse_secret_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "example_secret_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Создаём новый секрет с уникальным именем
resource "aws_secretsmanager_secret" "synapse_sql_password" {
  name = "synapse-sql-password-${random_string.synapse_secret_suffix.result}"

  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}

resource "aws_secretsmanager_secret" "example_password" {
  name = "example-password-${random_string.example_secret_suffix.result}"

  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}

# Установка значений секретов
resource "aws_secretsmanager_secret_version" "synapse_sql_password_value" {
  secret_id     = aws_secretsmanager_secret.synapse_sql_password.id
  secret_string = var.synapse_sql_password
}

resource "aws_secretsmanager_secret_version" "example_password_value" {
  secret_id     = aws_secretsmanager_secret.example_password.id
  secret_string = var.example_password
}


resource "aws_iam_role" "example_emr" {
  name = "example-emr-role"
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
  name = "example-role"
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
  name = "emr-service-role"
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
  name           = "example-cloudtrail-unique"
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

  alarm_actions             = [aws_sns_topic.example.arn]
  ok_actions                = [aws_sns_topic.example.arn]
  insufficient_data_actions = [aws_sns_topic.example.arn]

  tags = var.tags
}

resource "aws_sns_topic" "example" {
  name = "example-topic"

  tags = var.tags
}

resource "aws_iam_policy" "s3_policy" {
  name        = "s3-access-policy"
  description = "Allows updating bucket policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "s3:PutBucketPolicy",
      Resource = "arn:aws:s3:::my-s3-bucket"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role" "s3_access_role" {
  name = "S3AccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "s3.amazonaws.com" }, # ✅ Доступ для S3
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy_attachment" "s3_full_access" {
  name       = "s3-full-access"
  roles      = [aws_iam_role.s3_access_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role" "emr_role" {
  name = "EMR_DefaultRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "elasticmapreduce.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "emr_instance_profile" {
  name = "EMR_EC2_DefaultRole"
  role = aws_iam_role.emr_role.name
}