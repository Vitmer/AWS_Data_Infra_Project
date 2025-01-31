# AWS Provider Configuration - Specifies the region
provider "aws" {
  region = var.aws_region
}

# Terraform Backend Configuration - Stores state in an S3 bucket
terraform {
  backend "s3" {
    bucket         = "my-terraform-backend-new"
    key            = "terraform/state"
    region         = "eu-central-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

# Virtual Private Cloud (VPC) - Defines the network environment
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Public Subnet - Assigns public IP addresses and allows internet access
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone_a
}

# Private Subnet - Internal subnet with no public access
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.availability_zone_a
  tags              = var.tags
}

# Subnet for Amazon Redshift - Used for Redshift cluster
resource "aws_subnet" "redshift_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = false
  tags                    = var.tags
}

# Second Redshift Subnet - Ensures multi-AZ deployment
resource "aws_subnet" "redshift_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = false
  tags                    = var.tags
}

# Subnet for EMR Cluster - Used for data processing
resource "aws_subnet" "emr_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = false
  tags                    = var.tags
}

# Redshift Subnet Group - Groups subnets for Redshift
resource "aws_redshift_subnet_group" "redshift_subnet_group" {
  name        = "redshift-subnet-group"
  description = "Subnet group for Redshift"
  subnet_ids  = [
    aws_subnet.redshift_subnet.id,
    aws_subnet.redshift_subnet_b.id
  ]
  tags = var.tags
}

# Internet Gateway - Provides internet access to the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = var.tags
}

# Public Route Table - Routes public traffic via Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = var.tags
}

# Private Route Table - Routes private traffic via NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Allow private subnets to access the internet via NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = var.tags
  depends_on = [aws_nat_gateway.main]
}

# NAT Gateway - Allows private subnets to access the internet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags          = var.tags
  depends_on    = [aws_internet_gateway.main]
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = var.tags
}

# Route Table Associations for Redshift - Ensures correct routing
resource "aws_route_table_association" "redshift_a" {
  subnet_id      = aws_subnet.redshift_subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "redshift_b" {
  subnet_id      = aws_subnet.redshift_subnet_b.id
  route_table_id = aws_route_table.private.id
}

# 🔹 EMR Route Table Association - Ensure EMR subnet uses NAT Gateway
resource "aws_route_table_association" "emr_private_association" {
  subnet_id      = aws_subnet.emr_subnet.id
  route_table_id = aws_route_table.private.id
}

# Bastion Host - Public access for remote management
resource "aws_instance" "bastion_public" {
  ami             = var.ami_id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.public_sg.id]
  key_name        = var.ssh_key_name
  tags            = var.tags
}

# Backup Vault - Stores EC2 snapshots
resource "aws_backup_vault" "backup_vault" {
  name = "ec2-backup-vault-${random_string.suffix.result}"
}

# CloudWatch Log Group - Stores application logs
resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/example"
  retention_in_days = 14 # Keeps logs for 14 days
}

# AWS Backup Plan - Creates daily backups for EC2 instances
resource "aws_backup_plan" "daily_backup" {
  name = "daily-backup-plan"
  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 23 * * ? *)"
    lifecycle {
      delete_after = 30 # Retains backups for 30 days
    }
  }
  tags = var.tags
}

# Output - Returns Redshift Subnet ID
output "redshift_subnet_id" {
  description = "Subnet ID for Redshift"
  value       = aws_subnet.redshift_subnet.id
}