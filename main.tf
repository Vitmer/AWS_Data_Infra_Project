provider "aws" {
  region = var.aws_region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"

}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1a"

  tags = var.tags
}

resource "aws_subnet" "redshift_subnet" {
  vpc_id                  = aws_vpc.main.id # Убедись, что это Terraform VPC!
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false
  tags                    = var.tags
}

resource "aws_subnet" "redshift_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "eu-central-1b" # 🔹 Новая зона для отказоустойчивости
  map_public_ip_on_launch = false
  tags                    = var.tags
}

# Subnet for EMR
resource "aws_subnet" "emr_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false

  tags = var.tags
}

# 🔹 Группа подсетей для Redshift
resource "aws_redshift_subnet_group" "redshift_subnet_group" {
  name        = "redshift-subnet-group"
  description = "Subnet group for Redshift"
  subnet_ids = [
    aws_subnet.redshift_subnet.id,
    aws_subnet.redshift_subnet_b.id
  ]

  tags = var.tags
}

resource "aws_route_table_association" "redshift_a" {
  subnet_id      = aws_subnet.redshift_subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "redshift_b" {
  subnet_id      = aws_subnet.redshift_subnet_b.id
  route_table_id = aws_route_table.private.id
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = var.tags
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = var.tags
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = var.tags

  depends_on = [aws_nat_gateway.main]
}

resource "aws_route_table_association" "emr" {
  subnet_id      = aws_subnet.emr_subnet.id
  route_table_id = aws_route_table.public.id
}

# Route Table Association (Public)
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Route Table Association (Private)
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = var.tags

  depends_on = [aws_internet_gateway.main, aws_eip.nat] # Ждём создания IGW и EIP
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = var.tags
}

# Security Group (Public)
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # SSH только с твоего IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Разрешить весь исходящий трафик
  }

  tags = var.tags
}

# Security Group (Private)
resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id] # ✅ Только для bastion host!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group" "redshift_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "redshift-sg"
  description = "Security group for Redshift"

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # ✅ Разрешаем доступ только внутри VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Bastion Host (Public)
resource "aws_instance" "bastion_public" {
  ami             = var.ami_id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.public_sg.id]

  tags = var.tags

  key_name = var.ssh_key_name
}

# Bastion Host (Private)
resource "aws_instance" "bastion_private" {
  ami             = var.ami_id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.private_sg.id]

  tags = var.tags

  key_name = var.ssh_key_name
}

# Backup Vault (S3 bucket for snapshots)
resource "aws_s3_bucket" "backup_bucket" {
  bucket = "ec2-backup-bucket-${lower(random_string.bucket_suffix.result)}"

  #lifecycle {
  #  prevent_destroy = true
  #}

  tags = var.tags
}

# S3 Bucket Versioning Configuration
resource "aws_s3_bucket_versioning" "backup_bucket_versioning" {
  bucket = aws_s3_bucket.backup_bucket.id

  versioning_configuration {
    status = "Enabled" # Enables versioning for the S3 bucket
  }
}

# Generates a random suffix for resource names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
}

# Backup Policies
resource "aws_backup_plan" "daily_backup" {
  name = "daily-backup-plan"

  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 23 * * ? *)" # Runs backup daily at 23:00 UTC

    lifecycle {
      delete_after = 30 # Retains backups for 30 days before deletion
    }
  }

  tags = var.tags # Applies tags from variables
}

# Generates a random suffix for backup vault naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Backup Vault for storing backups
resource "aws_backup_vault" "backup_vault" {
  name = "ec2-backup-vault-${random_string.suffix.result}"
}

# Backup Selection - Defines resources to back up
resource "aws_backup_selection" "backup_selection" {
  name         = "Backup-Selection"
  iam_role_arn = aws_iam_role.backup_role.arn
  plan_id      = aws_backup_plan.daily_backup.id

  resources = [
    aws_instance.bastion_public.arn,
    aws_instance.bastion_private.arn
  ]

  depends_on = [aws_iam_role_policy_attachment.backup_vault_access] # Ждём IAM роль + политики
}

# IAM Role for AWS Backup Service
resource "aws_iam_role" "backup_role" {
  name = "BackupRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  lifecycle {
    prevent_destroy = false # Allows Terraform to destroy this role if needed
  }

  tags = var.tags
}

# Attaches AWS Backup service policy to IAM Role
resource "aws_iam_role_policy_attachment" "backup_vault_access" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"

  depends_on = [aws_iam_role.backup_role]
}

# CloudWatch Log Group for storing logs
resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/example"
  retention_in_days = 14 # Keeps logs for 14 days
}

# Example Backup Plan with different schedule
resource "aws_backup_plan" "example" {
  name = "example-backup-plan"
  rule {
    rule_name         = "example-rule"
    target_vault_name = aws_backup_vault.backup_vault.id
    schedule          = "cron(0 12 * * ? *)"
  }
  tags = var.tags
}

# Autoscaling Group Configuration
resource "aws_autoscaling_group" "example" {
  vpc_zone_identifier = [aws_subnet.public.id]
  max_size            = 5 # Maximum number of instances
  min_size            = 1 # Minimum number of instances

  launch_template {
    id      = aws_launch_template.example.id
    version = aws_launch_template.example.latest_version
  }

  dynamic "tag" {
    for_each = { for k, v in var.tags : k => v }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Launch Template for EC2 instances
resource "aws_launch_template" "example" {
  name          = "example-launch-template"
  image_id      = var.ami_id # Specifies the AMI ID for the instance
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.public_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags          = var.tags # Applies tags to instances created from this template
  }
}

# Network ACL Configuration
resource "aws_network_acl" "example" {
  vpc_id = aws_vpc.main.id

  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Разрешаем только HTTP/HTTPS и SSH
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = aws_vpc.main.cidr_block
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = aws_vpc.main.cidr_block
    from_port  = 443
    to_port    = 443
  }

  tags = var.tags
}

output "redshift_subnet_id" {
  description = "ID подсети для Redshift"
  value       = aws_subnet.redshift_subnet.id
}