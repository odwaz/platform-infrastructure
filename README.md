# Platform Infrastructure

Terraform modules provisioning the AWS infrastructure for the platform — microservices running on EKS with PostgreSQL, Kafka (Strimzi), CI/CD pipelines, and observability.

## Services Deployed

| Service | Description | Port |
|---------|-------------|------|
| **reactive-wallet** | OAuth2 merchant wallet & payments API | 8000 |
| **real-time-cdp** | Event-driven Customer Data Platform (Kafka) | 8080 |
| **sme-directory** | SME trust & discovery platform | 8080 |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  AWS Account                                                     │
│                                                                   │
│  ┌─────────────┐    ┌──────────────────────────────────────────┐ │
│  │ Route 53    │───▶│  ALB (HTTPS, ACM cert)                   │ │
│  └─────────────┘    └────────────────┬─────────────────────────┘ │
│                                      │                            │
│  ┌───────────────────────────────────▼────────────────────────┐  │
│  │  EKS Cluster                                                │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │  │
│  │  │ wallet-api   │ │ cdp-engine   │ │ sme-directory│       │  │
│  │  │ (Fargate)    │ │ (Fargate)    │ │ (Fargate)    │       │  │
│  │  └──────────────┘ └──────────────┘ └──────────────┘       │  │
│  │  ┌──────────────────────────────────────────────────┐      │  │
│  │  │ Kafka (Strimzi operator)                          │      │  │
│  │  │ 3 brokers, KRaft mode                            │      │  │
│  │  └──────────────────────────────────────────────────┘      │  │
│  │  ┌──────────────────────────────────────────────────┐      │  │
│  │  │ Prometheus + Grafana (kube-prometheus-stack)       │      │  │
│  │  └──────────────────────────────────────────────────┘      │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │ RDS PostgreSQL   │  │ ECR (3 repos)    │  │ S3 (artifacts)│  │
│  │ Multi-AZ         │  │                  │  │               │  │
│  └──────────────────┘  └──────────────────┘  └───────────────┘  │
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐                     │
│  │ CodePipeline     │  │ CloudWatch Logs  │                     │
│  │ (per service)    │  │                  │                     │
│  └──────────────────┘  └──────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

## Module Structure

```
.
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
├── modules/
│   ├── networking/        # VPC, subnets, NAT, security groups
│   ├── eks/               # EKS cluster + Fargate profiles
│   ├── rds/               # PostgreSQL Multi-AZ
│   ├── ecr/               # Container registries
│   ├── kafka/             # Strimzi operator + cluster via Helm
│   ├── monitoring/        # kube-prometheus-stack via Helm
│   ├── pipeline/          # CodePipeline + CodeBuild per service
│   └── dns/               # Route 53 + ACM certificates
├── .gitignore
├── backend.tf
├── providers.tf
└── README.md
```

## Usage

```bash
# Initialise (one-time)
cd environments/dev
terraform init

# Plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Destroy (careful)
terraform destroy
```

## State Management

State is stored in S3 with DynamoDB locking:
- **Bucket:** `platform-terraform-state-{account_id}`
- **Lock table:** `platform-terraform-locks`
- **Key:** `environments/{env}/terraform.tfstate`

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.5
- kubectl
- Helm 3

## Environments

| Environment | Purpose | EKS Node Type | RDS Instance |
|-------------|---------|---------------|--------------|
| dev | Development & testing | Fargate | db.t3.micro |
| prod | Production | Fargate | db.r6g.large |

## Adding an application

Each application gets an isolated stack per environment from `modules/app-stack`: its own VPC, EKS cluster,
optional PostgreSQL on RDS, one ECR repository per image (immutable tags) and an IAM role its CI pushes images with.
A project holds only that application's settings:

```hcl
# projects/<app>/<env>/main.tf
module "app" {
  source = "git::https://github.com/odwaz/platform-infrastructure.git//modules/app-stack?ref=app-stack-v1.0.0"

  name                = "<app>-<env>"
  cidr                = "10.60.0.0/16"   # a /16 no other project uses
  api_allowed_cidrs   = var.api_allowed_cidrs
  admin_principal_arn = var.admin_principal_arn
  github_repo         = "<owner>/<app>"
  images              = ["api", "web"]
  database            = { db_name = "<app>", username = "<app>" }   # or leave out for none
  db_password         = var.db_password
}
```

1. Copy an existing project's `versions.tf`, `providers.tf`, `variables.tf` and `outputs.tf`, and set the workspace
   name in `versions.tf` and the tags in `providers.tf`.
2. Add the workspace name to `local.workspaces` in `account/main.tf` and apply `account`, which creates its
   Terraform Cloud role.
3. Create the workspace in Terraform Cloud with working directory `projects/<app>/<env>`, the variables
   `TFC_AWS_PROVIDER_AUTH=true` and `TFC_AWS_RUN_ROLE_ARN`, and the stack's Terraform variables.
4. Plan and apply, then `kubectl apply -f modules/app-stack/cluster/storageclass-gp3.yaml` on the new cluster.

`app-stack` references the other modules by relative path, so one `app-stack-vX.Y.Z` tag pins the whole stack.
