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

# 1. VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

# 2. Subnets
resource "aws_subnet" "public" {
  vpc_id                   = aws_vpc.main.id
  cidr_block               = "10.0.1.0/24"
  map_public_ip_on_launch  = true
  availability_zone        = var.availability_zone

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.availability_zone

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

# 3. Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

# 4. Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

# 5. Route Table Associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# 6. NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

# 7. Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

# 8. Security Groups
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.example.id
  subnet_id     = aws_subnet.public.id
}


# 9. Bastion Hosts
resource "aws_instance" "bastion_public" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  security_groups = [aws_security_group.public_sg.id]

  tags = {
    Name = "AWS-Data-Infra-Project"
  }

  key_name = var.ssh_key_name
}

resource "aws_instance" "bastion_private" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id
  security_groups = [aws_security_group.private_sg.id]

  tags = {
    Name = "AWS-Data-Infra-Project"
  }

  key_name = var.ssh_key_name
}

# 10. Backup Vault (S3 bucket for snapshots)
resource "aws_s3_bucket" "backup_bucket" {
  bucket = "ec2-backup-bucket-${lower(random_string.bucket_suffix.result)}"

  #lifecycle {
  #  prevent_destroy = true
  #}

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

resource "aws_s3_bucket_versioning" "backup_bucket_versioning" {
  bucket = aws_s3_bucket.backup_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
}

# 11. Backup Policies
resource "aws_backup_plan" "daily_backup" {
  name = "daily-backup-plan"

  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 23 * * ? *)"

    lifecycle {
      delete_after = 30
    }
  }

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

resource "aws_backup_vault" "backup_vault" {
  name = "ec2-backup-vault"
}

resource "aws_backup_selection" "backup_selection" {
  name          = "Backup-Selection"
  iam_role_arn  = aws_iam_role.backup_role.arn
  plan_id       = aws_backup_plan.daily_backup.id

  resources = [
    aws_instance.bastion_public.arn,
    aws_instance.bastion_private.arn
  ]
}

# IAM Role for Backup
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

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

resource "aws_iam_role_policy_attachment" "backup_attach" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/example"
  retention_in_days = 14
}

resource "aws_backup_plan" "example" {
  name = "example-backup-plan"
  rule {
    rule_name         = "example-rule"
    target_vault_name = aws_backup_vault.example.name
    schedule          = "cron(0 12 * * ? *)"
  }
  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.id
  max_size             = 5
  min_size             = 1
}

resource "aws_eip" "example" {
  domain = "vpc"

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

resource "aws_backup_vault" "example" {
  name = "example-backup-vault"

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}

resource "aws_launch_configuration" "example" {
  name          = "example-launch-configuration"
  image_id      = "ami-12345678"
  instance_type = "t2.micro"

}

resource "aws_network_acl" "example" {
  vpc_id = aws_vpc.main.id

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "AWS-Data-Infra-Project"
  }
}