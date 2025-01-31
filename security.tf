# Random ID Generator - Generates a unique suffix for resource naming
resource "random_id" "unique_suffix" {
  byte_length = 4
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}


# Security Group for Public Access - Allows SSH access
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # SSH access only from your IP
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

# Security Group for Redshift - Restricts access to VPC only
resource "aws_security_group" "redshift_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "redshift-sg"
  description = "Security group for Redshift"
  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Allow access only inside VPC
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

# Network ACL - Restricts and controls VPC traffic
resource "aws_network_acl" "example" {
  vpc_id = aws_vpc.main.id
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 22
    to_port    = 22
  }
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags = var.tags
}

# Restrict Public Access to S3 Bucket
resource "aws_s3_bucket_public_access_block" "storage_public_access" {
  bucket                  = aws_s3_bucket.storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy - Grants access to a specific IAM Role
resource "aws_s3_bucket_policy" "storage_policy" {
  bucket = aws_s3_bucket.storage.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/S3AccessRole"
        }
        Resource = "${aws_s3_bucket.storage.arn}/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = "203.0.113.0/24" # Allowed IP range
          }
        }
      }
    ]
  })
}

# Server-Side Encryption (SSE) - Encrypts objects with AWS KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "storage_encryption" {
  bucket = aws_s3_bucket.storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.key.arn
    }
  }
}


# IAM Role for AWS Backup Service
resource "aws_iam_role" "backup_role" {
  name = "BackupRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  lifecycle {
    prevent_destroy = false # Allows Terraform to destroy this role if needed
  }

  tags = var.tags
}

# Attaches AWS Backup service policy to IAM Role
resource "aws_iam_role_policy_attachment" "backup_vault_access" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# AWS KMS Key - Manages encryption keys for securing sensitive data
resource "aws_kms_key" "key" {
  description             = "KMS key for managing secrets"
  deletion_window_in_days = 7
  tags                    = var.tags
}

# AWS KMS Alias - Creates a friendly alias for the KMS key
resource "aws_kms_alias" "key_alias" {
  name          = "alias/kms-central-${substr(random_id.unique_suffix.hex, 0, 10)}"
  target_key_id = aws_kms_key.key.id
}

# IAM Policy for Terraform Access - Grants Terraform permissions to manage secrets
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

# Random String Generator - Generates unique suffixes for secret names
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

# AWS Secrets Manager - Creates a secret for Synapse SQL password
resource "aws_secretsmanager_secret" "synapse_sql_password" {
  name = "synapse-sql-password-${random_string.synapse_secret_suffix.result}"

  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}

# AWS Secrets Manager - Creates a secret for an example password
resource "aws_secretsmanager_secret" "example_password" {
  name = "example-password-${random_string.example_secret_suffix.result}"

  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}

# AWS Secrets Manager - Stores values for secrets
resource "aws_secretsmanager_secret_version" "synapse_sql_password_value" {
  secret_id     = aws_secretsmanager_secret.synapse_sql_password.id
  secret_string = var.synapse_sql_password
}

resource "aws_secretsmanager_secret_version" "example_password_value" {
  secret_id     = aws_secretsmanager_secret.example_password.id
  secret_string = var.example_password
}

# IAM Role for EMR - Grants permissions for Amazon EMR service
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

# IAM Role for Lambda - Grants execution permissions for AWS Lambda
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

# IAM Role for EMR Service - Grants permissions for Amazon EMR service
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

# AWS CloudTrail - Enables logging of AWS API calls for security monitoring
resource "aws_cloudtrail" "example" {
  name           = "example-cloudtrail-unique"
  s3_bucket_name = "example-cloudtrail-bucket"

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  is_multi_region_trail = true
  enable_logging        = true
}

# IAM Policy for S3 - Grants permission to update S3 bucket policy
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

# IAM Role for S3 Access - Grants S3 permissions
resource "aws_iam_role" "s3_access_role" {
  name = "S3AccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "s3.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# IAM Policy Attachment - Grants full access to S3
resource "aws_iam_policy_attachment" "s3_full_access" {
  name       = "s3-full-access"
  roles      = [aws_iam_role.s3_access_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# IAM Role for EMR - Grants default EMR role permissions
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

# IAM Instance Profile for EMR - Associates role with EC2 instances in EMR
resource "aws_iam_instance_profile" "emr_instance_profile" {
  name = "EMR_EC2_DefaultRole"
  role = aws_iam_role.emr_role.name
}

# IAM Role for QuickSight - Grants QuickSight permissions
resource "aws_iam_role" "quicksight_service_role" {
  name = "QuickSightServiceRole-${random_string.suffix.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "quicksight.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# IAM Policy for QuickSight S3 Access - Allows QuickSight to access S3 data sources
resource "aws_iam_policy" "quicksight_s3_access" {
  name        = "quicksight-s3-access"
  description = "Allows QuickSight to access S3 data sources"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    }]
  })
}

# S3 Bucket Policy - Defines access control for the bootstrap bucket
resource "aws_s3_bucket_policy" "bootstrap_access" {
  bucket = aws_s3_bucket.bootstrap.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = "*",
      Action = ["s3:GetObject"],
      Resource = "${aws_s3_bucket.bootstrap.arn}/*"
    }]
  })
}

# IAM Role Policy Attachment for Redshift - Grants full access to Redshift commands
resource "aws_iam_role_policy_attachment" "redshift_full_access" {
  role       = aws_iam_role.redshift_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftAllCommandsFullAccess"
}

# IAM Role Policy Attachment for Redshift S3 - Grants Redshift full access to S3
resource "aws_iam_role_policy_attachment" "redshift_s3_full_access" {
  role       = aws_iam_role.redshift_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# IAM Role for Redshift - Required for permissions to access AWS services
resource "aws_iam_role" "redshift_role" {
  name = "redshift-role-${random_string.suffix_analytics.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "redshift.amazonaws.com"
      }
    }]
  })
  tags = var.tags
}

# IAM Role Policy Attachment for Lambda Execution - Grants basic execution permissions to Lambda
resource "aws_iam_role_policy_attachment" "kinesis_exec_lambda" {
  role       = aws_iam_role.kinesis_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Role Policy Attachment for Kinesis - Grants full access to Kinesis services
resource "aws_iam_role_policy_attachment" "kinesis_exec_full_access" {
  role       = aws_iam_role.kinesis_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
}

# IAM Role for Kinesis - Grants permissions for Kinesis execution
resource "aws_iam_role" "kinesis_exec" {
  name = "kinesis-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "kinesisanalytics.amazonaws.com"
      }
    }]
  })
  tags = var.tags
}

# IAM Role for AWS Glue - Grants permissions for Glue ETL jobs
resource "aws_iam_role" "glue_service_role" {
  name = "glue-service-role-${random_string.suffix_processing.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "glue.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_policy" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# IAM Role for EMR - Grants permissions to EMR service
resource "aws_iam_role" "emr_service_role" {
  name = "emr-service-role-${random_string.suffix_processing.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "elasticmapreduce.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

# IAM Instance Profile for EMR EC2 Instances
resource "aws_iam_instance_profile" "emr_ec2_instance_profile" {
  name = "emr-ec2-instance-profile-${random_string.suffix_processing.result}"
  role = aws_iam_role.emr_ec2_instance_role.name
  tags = var.tags
}

# IAM Role for Lambda Execution - Grants permissions to AWS Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

# IAM Role for Athena - Grants access to run queries
resource "aws_iam_role" "athena_role" {
  name = "athena-role-${random_string.suffix_analytics.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "athena.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "athena_s3_access" {
  role       = aws_iam_role.athena_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}

resource "aws_iam_role" "emr_ec2_instance_role" {
  name = "emr-ec2-role-${random_string.suffix.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}