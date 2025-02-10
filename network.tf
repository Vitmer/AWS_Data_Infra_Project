# ==================================
# Terraform Configuration & Backend
# ==================================

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
    access_logging {
      target_bucket = "terraform-logs-bucket"
      target_prefix = "logs/"
    }
  }
}

# =================================================
# Networking (VPC, Subnets, Route Tables, NAT, IGW)
# =================================================

# Virtual Private Cloud (VPC) - Defines the network environment
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Internet Gateway - Provides internet access to the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = var.tags
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

# Redshift Subnet - Used for Amazon Redshift cluster
resource "aws_subnet" "redshift_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = false
  tags                    = var.tags
}

# Additional Redshift Subnet - Used for Multi-AZ deployments
resource "aws_subnet" "redshift_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = false
  tags                    = var.tags
}

# Redshift Subnet Group - Defines which subnets the Redshift cluster can use
resource "aws_redshift_subnet_group" "redshift_subnet_group" {
  name        = "redshift-subnet-group"
  description = "Subnet group for Redshift"
  subnet_ids  = [
    aws_subnet.redshift_subnet.id,
    aws_subnet.redshift_subnet_b.id
  ]
  tags = var.tags
}

# EMR Subnet - Used for AWS EMR cluster
resource "aws_subnet" "emr_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = false
  tags                    = var.tags
}

# NAT Gateway - Allows private subnets to access the internet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags          = var.tags
}

# Elastic IP for NAT Gateway - Required for NAT public IP assignment
resource "aws_eip" "nat" {
  domain = "vpc"
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

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = var.tags
  depends_on = [aws_nat_gateway.main]
}

# Route Table Association for Redshift Subnet A - Ensures correct routing
resource "aws_route_table_association" "redshift_a" {
  subnet_id      = aws_subnet.redshift_subnet.id
  route_table_id = aws_route_table.private.id
}

# Route Table Association for Redshift Subnet B - Ensures correct routing
resource "aws_route_table_association" "redshift_b" {
  subnet_id      = aws_subnet.redshift_subnet_b.id
  route_table_id = aws_route_table.private.id
}

# EMR Route Table Association - Ensures EMR subnet uses NAT Gateway
resource "aws_route_table_association" "emr_private_association" {
  subnet_id      = aws_subnet.emr_subnet.id
  route_table_id = aws_route_table.private.id
}

# VPN Gateway - Connects the VPC with the on-premises network
resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = var.tags
}

# Customer Gateway - Represents the on-premises VPN device (replace IP with yours)
resource "aws_customer_gateway" "customer" {
  bgp_asn    = 65000
  ip_address = "203.0.113.1"  # Replace with the on-premises network IP
  type       = "ipsec.1"
  tags       = var.tags
}

# VPN Connection - Establishes a secure connection between AWS and on-premises
resource "aws_vpn_connection" "vpn" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.customer.id
  type               = "ipsec.1"
  static_routes_only = false
  tunnel1_inside_cidr = "169.254.10.0/30"
}

# PrivateLink for Redshift - Provides a secure connection to Redshift
resource "aws_vpc_endpoint" "redshift" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.eu-central-1.redshift"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.redshift_subnet.id]
  security_group_ids = [aws_security_group.redshift_sg.id]
}

# PrivateLink for S3 - Enables secure private access to S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private.id]
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

# ========================================
# Security (Security Groups, Firewall, WAF)
# ========================================

# Security Group for Redshift - Controls access to the Redshift cluster
resource "aws_security_group" "redshift_sg" {
  name        = "redshift-sg"
  description = "Security Group for Redshift"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24", "10.0.3.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow outbound traffic
  }
}

# AWS Network Firewall - Provides advanced security for VPC
resource "aws_networkfirewall_firewall" "main" {
  name                = "main-firewall"
  vpc_id             = aws_vpc.main.id
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn

  subnet_mapping {
    subnet_id = aws_subnet.private.id
  }
}

# AWS WAF Association - Protects API Gateway with Web Application Firewall
resource "aws_wafv2_web_acl_association" "api_waf" {
  resource_arn = aws_apigatewayv2_api.example.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# Security Group for Bastion - Controls access rules for the Bastion host
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Security Group for Bastion"
  vpc_id      = aws_vpc.main.id

  # Allows SSH access to Bastion from the internet (can be restricted by IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.1.0/24"]  
  }

  # Allows Bastion to establish connections with EC2 instances
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.2.0/24"]  # Allows outbound traffic to the private subnet
  }
}

# Network Firewall Policy - Defines firewall rules for controlling traffic
resource "aws_networkfirewall_firewall_policy" "main" {
  name = "firewall-policy"

  firewall_policy {
    stateless_default_actions            = ["aws:pass"]  # Allows all traffic by default
    stateless_fragment_default_actions   = ["aws:drop"]  # Drops packets unrelated to established connections

    stateless_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateless.arn
      priority     = 1
    }
  }
}

# Stateless Firewall Rule Group - Defines stateless firewall rules
resource "aws_networkfirewall_rule_group" "stateless" {
  capacity = 100
  name     = "stateless-rule-group"
  type     = "STATELESS"
  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        stateless_rule {
          priority = 1
          rule_definition {
            match_attributes {
              protocols = [6]  # TCP
            }
            actions = ["aws:pass"]
          }
        }
      }
    }
  }
}


# =================================================
# Compute (Bastion Host, Load Balancer, API Gateway)
# =================================================

# Bastion Host - Provides public SSH access for remote management
resource "aws_instance" "bastion_public" {
  ami             = var.ami_id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.bastion_sg.id]
  key_name        = var.ssh_key_name
  tags            = var.tags
}

# Load Balancer Target Group - Routes traffic to backend services
resource "aws_lb_target_group" "example_tg" {
  name     = "example-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    interval            = 30
    path                = "/health"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# API Gateway - Manages HTTP APIs
resource "aws_apigatewayv2_api" "example" {
  name          = "example-api"
  protocol_type = "HTTP"
}

# =================================================
# Output
# =================================================

# Output - Returns Redshift Subnet ID
output "redshift_subnet_id" {
  description = "Subnet ID for Redshift"
  value       = aws_subnet.redshift_subnet.id
}























