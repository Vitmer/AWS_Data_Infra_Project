

# AWS Credentials
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "aws_access_key" {
  description = "AWS access key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
}

variable "availability_zone_a" {
  description = "Availability Zone A for deploying resources"
  type        = string
}

variable "availability_zone_b" {
  description = "Availability Zone B for deploying resources"
  type        = string
}

# Instance Configuration
variable "ami_id" {
  description = "AMI ID for the EC2 instances"
  type        = string
  default     = "ami-01a0731204136ddad" # Replace with your preferred AMI ID
}

variable "availability_zone" {
  description = "Availability Zone for the subnets"
  type        = string
  default     = "eu-central-1a"
}

# Resource Names
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "AWS-Data-Infra-VPC"
}

variable "public_vm_name" {
  description = "Name of the public-facing VM"
  type        = string
  default     = "Public-VM"
}

variable "private_vm_name" {
  description = "Name of the private VM"
  type        = string
  default     = "Private-VM"
}

variable "bastion_host_name" {
  description = "Name of the Bastion Host"
  type        = string
  default     = "Bastion-Host"
}

# Backup
variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "ssh_key_name" {
  description = "The name of the SSH key pair to use for EC2 instances"
  type        = string
}

variable "redshift_password" {
  description = "Master password for the Redshift cluster"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "The ID of the VPC where the subnet will be created"
  type        = string
}

variable "tags" {
  description = "Tags to associate with resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "AWS-Data-Infra-Project"
  }
}

variable "synapse_sql_password" {
  description = "The password for Synapse SQL"
  type        = string
  sensitive   = true
}

variable "example_password" {
  description = "An example password for demonstration purposes"
  type        = string
  sensitive   = true
}

variable "storage_account_name" {
  description = "The name of the S3 bucket (equivalent to Azure Storage Account)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "quicksight_template_arn" {
  description = "ARN of the QuickSight template"
  type        = string
}

variable "quicksight_dashboard_id" {
  description = "ID of the QuickSight dashboard"
  type        = string
}

variable "quicksight_dashboard_name" {
  description = "Name of the QuickSight dashboard"
  type        = string
}
variable "data_set_arn" {
  description = "ARN of the QuickSight dataset"
  type        = string
}
variable "quicksight_dashboard_version_description" {
  description = "Version description for the QuickSight dashboard"
  type        = string
  default     = "Initial version"
}

variable "redshift_master_username" {
  description = "Master username for Redshift"
  type        = string
}

variable "redshift_master_password" {
  description = "Master password for Redshift"
  type        = string
}

variable "my_ip" {
  description = "Your IP address for SSH access"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR блок VPC"
  type        = string
  default     = "10.0.0.0/16"
}