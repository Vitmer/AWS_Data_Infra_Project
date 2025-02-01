# Athena Workgroup - A managed query service for analyzing data stored in S3
resource "aws_athena_workgroup" "athena_workgroup" {
  name = "athena-workgroup-${random_string.suffix_analytics.result}"
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_lake.bucket}/query-results/"
    }
  }
  tags = var.tags

  depends_on = [aws_s3_bucket.data_lake] # Ensure the bucket is created before Athena
}

# Redshift Cluster - A managed data warehouse service
resource "aws_redshift_cluster" "redshift_cluster" {
  cluster_identifier      = "redshift-cluster-${random_string.suffix_analytics.result}"
  node_type               = "dc2.large"
  master_username         = var.redshift_master_username
  master_password         = var.redshift_password
  number_of_nodes         = 2
  cluster_type            = "multi-node"
  publicly_accessible     = true
  cluster_subnet_group_name = aws_redshift_subnet_group.redshift_subnet_group.name
  skip_final_snapshot = true

  iam_roles = [
    aws_iam_role.iam_roles["redshift_role"].arn
  ]

  enhanced_vpc_routing       = true  # Enables Concurrency Scaling for better performance
  automated_snapshot_retention_period = 7 # Configures automated backups

  depends_on = [
    aws_redshift_subnet_group.redshift_subnet_group,
    aws_route_table_association.redshift_a,
    aws_route_table_association.redshift_b
  ]

  tags = var.tags
}

# Glue Connection for Redshift - Establishes a JDBC connection to Redshift for ETL processing
resource "aws_glue_connection" "redshift_connection" {
  name = "redshift-connection-${random_string.suffix_analytics.result}"
  connection_properties = {
    JDBC_ENFORCE_SSL    = "true"
    JDBC_CONNECTION_URL = "jdbc:redshift://${aws_redshift_cluster.redshift_cluster.endpoint}:5439/dev"
    PASSWORD            = var.redshift_password
    USERNAME            = "adminuser"
  }
  tags = var.tags
}

# Glue Database - Stores metadata for Glue ETL jobs
resource "aws_glue_catalog_database" "glue_database" {
  name = "analytics-db-${random_string.suffix_analytics.result}"

  tags = var.tags
}

# Glue Table for Redshift Data - Defines an external table for Redshift data stored in S3
resource "aws_glue_catalog_table" "analytics_table" {
  name          = "analytics_table"
  database_name = aws_glue_catalog_database.glue_database.name
  table_type    = "EXTERNAL_TABLE"
  parameters = {
    EXTERNAL = "TRUE"
  }
  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.bucket}/analytics-data/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
    }
  }
}

# Random Suffix for Unique Naming - Ensures uniqueness across resources
resource "random_string" "suffix_analytics" {
  length  = 6
  special = false
  upper   = false
  keepers = {
    unique_id = "analytics"
  }
}

# Kinesis Stream - Creates a data stream for real-time analytics
resource "aws_kinesis_stream" "example" {
  name             = "example-stream"
  shard_count      = 1
  retention_period = 24 # Data retention period in hours

  tags = var.tags
}

# Quicksight Group - Creates a user group in AWS QuickSight
resource "aws_quicksight_group" "example" {
  aws_account_id = var.aws_account_id
  namespace      = "default"
  group_name     = "example-group"
}

# Quicksight Dashboard - Creates a dashboard for visualizing analytics data
resource "aws_quicksight_dashboard" "example" {
  aws_account_id      = var.aws_account_id
  dashboard_id        = var.quicksight_dashboard_id
  name                = var.quicksight_dashboard_name
  version_description = var.quicksight_dashboard_version_description

  source_entity {
    source_template {
      arn = var.quicksight_template_arn
      data_set_references {
        data_set_arn         = var.data_set_arn
        data_set_placeholder = "example-placeholder"
      }
    }
  }
  depends_on = [aws_quicksight_group.example]
  tags = var.tags
}

# S3 Bucket for Bootstrap Files - Stores initialization scripts and data
resource "aws_s3_bucket" "bootstrap" {
  bucket = "bootstrap-example-${random_string.random_suffixes["suffix"].result}"

  tags = var.tags
}

# S3 Object for Bootstrap Script - Uploads an initialization script to the S3 bucket
resource "aws_s3_object" "bootstrap_script" {
  bucket = aws_s3_bucket.bootstrap.id
  key    = "bootstrap.sh"
  source = "${path.module}/bootstrap.sh"
  etag   = filemd5("${path.module}/bootstrap.sh")
}

# S3 Object for Example Data - Stores example dataset in S3 for use in analytics
resource "aws_s3_object" "example_file" {
  bucket  = aws_s3_bucket.bootstrap.id
  key     = "example-data/manifest.json"
  content = jsonencode({
    fileLocations = [
      {
        URIPrefixes = ["s3://${aws_s3_bucket.bootstrap.bucket}/example-data/"]
      }
    ]
    globalUploadSettings = {
      format = "CSV"
    }
  })
  tags = var.tags
}
