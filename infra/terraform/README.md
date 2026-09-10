# Terraform IaC — Sunrise Prepaid Modernization

Beginner-friendly, heavily-commented Terraform for the Green Dot **Sunrise** prepaid
modernization on AWS (FIS). Organized so you can learn Terraform from the ground up:
**modules** are reusable building blocks, **environments** wire them together.

> New to Terraform? Read [`docs/TERRAFORM-PRIMER.md`](docs/TERRAFORM-PRIMER.md) first.

---

## 1. Layout

```
infra/terraform/
├── README.md                  <- you are here
├── versions.tf                <- required Terraform + provider versions (copied per env)
├── providers.tf               <- AWS provider config (copied per env)
├── backend.tf.example         <- remote state (S3 + DynamoDB lock) template
├── docs/
│   └── TERRAFORM-PRIMER.md     <- crash course: what each file/keyword means
├── bootstrap/                 <- one-time: creates the S3 bucket + DynamoDB lock table
│   └── main.tf
├── modules/                   <- reusable building blocks (no hard-coded env values)
│   ├── network/               <- VPC, subnets, NAT, VPC endpoints
│   ├── security/              <- security groups
│   ├── kms/                   <- KMS CMKs (replace TDE)
│   ├── secrets/               <- Secrets Manager
│   ├── iam/                   <- IAM roles/policies
│   ├── sqlserver-ec2-ag/      <- Phase 1: SQL Server Always On AG on EC2 Multi-AZ
│   ├── eks/                   <- app tier (Spring Boot microservices)
│   ├── messaging/             <- Kinesis + SQS (decoupling)
│   ├── settlement/            <- Glue + Lambda + Transfer Family
│   ├── observability/         <- CloudWatch + X-Ray
│   ├── rds-aurora-postgresql/ <- Phase 2a target DB
│   ├── rds-sqlserver/         <- Phase 2b fallback DB
│   ├── dms/                   <- migration: replication instance + endpoints + tasks
│   └── dr/                    <- cross-region DR wiring
└── environments/
    └── dev/                   <- composition that calls the modules for the dev env
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── terraform.tfvars.example
        ├── versions.tf
        ├── providers.tf
        └── Makefile
```

## 2. How Terraform is organized here (the mental model)

- **Module** = a folder of `.tf` files that provisions one capability (e.g., a VPC). It takes
  **inputs** (`variables.tf`) and returns **outputs** (`outputs.tf`). It contains **no**
  environment-specific values.
- **Environment** = a composition (e.g., `environments/dev`) that calls modules with real
  values for that environment, and holds the **remote state**.
- **Remote state** = where Terraform records what it created. Stored in **S3** with a
  **DynamoDB** lock so two people can't apply at once.

## 3. First-time setup

```bash
# 0. Configure AWS creds (profile or env vars) for the target account.

# 1. Bootstrap the state backend ONCE per account (creates S3 bucket + DynamoDB table).
cd infra/terraform/bootstrap
terraform init
terraform apply

# 2. Point an environment at that backend.
cd ../environments/dev
cp ../../backend.tf.example backend.tf   # then edit bucket/table names
cp terraform.tfvars.example terraform.tfvars   # then edit values

# 3. Standard workflow (or use the Makefile targets).
terraform init
terraform plan
terraform apply
```

Or with the Makefile in `environments/dev`:

```bash
make init      # terraform init
make plan      # terraform plan
make apply     # terraform apply
make destroy   # tear down (dev only!)
make fmt       # terraform fmt -recursive
make validate  # terraform validate
```

## 4. Phase mapping

| Phase | Modules |
|-------|---------|
| **Foundation** | `network`, `security`, `kms`, `secrets`, `iam` |
| **Phase 1 (Modernize)** | `sqlserver-ec2-ag`, `eks`, `messaging`, `settlement`, `observability` |
| **Phase 2 (Re-architect)** | `rds-aurora-postgresql`, `rds-sqlserver`, `dms`, `dr` |

## 5. Conventions

- Everything is tagged (`project`, `environment`, `phase`, `managed_by=terraform`).
- No secrets in code — use **Secrets Manager** (`modules/secrets`).
- Encryption on by default — **KMS** CMKs everywhere at rest.
- Multi-AZ by default for HA (99.99% objective).

> ⚠️ These modules are **learning-grade scaffolding**: complete and coherent, with sensible
> defaults, but review sizing, CIDRs, and security before any production apply.
