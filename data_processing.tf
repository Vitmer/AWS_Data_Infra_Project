# 24. AWS Glue Data Catalog
resource "aws_glue_catalog_database" "example" {
  name = "unique-database-${random_string.suffix_processing.result}"
}

# 25. ETL Pipeline with Glue Workflow
resource "aws_glue_workflow" "etl_pipeline" {
  name        = "etl-pipeline-${random_string.suffix_processing.result}"
  description = "ETL pipeline using AWS Glue"
}

resource "aws_glue_trigger" "etl_trigger" {
  name           = "etl-trigger-${random_string.suffix_processing.result}"
  type           = "ON_DEMAND"
  workflow_name  = aws_glue_workflow.etl_pipeline.name
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
    "--TempDir"   = "s3://${aws_s3_bucket.temp.bucket}/temp/"
    "--inputPath" = "s3://${aws_s3_bucket.blob_storage.bucket}/example-folder/example-file.csv"
    "--outputPath" = "s3://${aws_s3_bucket.data_lake.bucket}/processed-data/"
  }
  max_capacity = 2
}

# 26. Databricks ETL Pipeline (AWS EMR equivalent)
resource "aws_emr_cluster" "databricks_emr" {
  name          = "databricks-emr-cluster-${random_string.suffix_processing.result}"
  release_label = "emr-6.10.0"
  applications  = ["Spark", "Hadoop"]

  service_role = aws_iam_role.emr_service_role.name

  ec2_attributes {
    key_name          = var.ssh_key_name
    instance_profile  = aws_iam_instance_profile.emr_profile.arn
    subnet_id         = aws_subnet.main.id
  }

  master_instance_group {
    instance_type = "m5.xlarge"
    instance_count = 1
  }

  core_instance_group {
    instance_type = "m5.xlarge"
    instance_count = 2
  }

  bootstrap_action {
    name = "Install dependencies"
    path = "s3://${aws_s3_bucket.scripts.bucket}/bootstrap/install_dependencies.sh"
  }

  configurations_json = jsonencode([
    {
      Classification = "spark",
      Properties     = {
        "spark.executor.memory" = "2G",
        "spark.executor.cores"  = "2"
      }
    }
  ])
}

# 27. Linked Service for S3 Blob Storage
resource "aws_s3_bucket" "blob_storage" {
  bucket = "blob-storage-${random_string.suffix_processing.result}"
}

resource "aws_s3_object" "example_blob" {
  bucket = aws_s3_bucket.blob_storage.id
  key    = "example-folder/example-file.csv"
  source = "path/to/local/example-file.csv"
  acl    = "private"
}

# 28. Linked Service for S3 Data Lake
resource "aws_s3_bucket" "data_lake" {
  bucket = "data-lake-${random_string.suffix_processing.result}"
}

# Scripts Bucket
resource "aws_s3_bucket" "scripts" {
  bucket = "scripts-bucket-${random_string.suffix_processing.result}"
}

# Temp Bucket
resource "aws_s3_bucket" "temp" {
  bucket = "temp-bucket-${random_string.suffix_processing.result}"
}

# IAM Role for Glue
resource "aws_iam_role" "glue_service_role" {
  name = "glue-service-role-${random_string.suffix_processing.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_policy" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# IAM Role and Instance Profile for EMR
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
}

resource "aws_iam_role_policy_attachment" "emr_service_policy" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

resource "aws_iam_instance_profile" "emr_profile" {
  name = "emr-profile-${random_string.suffix_processing.result}"
  role = aws_iam_role.emr_service_role.name
}

# Subnet for EMR
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
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

# 38. Random Suffix for Unique Naming
resource "random_string" "suffix_processing" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_glue_job" "example" {
  name     = "example-glue-job"
  role_arn = aws_iam_role.example.arn
  command {
    name            = "glueetl"
    script_location = "s3://path-to-script/script.py"
    python_version  = "3"
  }
}

resource "aws_emr_cluster" "example" {
  name          = "example-emr-cluster"
  release_label = "emr-6.3.0"

  master_instance_group {
    instance_type = "m5.xlarge"
  }

  core_instance_group {
    instance_type = "m5.xlarge"
    instance_count = 2
  }

  service_role = aws_iam_role.emr_service.arn
}

resource "aws_lambda_function" "etl_processor" {
  filename         = "etl_processor.zip"
  function_name    = "etl-processor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("etl_processor.zip")
}

resource "aws_iam_role" "lambda_exec" {
  name               = "lambda-exec-role"
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
}