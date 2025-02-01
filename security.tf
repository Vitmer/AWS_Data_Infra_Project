# ========== RANDOM STRINGS  ==========
variable "random_names" {
  default = [
    "synapse_sql_password",  # For Synapse SQL secret
    "example_password",      # For demonstration secret
    "suffix",                # For S3 buckets or other unique names
    "synapse_secret",        # For Synapse KMS or other bindings
    "example_secret"         # Example for usage
  ]
}

resource "random_string" "random_suffixes" {
  for_each = toset(var.random_names)

  length  = 6
  special = false
  upper   = false
}

# ========== IAM РОЛИ  ==========
variable "iam_roles" {
  type = map(object({
    name    = string
    service = string
  }))
  
  default = {
    emr_service   = { name = "emr-service-role", service = "elasticmapreduce.amazonaws.com" }
    emr_role      = { name = "EMR_DefaultRole", service = "elasticmapreduce.amazonaws.com" }
    lambda_exec   = { name = "lambda-exec-role", service = "lambda.amazonaws.com" }
    config_role   = { name = "config-role", service = "config.amazonaws.com" }
    s3_access     = { name = "s3-access-role", service = "s3.amazonaws.com" }  
    athena_role   = { name = "athena-role", service = "athena.amazonaws.com" }  
    glue_role     = { name = "glue-service-role", service = "glue.amazonaws.com" } 
    redshift_role = { name = "redshift-role", service = "redshift.amazonaws.com" }
    vpc_flow_logs = { name = "vpc-flow-logs-role", service = "vpc-flow-logs.amazonaws.com" }
  }
}

resource "aws_iam_role" "iam_roles" {
  for_each = var.iam_roles

  name = each.value.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = each.value.service }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

# ========== IAM ПОЛИТИКИ  ==========
variable "iam_policies" {
  type = map(object({
    name        = string
    description = string
    policy_arn  = string
  }))
  
  default = {
    s3_access     = { name = "S3FullAccess", description = "Full S3 Access", policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" }
    athena_role   = { name = "AthenaFullAccess", description = "Athena full access", policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess" }
    lambda_exec   = { name = "LambdaBasicExecution", description = "Lambda execution", policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" }
    glue_role     = { name = "GlueServiceRole", description = "Glue service role", policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole" }
    redshift_role = { name = "RedshiftFullAccess", description = "Full Redshift Access", policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftFullAccess" }
    emr_role      = { name = "EMRFullAccess", description = "Full EMR Access", policy_arn = "arn:aws:iam::aws:policy/AmazonElasticMapReduceFullAccess" }
    config_role   = { name = "ConfigAccess", description = "AWS Config Access", policy_arn = "arn:aws:iam::aws:policy/AWSConfigUserAccess" }
    vpc_flow_logs = { name = "VpcFlowLogsAccess", description = "Allows VPC Flow Logs to write to CloudWatch", policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess" }
  }
}

resource "aws_iam_role_policy_attachment" "iam_policy_attachments" {
  for_each = var.iam_policies

  role       = aws_iam_role.iam_roles[each.key].name 
  policy_arn = each.value.policy_arn
}

# ========== SECURITY GROUPS  ==========
variable "security_groups" {
  type = map(object({
    name        = string
    description = string
    ingress     = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)  
    }))
  }))

  default = {
    public_sg = {
      name        = "public-sg"
      description = "Public SSH access"
      ingress = [{
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]  
      }]
    }
    redshift_sg = {
      name        = "redshift-sg"
      description = "Redshift VPC access"
      ingress = [{
        from_port   = 5439
        to_port     = 5439
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/16"]  
      }]
    }
  }
}

resource "aws_security_group" "sg" {
  for_each = var.security_groups

  name        = each.value.name
  description = each.value.description
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

# ========== SECRETS MANAGER  ==========
variable "secrets" {
  type = map(string)
  default = {
    synapse_sql_password = "synapse-sql-password"
    example_password     = "example-password"
  }
}

resource "aws_secretsmanager_secret" "secrets" {
  for_each = var.secrets

  name = "${each.key}-${random_string.random_suffixes[each.key].result}"

  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}

resource "aws_secretsmanager_secret" "synapse_sql_password" {
  name = "synapse-sql-password-${random_string.random_suffixes["synapse_secret"].result}"
  tags = var.tags
}

resource "aws_secretsmanager_secret" "example_password" {
  name = "example-password-${random_string.random_suffixes["example_secret"].result}"
  tags = var.tags
}

# ========== KMS KEY ==========
resource "aws_kms_key" "key" {
  description             = "KMS key for managing secrets"
  deletion_window_in_days = 7
  tags                    = var.tags
}

resource "aws_kms_alias" "key_alias" {
  name          = "alias/kms-central-${random_string.random_suffixes["suffix"].result}"
  target_key_id = aws_kms_key.key.id
}

resource "aws_kms_key" "cloudtrail_kms" {
  description             = "KMS key for CloudTrail logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags
}

# ========== S3 POLICIES ==========
resource "aws_s3_bucket_public_access_block" "bootstrap_access_block" {
  bucket = aws_s3_bucket.bootstrap.id

  block_public_acls       = true
  block_public_policy     = false  
  ignore_public_acls      = true
  restrict_public_buckets = false  
}

resource "aws_s3_bucket_policy" "bootstrap_access" {
  bucket = aws_s3_bucket.bootstrap.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = "*",
      Action    = ["s3:GetObject"],
      Resource  = "${aws_s3_bucket.bootstrap.arn}/*"
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.bootstrap_access_block]
}

# ========== LAMBDA FUNCTION ==========
resource "aws_lambda_function" "secret_rotation" {
  function_name = "secret-rotation-lambda"
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.iam_roles["lambda_exec"].arn
  filename      = "lambda.zip"

  depends_on = [null_resource.create_lambda_package]
}

resource "aws_secretsmanager_secret_rotation" "rotation" {
  secret_id           = aws_secretsmanager_secret.secrets["synapse_sql_password"].id
  rotation_lambda_arn = aws_lambda_function.secret_rotation.arn
  rotation_rules {
    automatically_after_days = 30
  }
}

# ========== CLOUDTRAIL ==========
resource "aws_cloudtrail" "example" {
  name           = "example-cloudtrail-unique"
  s3_bucket_name = "example-cloudtrail-bucket"
  kms_key_id     = aws_kms_key.cloudtrail_kms.arn  

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  is_multi_region_trail = true
  enable_logging        = true
}

resource "aws_iam_instance_profile" "emr_ec2_instance_profile" {
  name = "emr-ec2-instance-profile-${random_string.random_suffixes["suffix"].result}"
  role = aws_iam_role.iam_roles["emr_role"].name
}

resource "null_resource" "create_lambda_package" {
  provisioner "local-exec" {
    command = "zip -j ${path.module}/lambda.zip ${path.module}/lambda_function.py"
  }

  triggers = {
    lambda_function = filemd5("${path.module}/lambda_function.py")
  }
}