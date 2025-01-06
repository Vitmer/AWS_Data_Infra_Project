# 14. S3 Bucket (analog of Azure Storage Account)
resource "aws_s3_bucket" "storage" {
  bucket = var.storage_account_name

  tags = var.tags
}

# Versioning for S3 Bucket
resource "aws_s3_bucket_versioning" "storage_versioning" {
  bucket = aws_s3_bucket.storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-Side Encryption for S3 Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "storage_encryption" {
  bucket = aws_s3_bucket.storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Lifecycle Configuration
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

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "storage_policy" {
  bucket = aws_s3_bucket.storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:*"
        Effect   = "Allow"
        Principal = "*"
        Resource = [
          "${aws_s3_bucket.storage.arn}/*"
        ]
      }
    ]
  })
}

# 15. Data Lake Gen2 Filesystem → S3 Bucket Folder
resource "aws_s3_object" "data_lake_filesystem" {
  bucket = aws_s3_bucket.storage.id
  key    = "datalake-filesystem/" # Creates a folder in S3
  source = null # The folder is created in S3 by adding "/"
}

# 16. Storage Container → S3 Folder
resource "aws_s3_object" "data_container" {
  bucket = aws_s3_bucket.storage.id
  key    = "data-container/" # Creates a container (folder) in S3
  source = null
}

# 17. Blob Storage → S3 Object
resource "aws_s3_object" "data_blob" {
  bucket = aws_s3_bucket.storage.id
  key    = "data-container/data-blob" # Placement in the data-container folder
  content = "Hello, this is a test file!" # Content of the object
  acl     = "private"
}

# S3 Bucket for CloudTrail
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = "${var.storage_account_name}-cloudtrail"

  tags = {
    Name = "CloudTrail Bucket"
  }
}

# S3 Bucket for Glacier
resource "aws_s3_bucket" "glacier_bucket" {
  bucket = "${var.storage_account_name}-glacier"

  tags = {
    Name = "Glacier Bucket"
  }
}



# Amazon Redshift Cluster
resource "aws_redshift_cluster" "example" {
  cluster_identifier = "example-cluster"
  node_type          = "dc2.large"
  master_username    = var.redshift_master_username
  master_password    = var.redshift_master_password
  cluster_type       = "single-node"
  database_name      = "exampledb"

  tags = var.tags

  skip_final_snapshot = true
}

resource "aws_iam_policy" "s3_policy" {
  name   = "s3-access-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:*"],
        Resource = [
          "${aws_s3_bucket.storage.arn}/*"
        ]
      }
    ]
  })
}