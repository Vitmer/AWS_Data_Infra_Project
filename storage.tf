
resource "aws_db_instance" "rds_example" {
  engine         = "postgres"
  instance_class = "db.m5.large"
  multi_az       = true
}

# =============================
# S3 STORAGE CONFIGURATION
# =============================

# S3 Bucket - Main storage bucket (analog of Azure Storage Account)
resource "aws_s3_bucket" "storage" {
  bucket = "my-s3-bucket-${random_string.unique.result}"
  tags   = var.tags
}

# Enable Versioning for S3 Bucket
resource "aws_s3_bucket_versioning" "storage_versioning" {
  bucket = aws_s3_bucket.storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket for VPC Flow Logs
resource "aws_s3_bucket" "vpc_logs_bucket" {
  count  = var.enable_vpc_s3_logging ? 1 : 0
  bucket = "vpc-flow-logs-${random_string.random_suffixes["suffix"].result}"
  force_destroy = true 
  tags          = var.tags
}

resource "aws_s3_bucket" "example" {
  bucket = "my-secure-bucket-${random_string.random_suffixes["suffix"].result}"
  force_destroy = true 
  tags = var.tags
}

# Lifecycle Policy - Automatically deletes objects after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "storage_lifecycle" {
  bucket = aws_s3_bucket.storage.id

  rule {
    id     = "lifecycle-rule"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

# Retrieve AWS Account ID
data "aws_caller_identity" "current" {}

# =============================
# DATA LAKE STORAGE
# =============================

# Data Lake Filesystem - Creates a folder inside S3
resource "aws_s3_object" "data_lake_filesystem" {
  bucket = aws_s3_bucket.storage.id
  key    = "datalake-filesystem/" # Creates a folder in S3
  source = null
  tags   = var.tags
}

# Data Container - Creates a folder for structured data
resource "aws_s3_object" "data_container" {
  bucket = aws_s3_bucket.storage.id
  key    = "data-container/" # Creates a container (folder) in S3
  source = null
  tags   = var.tags
}

# Data Blob - Creates an object inside the container
resource "aws_s3_object" "data_blob" {
  bucket  = aws_s3_bucket.storage.id
  key     = "data-container/data-blob"
  content = "Hello, this is a test file!"
  acl     = "private"
  tags    = var.tags
}


# =============================
# SPECIALIZED S3 BUCKETS
# =============================

# CloudTrail Logging Bucket
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = "aws-data-infra-bucket-cloudtrail"
  tags   = var.tags
}

# Glacier Storage Bucket
resource "aws_s3_bucket" "glacier_bucket" {
  bucket = "aws-data-infra-bucket-glacier"
  tags   = var.tags
}

# =============================
# RANDOM STRING FOR UNIQUE NAMING
# =============================

# Generate a unique identifier for resource naming
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

# ========== Example Data (CSV) ==========
resource "null_resource" "create_example_data" {
  provisioner "local-exec" {
    command = <<EOT
      echo "customer_id,purchase_amount" > ${path.module}/data.csv
      echo "1,100.50" >> ${path.module}/data.csv
      echo "2,200.75" >> ${path.module}/data.csv
      echo "3,150.25" >> ${path.module}/data.csv
    EOT
  }
}

# Загрузка файла data.csv в S3
resource "aws_s3_object" "data_file" {
  bucket = aws_s3_bucket.example.bucket
  key    = "data/data.csv"
  source = "${path.module}/data.csv"

  depends_on = [null_resource.create_example_data]
}

# ========== Manifest File ==========
resource "null_resource" "create_manifest_file" {
  provisioner "local-exec" {
    command = <<EOT
      echo '{
        "fileLocations": [
          {
            "URIPrefixes": ["s3://${aws_s3_bucket.example.bucket}/data/"]
          }
        ],
        "globalUploadSettings": {
          "format": "CSV",
          "delimiter": ",",
          "containsHeader": "true"
        }
      }' > ${path.module}/manifest.json
    EOT
  }
}

# Загрузка файла manifest.json в S3
resource "aws_s3_object" "manifest_file" {
  bucket = aws_s3_bucket.example.bucket
  key    = "manifest.json"
  source = "${path.module}/manifest.json"

  depends_on = [null_resource.create_manifest_file]
}

# ========== QuickSight Data Source ==========
resource "aws_quicksight_data_source" "example_data_source" {
  data_source_id = "example-athena-data-source"
  name           = "Example Athena Data Source"
  type           = "ATHENA"

  parameters {
    athena {
      work_group = "primary" 
    }
  }

  permission {
    principal = "arn:aws:iam::${var.aws_account_id}:role/service-role/AWSQuickSightAthenaAccess"
    actions   = ["quicksight:DescribeDataSource"]
  }

  tags = var.tags
}

/* # ========== QuickSight Data Set ==========
#resource "aws_quicksight_data_set" "example_data_set" {
#  data_set_id = "example-dataset-id"
#  name        = "Example Data Set"
#  import_mode = "SPICE"

  physical_table_map {
    id = "example_table"
    s3_source {
      data_source_arn = aws_quicksight_data_source.example_data_source.arn
      input_columns = [
        {
          name = "column1"
          type = "STRING"
        },
        {
          name = "column2"
          type = "INTEGER"
        }
      ]
    }
  }

  logical_table_map {
    id    = "logical_table_1"
    alias = "LogicalTable1"
    source {
      physical_table_id = "example_table"
    }
    data_transforms {
      project_operation {
        projected_columns = ["column1", "column2"]
      }
    }
  }

  tags = var.tags
}*/

# План резервного копирования
resource "aws_backup_plan" "backup_plan" {
  name = "daily-backup-plan"

  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 2 * * ? *)"  # Запуск в 2:00 ночи
  }
}

# Backup Vault - Stores EC2 snapshots
resource "aws_backup_vault" "backup_vault" {
  name = "ec2-backup-vault-${random_string.random_suffixes["suffix"].result}"
}

resource "aws_s3_bucket_logging" "data_lake_logs" {
  bucket = aws_s3_bucket.data_lake.id

  target_bucket = aws_s3_bucket.cloudtrail_bucket.id
  target_prefix = "s3-access-logs/"
}