# Random Suffix - Generates a unique identifier for resource naming
resource "random_string" "suffix_processing" {
  length  = 6
  special = false
  upper   = false
}

# AWS Glue Data Catalog - Stores metadata for data processing
resource "aws_glue_catalog_database" "example" {
  name = "unique-database-${random_string.suffix_processing.result}"
  tags = var.tags
}

# AWS Glue Workflow - Orchestrates ETL pipeline execution
resource "aws_glue_workflow" "etl_pipeline" {
  name        = "etl-pipeline-${random_string.suffix_processing.result}"
  description = "ETL pipeline using AWS Glue"
  tags        = var.tags
}

# AWS Glue Trigger - Starts the Glue job on demand
resource "aws_glue_trigger" "etl_trigger" {
  name          = "etl-trigger-${random_string.suffix_processing.result}"
  type          = "ON_DEMAND"
  workflow_name = aws_glue_workflow.etl_pipeline.name
  actions {
    job_name = aws_glue_job.copy_blob_to_data_lake.name
  }
}

# AWS Glue Job - Copies data from blob storage to data lake
resource "aws_glue_job" "copy_blob_to_data_lake" {
  name     = "copy-blob-to-data-lake"
  role_arn = aws_iam_role.glue_service_role.arn
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/scripts/copy_blob_to_datalake.py"
    python_version  = "3"
  }
  default_arguments = {
    "--TempDir"    = "s3://${aws_s3_bucket.temp.bucket}/temp/"
    "--inputPath"  = "s3://${aws_s3_bucket.blob_storage.bucket}/example-folder/example-file.csv"
    "--outputPath" = "s3://${aws_s3_bucket.data_lake.bucket}/processed-data/"
  }
  max_capacity = 2
  tags        = var.tags
}

# AWS EMR Cluster - Manages a distributed big data processing cluster
resource "aws_emr_cluster" "databricks_emr" {
  name          = "databricks-emr-cluster-${random_string.suffix_processing.result}"
  release_label = "emr-6.10.0"
  applications  = ["Spark", "Hadoop"]
  service_role  = aws_iam_role.emr_service_role.name

  ec2_attributes {
    key_name         = var.ssh_key_name
    instance_profile = aws_iam_instance_profile.emr_ec2_instance_profile.name
    subnet_id        = aws_subnet.emr_subnet.id
  }

  master_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 1
  }

  core_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 2
  }

  bootstrap_action {
    name = "Install dependencies"
    path = "s3://${aws_s3_bucket.scripts.bucket}/bootstrap/install_dependencies.sh"
  }

  configurations_json = jsonencode([
    {
      Classification = "spark",
      Properties = {
        "spark.executor.memory" = "2G",
        "spark.executor.cores"  = "2"
      }
    }
  ])

  tags = var.tags
}

# S3 Bucket for Blob Storage - Stores raw data files
resource "aws_s3_bucket" "blob_storage" {
  bucket = "blob-storage-${random_string.suffix_processing.result}"
  tags   = var.tags
}

# Example Blob Data File - Placeholder CSV file in S3
resource "aws_s3_object" "example_blob" {
  bucket  = aws_s3_bucket.blob_storage.id
  key     = "example-file.csv"
  content = "column1,column2,column3\nrow1col1,row1col2,row1col3"
  tags    = var.tags
}

# S3 Bucket for Data Lake - Stores processed data
resource "aws_s3_bucket" "data_lake" {
  bucket        = "data-lake-${random_string.suffix_processing.result}"
  force_destroy = true
  tags          = var.tags
}

# S3 Bucket for Scripts - Stores Glue and EMR scripts
resource "aws_s3_bucket" "scripts" {
  bucket = "scripts-bucket-${random_string.suffix_processing.result}"
  tags   = var.tags
}

# S3 Bucket for Temporary Files - Stores intermediate processing data
resource "aws_s3_bucket" "temp" {
  bucket = "temp-bucket-${random_string.suffix_processing.result}"
  tags   = var.tags
}

# AWS Glue Table - Defines dataset schema for Redshift
resource "aws_glue_catalog_table" "redshift_dataset" {
  name          = "redshift-dataset"
  database_name = aws_glue_catalog_database.example.name
  table_type    = "EXTERNAL_TABLE"
  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.bucket}/processed-data/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
    }
  }
}

# AWS Lambda Function - Runs ETL processing
resource "aws_lambda_function" "etl_processor" {
  filename         = "etl_processor.zip"
  function_name    = "etl-processor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("etl_processor.zip")
  tags             = var.tags
}

