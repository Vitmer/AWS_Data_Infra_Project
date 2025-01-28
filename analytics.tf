# 33. Athena Workgroup
resource "aws_athena_workgroup" "athena_workgroup" {
  name = "athena-workgroup-${random_string.suffix_analytics.result}"
  configuration {
    enforce_workgroup_configuration = true
    publish_cloudwatch_metrics_enabled = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_lake.bucket}/query-results/"
    }

  }

  tags = var.tags
}

# 34. Redshift Cluster
resource "aws_redshift_cluster" "redshift_cluster" {
  cluster_identifier = "redshift-cluster-${random_string.suffix_analytics.result}"
  node_type          = "dc2.large"
  master_username    = "adminuser"
  master_password    = var.redshift_password
  number_of_nodes    = 2
  cluster_type       = "multi-node"
  publicly_accessible = false
  iam_roles = [
    aws_iam_role.redshift_role.arn
  ]
  tags = var.tags
}

# 35. IAM Role for Redshift
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

resource "aws_iam_role_policy_attachment" "redshift_s3_access" {
  role       = aws_iam_role.redshift_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# 36. Glue Connection for Redshift
resource "aws_glue_connection" "redshift_connection" {
  name = "redshift-connection-${random_string.suffix_analytics.result}"
  connection_properties = {
    JDBC_ENFORCE_SSL     = "true"
    JDBC_CONNECTION_URL  = "jdbc:redshift://${aws_redshift_cluster.redshift_cluster.endpoint}/dev"
    PASSWORD             = var.redshift_password
    USERNAME             = "adminuser"
  }
  tags = var.tags
}

# 37. Glue Database
resource "aws_glue_catalog_database" "glue_database" {
  name = "analytics-db-${random_string.suffix_analytics.result}"

  tags = var.tags
}

# 38. Glue Table for Redshift Data
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

# 39. Random Suffix for Unique Naming
resource "random_string" "suffix_analytics" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_quicksight_group" "example" {
  aws_account_id = var.aws_account_id
  namespace      = "default"
  group_name     = "example-group"

}

resource "aws_kinesisanalyticsv2_application" "example" {
  name                 = "example-kinesis-app"
  runtime_environment  = "SQL-1_0"
  service_execution_role = aws_iam_role.kinesis_exec.arn

  application_configuration {
    application_code_configuration {
      code_content {
        text_content = <<-EOT
          CREATE OR REPLACE STREAM "DESTINATION_SQL_STREAM" (
            id VARCHAR(16),
            value DOUBLE,
            timestamp TIMESTAMP
          );
        EOT
      }
      code_content_type = "PLAINTEXT"
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "kinesis_exec" {
  name               = "kinesis-exec-role"
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

resource "aws_kinesis_stream" "example" {
  name             = "example-stream"
  shard_count      = 1
  retention_period = 24 # Время хранения данных в часах

  tags = var.tags
}

resource "aws_quicksight_dashboard" "example" {
  aws_account_id       = var.aws_account_id
  dashboard_id         = var.quicksight_dashboard_id
  name                 = var.quicksight_dashboard_name
  version_description  = var.quicksight_dashboard_version_description

  source_entity {
  source_template {
    arn = var.quicksight_template_arn

    data_set_references {
      data_set_arn         = var.data_set_arn
      data_set_placeholder = "example-placeholder"
      }
    }
  }

  tags = var.tags
}