# Project Context — Green Dot "Prepaid Sunrise" Modernization (FIS + AWS)

> **Source of truth for this repo.** Captured from the AWS proposal slides (current-state
> understanding, modernization strategy, and timeline). All other docs align to this.

---

## 1. What This Project Actually Is

This is **NOT primarily a data-lake / analytics build**. It is an **application + database
modernization program** for the **Green Dot Prepaid "Sunrise" (GD)** platform delivered
through FIS, moving from on-prem SQL Server to AWS with high availability, DevOps, and a
re-architected application tier.

**The core objectives:**
- Get off **SQL Server 2016** before **end of extended support (July 14, 2026)**.
- Raise availability from **99.95% → 99.99%**.
- Eliminate on-prem infrastructure and high SQL Server licensing cost.
- Decouple the tightly-coupled app + DB; move **stored-procedure business logic into an
  application tier** so the database becomes **CRUD-only**.
- Introduce DevOps automation (CI/CD, IaC with **Terraform**, chaos engineering).

---

## 2. Current-State Facts (from "Our Understanding" slide)

| Area | Current State |
|------|---------------|
| **Platform** | Green Dot Prepaid Sunrise (GD), delivered via FIS |
| **Data centers** | On-prem: **Phoenix DC (primary)** + **Little Rock DC (secondary)** |
| **Database** | **SQL Server 2016** — nearing **end of extended support (Jul 14, 2026)** |
| **DB count** | **68 databases**, all on **Simple recovery model** → no HA, no point-in-time recovery |
| **Replication** | Complex **bi-directional** topology — **1,771 articles** serving **7 distinct business purposes** |
| **Availability** | **99.95% SLO today** vs **99.99% desired** |
| **Deployment** | Multiple **manual** processes (~**1 day/server**, no DevOps automation) |
| **Scaling** | Infrastructure sized at **peak capacity**, **manual** scaling |
| **Coupling** | Tightly coupled **application + database** → limited scalability & DR options |
| **Licensing** | High enterprise **SQL Server licensing cost** |
| **OS** | Windows Server 2012 R2 (migrating to 2022); Linux RedHat present |
| **Application** | Existing **Sunrise app is Java / Spring Boot** (thin app — business logic is trapped in SQL Server stored procedures) |
| **Key services** | Authorization, Settlement, Reporting, Card Management |
| **Integrations** | SecurLock (Falcon) & HSM, Alert System (.NET SOAP → REST in Phase 2), CONNEX, card networks |
| **Security tooling** | Opscon, Splunk (internal); network/app/data cyber layers |

**Pain points driving the program:** end-of-support risk, no HA/DR, manual ops, peak-sized
cost, tight coupling limiting scale, and a fragile 1,771-article bi-directional replication mesh.

---

## 3. Target State — Two-Phase Strategy

### Phase 1 — **Modernize** the Sunrise Prepaid platform
Goal: improve performance, reliability, and operations **without** yet re-architecting.

- **Performance:** cut settlement processing time by ~half; support **30% YoY growth**; eliminate DB locking bottlenecks (enable horizontal app scaling).
- **Availability:** **99.99%** via **Always On Availability Groups** automatic failover (10–30s); multi-region **active-warm DR**.
- **Infra:** eliminate on-prem → optimized AWS (**EC2, EKS, MSSQL Server Multi-AZ**).
- **DB tuning:** enable **RCSI** on Gemini, remove reader-writer blocking, consolidate **PV1+PV2**.
- **Settlement modernization:** parallel processing with **Glue Spark, Lambda, Transfer Family**.
- **Decoupling:** **Kinesis** alerts, **SQS**, SecurLock, **EKS reconciliation**.
- **DevOps:** CI/CD pipeline, **IaC with Terraform**, Image Builder pipeline, chaos engineering.
- **Observability:** CloudWatch, X-Ray, Settlement Ops UI, operational runbooks.
- **Security:** **Secrets Manager** for credentials management.

### Phase 2 — **Re-architect** the Sunrise Prepaid platform
Goal: cost savings, DB freedom, future-ready microservices.

- **Stored Procedure migration:** extract SP logic to **application tier (Java / Spring Boot on EKS)**; **database becomes CRUD-only**.
- **API layer modernization:** convert **SOAP .NET → REST** APIs (Windows → Linux).
- **Database optimization:** migrate **EC2 MS SQL Server → RDS Aurora PostgreSQL**.
- **Auto-scaled infra:** **EKS** with **multi-AZ auto-scaling**.
- **Encryption modernization:** **KMS** encryption replacing **TDE**.
- **Outcome:** eliminate Windows/SQL licenses, scale beyond 30% YoY at the app tier, microservices architecture, higher security/availability/resiliency.

---

## 4. Timeline (from the Modernization Timeline slide)

- **Total:** ~**46 weeks / 23 sprints**, two-week sprints.
- **Phase 1:** ~**26 weeks** — Initial Setup, Database Modernization, Application Modernization, Observability, Resiliency/Testing/Support.
- **Phase 2a — Aurora PG:** ~**32 weeks** — Application Re-architecture, Database Modernization, Resiliency/Testing/Support.
- **Phase 2b — RDS SQL Server:** Application Re-architecture, Database Modernization, Resiliency/Testing/Support.
- **Governance:** existing AWS/FIS delivery model — two-week sprints, demos, planning; **bi-weekly Steering Committee**, established escalation/triage protocols.

> Note: Phase 2 shows **two DB targets** — **2a Aurora PostgreSQL** (strategic re-platform)
> and **2b RDS SQL Server** (lift for workloads not yet ready for PostgreSQL). This is a
> pragmatic split: move what's ready to Aurora, park the rest on managed RDS SQL Server.

---

## 5. How the Rest of This Repo Maps to This Context

| Doc | Role in the program |
|-----|---------------------|
| `06-modernization-roadmap.md` | The 46-week phased plan + Gantt |
| `01-hld.md` | Current-state → target-state architecture (EKS app tier, Always On AG, Aurora PG) |
| `02-lld.md` | Component detail (settlement on Glue Spark, Kinesis/SQS decoupling, Aurora schema) |
| `04-migration-strategy.md` | **1,771-article stored-proc extraction to Spring Boot** + SQL Server → Aurora PG |
| `00-architect-qa.md` | DA/SA/EA rationale for every major decision |
| `03-diagrams.md` | Visual companion |

---

## 6. Terminology Reconciliation (earlier draft vs. real scope)

My first-pass docs assumed an Iceberg **lakehouse/analytics** platform. The slides show the
program is **app + DB modernization**. Corrections applied across the repo:

| Earlier assumption | Corrected to real scope |
|--------------------|--------------------------|
| Primary goal = analytics lakehouse | Primary goal = **app + DB modernization, HA/DR, get off SQL 2016** |
| Iceberg medallion is the centerpiece | **Aurora PostgreSQL + EKS Spring Boot app tier** is the centerpiece; Glue Spark is scoped to **Settlement** |
| Generic Kafka ingestion | **Kinesis + SQS** decoupling (Kafka/MSK optional, not stated in slides) |
| Apple Pay assumed as main source | Green Dot **prepaid card** platform (Authorization/Settlement/Reporting/Card Mgmt) |
| DMS as the whole migration | DMS/SCT for data; **stored-proc logic → Spring Boot app tier (DB CRUD-only)** is the real challenge |

> Analytics (Iceberg/Athena) can remain a **future/optional** extension, but is not the
> Phase 1/2 mandate.
