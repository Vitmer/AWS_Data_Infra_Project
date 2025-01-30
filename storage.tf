# 14. S3 Bucket (аналог Azure Storage Account)
resource "aws_s3_bucket" "storage" {
  bucket = "my-s3-bucket-${random_string.unique.result}"
  tags   = var.tags
}

# Включение версионирования S3 Bucket
resource "aws_s3_bucket_versioning" "storage_versioning" {
  bucket = aws_s3_bucket.storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Шифрование на стороне сервера (SSE)
resource "aws_s3_bucket_server_side_encryption_configuration" "storage_encryption" {
  bucket = aws_s3_bucket.storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Политика жизненного цикла для S3 Bucket
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

# Получение текущего AWS Account ID
data "aws_caller_identity" "current" {}

# Политика для S3 Bucket (исправленный Principal)
resource "aws_s3_bucket_policy" "storage_policy" {
  bucket = aws_s3_bucket.storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/S3AccessRole" # Исправленный ARN
        }
        Resource = "${aws_s3_bucket.storage.arn}/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = "203.0.113.0/24" # Разрешённый IP-диапазон
          }
        }
      }
    ]
  })
}

# 15. Data Lake Gen2 Filesystem → Создание папки в S3
resource "aws_s3_object" "data_lake_filesystem" {
  bucket = aws_s3_bucket.storage.id
  key    = "datalake-filesystem/" # Создаёт папку в S3
  source = null                   # Папка создаётся автоматически

  tags = var.tags
}

# 16. Storage Container → Создание контейнера (папки) в S3
resource "aws_s3_object" "data_container" {
  bucket = aws_s3_bucket.storage.id
  key    = "data-container/" # Создаёт контейнер (папку) в S3
  source = null

  tags = var.tags
}

# 17. Blob Storage → Создание объекта в S3
resource "aws_s3_object" "data_blob" {
  bucket  = aws_s3_bucket.storage.id
  key     = "data-container/data-blob"    # Размещение в папке data-container
  content = "Hello, this is a test file!" # Содержимое объекта
  acl     = "private"

  tags = var.tags
}

# S3 Bucket для CloudTrail
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = "aws-data-infra-bucket-cloudtrail"

  tags = var.tags
}

# S3 Bucket для Glacier
resource "aws_s3_bucket" "glacier_bucket" {
  bucket = "aws-data-infra-bucket-glacier"

  tags = var.tags
}

# Amazon Redshift Cluster
resource "aws_redshift_cluster" "example" {
  cluster_identifier        = "example-cluster"
  node_type                 = "dc2.large"
  master_username           = var.redshift_master_username # ✅ Используем переменную
  master_password           = var.redshift_master_password # ✅ Используем переменную
  cluster_type              = "single-node"
  cluster_subnet_group_name = aws_redshift_subnet_group.redshift_subnet_group.name # ✅ Группа сабнетов

  vpc_security_group_ids = [aws_security_group.redshift_sg.id] # ✅ Группа безопасности
  publicly_accessible    = false                               # ✅ Приватный кластер

  skip_final_snapshot = true
}

# Генерация уникального идентификатора
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

# Публичный доступ к S3 Bucket
resource "aws_s3_bucket_public_access_block" "example" {
  bucket                  = aws_s3_bucket.storage.id # Исправлено с backup_bucket на storage
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}