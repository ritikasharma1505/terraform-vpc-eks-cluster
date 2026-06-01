# Production-Ready Amazon EKS Cluster on Custom VPC using Terraform

## Project Overview

This project demonstrates the provisioning of a production-style Amazon EKS (Elastic Kubernetes Service) cluster on AWS using Terraform. The infrastructure includes a custom VPC, private worker nodes, private API endpoint access, OIDC integration, IRSA, EBS CSI Driver, and secure cluster access through a jump server using AWS Systems Manager Session Manager.

The project follows Infrastructure as Code (IaC) principles and implements AWS best practices for networking, security, and Kubernetes cluster management.

---

## Architecture

### Infrastructure Components

* Custom VPC
* Public Subnets
* Private Subnets
* Internet Gateway
* NAT Gateway
* Route Tables
* Amazon EKS Cluster
* Managed Node Group
* OIDC Provider
* IAM Roles for Service Accounts (IRSA)
* EBS CSI Driver
* CoreDNS Addon
* kube-proxy Addon
* VPC CNI Addon
* Jump Server
* AWS Systems Manager Session Manager


## Prerequisites

Before starting, ensure the following tools are installed:

* AWS CLI
* Terraform
* kubectl

Verify installations:

```bash
aws --version
terraform --version
kubectl version --client
```

---

# Step 1: Configure AWS CLI

Configure AWS credentials:

```bash
aws configure
```

Provide:

* AWS Access Key
* AWS Secret Access Key
* Region: us-east-2
* Output format: json

Verify:

```bash
aws sts get-caller-identity
```

---

# Step 2: Create Terraform Backend

Create an S3 bucket for remote Terraform state.

```bash
aws s3 mb s3://terraform-state-bucket --region us-east-2
```

Enable versioning:(optional)

```bash
aws s3api put-bucket-versioning \
--bucket terraform-state-bucket \
--versioning-configuration Status=Enabled
```

---

# Step 3: Create Terraform Project Structure

```text
terraform-vpc-eks/
│
├── modules/
│   ├── vpc/
│   └── eks/
│
├── k8s-manifests/
│
├── main.tf
├── provider.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── README.md
```

---

# Step 4: Build Custom VPC Module

Create:

* VPC
* Public Subnet 1
* Public Subnet 2
* Private Subnet 1
* Private Subnet 2
* Internet Gateway
* NAT Gateway
* Route Tables
* Route Table Associations

Configure subnet tags for EKS.

Public Subnets:

```hcl
"kubernetes.io/role/elb" = "1"
```

Private Subnets:

```hcl
"kubernetes.io/role/internal-elb" = "1"
```

Cluster Tag:

```hcl
"kubernetes.io/cluster/eks-prod-cluster" = "shared"
```

---

# Step 5: Create EKS Module

Create:

* EKS Cluster IAM Role
* Node Group IAM Role
* Security Groups
* EKS Cluster
* Managed Node Group

Configure:

```hcl
endpoint_private_access = true
endpoint_public_access  = false
```

This ensures the Kubernetes API server is accessible only from within the VPC.

---

# Step 6: Configure OIDC Provider

Create:

* TLS Certificate Data Source
* OIDC Provider
* IAM Policy Document

Purpose:

Allow Kubernetes service accounts to securely assume AWS IAM roles using IRSA.

---

# Step 7: Configure EBS CSI Driver

Create:

* IAM Role for EBS CSI Driver
* Assume Role Policy
* Policy Attachment
* EBS CSI Addon

Purpose:

Enable dynamic EBS volume provisioning for Kubernetes Persistent Volumes.

---

# Step 8: Install EKS Addons

Deploy:

* CoreDNS
* kube-proxy
* VPC CNI
* EBS CSI Driver

Verify:

```bash
kubectl get pods -n kube-system
```

Expected:

All addon pods should be in Running state.

---

# Step 9: Deploy Infrastructure

Initialize Terraform:

```bash
terraform init
```

Validate:

```bash
terraform validate
```

Review:

```bash
terraform plan
```

Deploy:

```bash
terraform apply
```

---

# Step 10: Create Jump Server

Launch an EC2 instance inside the VPC.

Configure:

* IAM Role with SSM permissions
* Security Group
* Session Manager Access

Purpose:

Secure access to the private EKS API endpoint.

---

# Step 11: Connect Using Session Manager

Navigate:

AWS Console → Systems Manager → Session Manager

Connect to the jump server.

Verify connectivity:

```bash
aws eks update-kubeconfig \
--region us-east-2 \
--name eks-prod-cluster
```

Check cluster:

```bash
kubectl get nodes
```

---

# Step 12: Verify Cluster Health

```bash
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
```

Expected:

Worker nodes should be in Ready state.

---

# Step 13: Deploy Sample Application

Deploy Tetris application:

```bash
kubectl apply -f tetris-deployment.yaml
kubectl apply -f tetris-service.yaml
```

Verify:

```bash
kubectl get pods
kubectl get svc
```

---

# Challenges Faced and Troubleshooting

## EBS CSI Driver CrashLoopBackOff

Issue:

```text
AccessDenied: sts:AssumeRoleWithWebIdentity
```

Root Cause:

Incorrect IRSA trust policy.

Resolution:

Updated service account trust relationship to:

```text
system:serviceaccount:kube-system:ebs-csi-controller-sa
```

---

## Private Endpoint Connectivity

Issue:

kubectl commands timed out outside the VPC.

Resolution:

Used jump server through AWS Session Manager.

---

## Terraform Destroy Failure

Issue:

VPC deletion blocked.

Root Cause:

Orphaned Kubernetes-created ENIs and EKS Security Groups.

Resolution:

Identified dependencies using:

```bash
aws ec2 describe-network-interfaces
aws ec2 describe-security-groups
```

Removed orphaned resources and reran destroy.

---

# Security Best Practices Implemented

* Private EKS Endpoint
* Private Worker Nodes
* OIDC Integration
* IRSA
* SSM-based Access
* No Public SSH Access
* Remote Terraform State in S3

---

# Future Enhancements

* AWS Load Balancer Controller
* Ingress Resources
* Application Load Balancer (ALB)
* GitHub Actions CI/CD
* ArgoCD GitOps
* Monitoring using Prometheus and Grafana

---

# Conclusion

This project demonstrates the deployment of a production-style Amazon EKS cluster using Terraform, implementing AWS networking, Kubernetes security best practices, OIDC, IRSA, and private cluster access through Session Manager.
