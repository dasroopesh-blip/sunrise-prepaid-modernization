# Helm Chart — `sunrise-services`

Deploys the Green Dot Sunrise prepaid **Java/Spring Boot microservices** onto the EKS cluster
provisioned by `infra/terraform` (module `eks`). One chart deploys all four services from a
single `values.yaml` `services:` map — each gets a **Deployment**, **Service**, **HPA**, and a
shared **Ingress** path.

This is the **app tier that absorbs the extracted stored-proc logic** (Phase 2). The database
is CRUD-only; all business logic runs here.

## Services

| Service | Path | Purpose |
|---------|------|---------|
| `authorization`    | `/api/authorization` | Card authorization |
| `settlement`       | `/api/settlement`    | Settlement posting |
| `reporting`        | `/api/reporting`     | Reporting |
| `card-management`  | `/api/cards`         | Card management |

## Prerequisites

- EKS cluster reachable (`aws eks update-kubeconfig --name <cluster>`).
- **AWS Load Balancer Controller** installed (for the ALB Ingress).
- A Kubernetes Secret named `sunrise-aurora-credentials` (keys: `username`, `password`)
  **synced from AWS Secrets Manager** — use the **Secrets Store CSI Driver** or **External
  Secrets Operator** so the raw password never lives in git or values.
- Metrics Server installed (for HPA).
- Container images pushed to the registry set in `global.imageRegistry`.

## Install

```bash
# Lint + preview
helm lint ./sunrise-services
helm template sunrise ./sunrise-services -f ./sunrise-services/values-dev.yaml

# Dev
helm upgrade --install sunrise ./sunrise-services \
  -n sunrise --create-namespace \
  -f ./sunrise-services/values-dev.yaml

# Prod
helm upgrade --install sunrise ./sunrise-services \
  -n sunrise --create-namespace \
  -f ./sunrise-services/values-prod.yaml
```

## How it maps to the design

- **Health probes** hit Spring Boot Actuator (`/actuator/health/liveness`,
  `/actuator/health/readiness`, `/actuator/health`) — matching the DR health check in the
  Terraform `dr` module.
- **HPA** delivers the "scale beyond 30% YoY / no manual scaling" goal at the app tier.
- **DB credentials** are injected from a Secrets-Manager-synced K8s Secret via `secretKeyRef`
  (never hard-coded), matching the "Secrets Manager for credentials" Phase 1 deliverable.
- **Ingress** uses the ALB, aligning with the EKS + ALB target-state architecture.

## Customizing

Add or remove a service by editing the `services:` map in `values.yaml` — the templates loop
over it, so no template changes are needed. Override anything per environment with
`values-dev.yaml` / `values-prod.yaml` (create `values-staging.yaml` similarly).

> Validation note: `helm lint`/`template` require Helm locally; this repo was authored in an
> environment without Helm, so YAML validity and template delimiter/`range`/`end` balance were
> checked manually. Run `helm lint` before deploying.
