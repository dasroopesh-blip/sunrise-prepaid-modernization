# Terraform Primer (read this first if you're new to Terraform)

A quick crash course tailored to this repo. Terraform lets you describe cloud
infrastructure as **code** (declaratively), then creates/updates it to match.

## Core idea

You write **what you want** (e.g., "a VPC with 3 private subnets"). Terraform figures out
**how** to make reality match, and records what it did in **state**.

```
Your .tf files  ->  terraform plan  ->  terraform apply  ->  AWS resources
                     (preview diff)      (make it real)       (+ state file)
```

## The files you'll see in every module

| File | What it holds |
|------|---------------|
| `main.tf` | The actual resources (the "what to build"). |
| `variables.tf` | **Inputs** — knobs the caller can set (with types, defaults, descriptions). |
| `outputs.tf` | **Outputs** — values this module returns (e.g., the VPC id) for others to use. |
| `versions.tf` | Required Terraform + provider versions. |

## Key keywords

- **`resource`** — one real thing to create, e.g. `resource "aws_vpc" "this" { ... }`.
  - First string = resource type (`aws_vpc`), second = local name (`this`).
- **`variable`** — an input. Reference it as `var.name`.
- **`output`** — a value to expose. Reference another module's output as `module.x.name`.
- **`module`** — reuse a folder of resources. You pass inputs and read outputs.
- **`data`** — read something that already exists (e.g., available AZs) without creating it.
- **`locals`** — computed convenience values used within a file.
- **`for_each` / `count`** — create many similar resources from a map/number.

## How a module is called (from an environment)

```hcl
module "network" {
  source     = "../../modules/network"  # path to the reusable module
  project    = var.project
  environment = var.environment
  vpc_cidr   = "10.20.0.0/16"
  az_count   = 3
}

# Later, use its output:
#   module.network.private_subnet_ids
```

## The everyday workflow

```bash
terraform init      # download providers, configure backend  (run once / when providers change)
terraform fmt       # auto-format your code
terraform validate  # check syntax & references
terraform plan      # PREVIEW what will change (no changes made)
terraform apply     # make the changes (asks for confirmation)
terraform destroy   # remove everything this state manages (careful!)
```

## State — the one thing beginners must respect

Terraform stores a **state file** mapping your code to real AWS resource IDs. We keep it in
**S3** (shared, versioned) with a **DynamoDB lock** (prevents concurrent applies). Never edit
state by hand; never commit it to git.

## Reading order for this repo

1. `bootstrap/` — creates the S3 bucket + DynamoDB table for state (run once per account).
2. `modules/network` — the simplest module; good to read first.
3. `environments/dev/main.tf` — see how all modules are wired together.
