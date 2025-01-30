# 1. Random Suffix for Unique Naming
resource "random_string" "suffix_processing" {
  length  = 6
  special = false
  upper   = false
}

# 24. AWS Glue Data Catalog
resource "aws_glue_catalog_database" "example" {
  name = "unique-database-${random_string.suffix_processing.result}"

  tags = var.tags
}

# 25. ETL Pipeline with Glue Workflow
resource "aws_glue_workflow" "etl_pipeline" {
  name        = "etl-pipeline-${random_string.suffix_processing.result}"
  description = "ETL pipeline using AWS Glue"

  tags = var.tags
}

resource "aws_glue_trigger" "etl_trigger" {
  name          = "etl-trigger-${random_string.suffix_processing.result}"
  type          = "ON_DEMAND"
  workflow_name = aws_glue_workflow.etl_pipeline.name
  actions {
    job_name = aws_glue_job.copy_blob_to_data_lake.name
  }
}

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

  tags = var.tags
}

# 26. Databricks ETL Pipeline (AWS EMR equivalent)
resource "aws_emr_cluster" "databricks_emr" {
  name          = "databricks-emr-cluster-${random_string.suffix_processing.result}"
  release_label = "emr-6.10.0"
  applications  = ["Spark", "Hadoop"]

  service_role = aws_iam_role.emr_service_role.name

  ec2_attributes {
    key_name         = var.ssh_key_name
    instance_profile = aws_iam_instance_profile.emr_ec2_instance_profile.name # Здесь указано
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

# 27. Linked Service for S3 Blob Storage
resource "aws_s3_bucket" "blob_storage" {
  bucket = "blob-storage-${random_string.suffix_processing.result}"

  tags = var.tags
}

# Заглушка для example-file.csv
resource "aws_s3_object" "example_blob" {
  bucket  = aws_s3_bucket.blob_storage.id
  key     = "example-file.csv"
  content = "column1,column2,column3\nrow1col1,row1col2,row1col3" # Заглушка

  tags = var.tags
}

# 28. Linked Service for S3 Data Lake
resource "aws_s3_bucket" "data_lake" {
  bucket        = "data-lake-${random_string.suffix_processing.result}"
  force_destroy = true
  tags          = var.tags
}

# Scripts Bucket
resource "aws_s3_bucket" "scripts" {
  bucket = "scripts-bucket-${random_string.suffix_processing.result}"

  tags = var.tags
}

# Temp Bucket
resource "aws_s3_bucket" "temp" {
  bucket = "temp-bucket-${random_string.suffix_processing.result}"

  tags = var.tags
}

# IAM Role for Glue
resource "aws_iam_role" "glue_service_role" {
  name = "glue-service-role-${random_string.suffix_processing.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_policy" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# IAM Role and Instance Profile for EMR
## Service Role
resource "aws_iam_role" "emr_service_role" {
  name = "emr-service-role-${random_string.suffix_processing.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "emr_service_policy" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

## Instance Role for EC2
resource "aws_iam_role" "emr_ec2_instance_role" {
  name = "emr-ec2-role-${random_string.suffix_processing.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "emr_ec2_policy" {
  role       = aws_iam_role.emr_ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

resource "aws_iam_instance_profile" "emr_ec2_instance_profile" {
  name = "emr-ec2-instance-profile-${random_string.suffix_processing.result}"
  role = aws_iam_role.emr_ec2_instance_role.name
  tags = var.tags
}

resource "aws_iam_instance_profile" "emr_profile" {
  name = "emr-profile-${random_string.suffix_processing.result}"
  role = aws_iam_role.emr_service_role.name

  tags = var.tags
}

# 30. Dataset for Redshift SQL Table
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

# 31. Dataset for S3 Blob
resource "aws_glue_catalog_table" "blob_dataset" {
  name          = "blob-dataset"
  database_name = aws_glue_catalog_database.example.name
  table_type    = "EXTERNAL_TABLE"
  storage_descriptor {
    location      = "s3://${aws_s3_bucket.blob_storage.bucket}/example-folder/example-file.csv"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
    }
  }

}

resource "aws_glue_job" "example" {
  name     = "example-glue-job"
  role_arn = aws_iam_role.example.arn
  command {
    name            = "glueetl"
    script_location = "s3://path-to-script/script.py"
    python_version  = "3"
  }

  tags = var.tags
}

resource "aws_emr_cluster" "example" {
  name          = "example-emr-cluster"
  release_label = "emr-6.3.0"

  master_instance_group {
    instance_type = "m5.xlarge"
  }

  core_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 2
  }

  service_role = aws_iam_role.emr_service.arn

  tags = var.tags
}

resource "aws_lambda_function" "etl_processor" {
  filename         = "etl_processor.zip"
  function_name    = "etl-processor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("etl_processor.zip")

  tags = var.tags
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "kinesis_glue_access" {
  role       = aws_iam_role.kinesis_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.kinesis_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role" "athena_role" {
  name = "athena-role-${random_string.suffix_analytics.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "athena.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "athena_s3_access" {
  role       = aws_iam_role.athena_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}