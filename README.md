
# AWS Infrastructure Project

## Project Goal
To create a comprehensive infrastructure in AWS, covering:
1. AWS Fundamentals (CLF-C01).  
2. Infrastructure Design and Management (SAA-C03).  
3. Data Storage, Processing, and Analytics (DAS-C01).  

The project demonstrates skills in deployment, management, and automation in AWS using Terraform.

---

## Project Structure

### 1. Infrastructure Deployment (CLF-C01 + SAA-C03):
- **Creating a Virtual Private Cloud (VPC):**
  - Public subnets for NAT Gateway and Bastion Host.
  - Private subnets for EC2 instances and data storage.
- **Setting up Internet Access:**
  - NAT Gateway for private subnet egress.
  - Internet Gateway for public access.
- **Security Management:**
  - Configuring Security Groups for inbound/outbound traffic filtering.
  - AWS Network ACLs for additional access control.
- **EC2 Instances:**
  - Deploying and configuring virtual machines (EC2).
  - Automating backups with Amazon Backup.
- **Process Automation:**
  - Using Terraform to deploy the entire infrastructure.

---

### 2. Data Storage (DAS-C01 + SAA-C03):
- **Amazon S3:**
  - Creating storage for raw data.
  - Enabling object versioning and automating data lifecycle policies.
- **Amazon S3 Glacier:**
  - Archiving data for long-term storage.
- **Amazon Redshift:**
  - Deploying an analytics data warehouse.
  - Integrating with S3 for data loading.
- **Access Management:**
  - Configuring IAM roles and policies to restrict data access.

---

### 3. ETL Processes and Data Processing (DAS-C01):
- **AWS Glue:**
  - Setting up ETL pipelines for processing data from S3.
  - Cleaning and transforming data before loading it into Redshift.
- **Amazon EMR:**
  - Configuring clusters for processing large datasets using Apache Spark.
- **AWS Lambda:**
  - Automating small ETL processes triggered by S3 events.

---

### 4. Data Analytics and Visualization (DAS-C01):
- **Amazon QuickSight:**
  - Building dashboards to visualize analytical data.
- **Data Integration:**
  - Integrating Redshift with QuickSight for reporting.
- **Real-Time Analytics:**
  - Using Kinesis Data Analytics for real-time stream processing.

---

### 5. Security and Access Management (SAA-C03 + CLF-C01):
- **IAM Policies:**
  - Configuring roles, policies, and user groups for access management.
- **AWS KMS:**
  - Managing data encryption in S3, Redshift, and RDS.
- **CloudTrail and CloudWatch:**
  - Monitoring access and activity in AWS to ensure security compliance.

---

### 6. Monitoring and Backup (SAA-C03):
- **Amazon CloudWatch:**
  - Setting up metrics and alerts for all resources.
- **Amazon Backup:**
  - Configuring regular backups for S3, RDS, and EC2.
- **Logging:**
  - Managing logs using AWS CloudTrail and S3.

---

### 7. Automation (SAA-C03 + DAS-C01 + Terraform):
- **Terraform for AWS:**
  - Deploying all components: VPC, NAT Gateway, EC2, S3, Redshift, Glue.
  - Setting up Terraform modules for infrastructure management.
- **Auto Scaling:**
  - Configuring EC2 Auto Scaling based on load.

---

## Project Outcomes
- A fully deployed AWS infrastructure for networking, storage, and data analytics.
- A functional ETL process with AWS Glue and EMR.
- An analytics data warehouse (Redshift) and visualization in QuickSight.
- Terraform code for automating deployment and management.

---

## How to Use the Project
1. **Setting up the Development Environment:**
   - Install Terraform and AWS CLI.
   - Configure AWS access with an IAM user with administrative privileges.
2. **Deployment Steps:**
   - Start by creating the VPC, then add data storage, ETL, and analytics.
3. **Terraform Commands:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

---

## Certifications Alignment

The project aligns with the following AWS certifications:

1. **AWS Certified Cloud Practitioner (CLF-C01):**
   - Fundamental AWS concepts, including IAM, S3, VPC, and resource management.
   - General knowledge of cloud architecture.

2. **AWS Certified Solutions Architect – Associate (SAA-C03):**
   - VPC architecture design: subnets, NAT Gateway, Internet Gateway.
   - Setting up Auto Scaling, Security Groups, and IAM.
   - Optimizing and securing cloud infrastructure.

3. **AWS Certified Data Analytics – Specialty (DAS-C01):**
   - Setting up ETL pipelines with AWS Glue.
   - Data analytics using Amazon Redshift, Kinesis, and QuickSight.
   - Managing and integrating data storage.

4. **Partial Coverage:**
   - **AWS Certified DevOps Engineer – Professional:**
     - Using Terraform to automate infrastructure deployment.
     - Setting up monitoring with CloudWatch and CloudTrail.
   - **AWS Certified Developer – Associate:**
     - Automating ETL processes with AWS Lambda.
     - Event-driven data processing and real-time integration.

---

This project showcases practical knowledge from the listed certifications, emphasizing readiness to tackle Cloud Engineer-level tasks.
