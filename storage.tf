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