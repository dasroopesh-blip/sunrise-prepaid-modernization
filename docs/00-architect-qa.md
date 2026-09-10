# Architect Q&A — Three Lenses, Why / What / What-For

For the **Sunrise / FIS Payments Data Platform**, every major design question is answered from
three perspectives:

- 🟦 **Data Architect (DA):** data structure, modeling, storage format, quality, lineage.
- 🟩 **Solution Architect (SA):** concrete AWS services, integration, deployment, cost, ops.
- 🟪 **Enterprise Architect (EA):** business capability fit, standards, governance, strategy, risk.

Each answer covers **Why** (rationale), **What** (the decision), **What-For** (the business/technical outcome).

---

## Q1. How do we ingest millions of payment rows from SQL Server in near-real-time?

### 🟦 Data Architect
- **Why:** Payment records are high-velocity, append-heavy, and time-sensitive (reconciliation, fraud). Batch nightly loads lose freshness and can't feed real-time analytics.
- **What:** Use **Change Data Capture (CDC)** on SQL Server so every INSERT/UPDATE/DELETE becomes an ordered change event keyed by the transaction primary key, preserving `before`/`after` images and operation type.
- **What-For:** Guarantees a complete, ordered, replayable history of every payment mutation — the foundation for accurate downstream models and audit.

### 🟩 Solution Architect
- **Why:** We need a managed, low-source-impact way to capture changes and a scalable bus to absorb bursts.
- **What:** **AWS DMS** (with CDC enabled against SQL Server transaction log) for capture, publishing into **Amazon MSK (managed Kafka)** topics; alternatively **MSK Connect + Debezium SQL Server connector** for log-based CDC directly into Kafka.
- **What-For:** Decouples producers from consumers, absorbs millions of events/sec with buffering + replay, and avoids hand-built polling that hammers the source DB.

### 🟪 Enterprise Architect
- **Why:** Ingestion must align to enterprise data-movement standards, minimize risk to a regulated system-of-record, and be reusable across future FIS domains.
- **What:** Standardize on an **event-streaming ingestion pattern** (CDC → Kafka) as the enterprise-approved integration style for operational data, with clear ownership and SLAs.
- **What-For:** Creates a repeatable "ingest once, consume many" capability that shortens time-to-market for future data products and reduces point-to-point integration sprawl.

---

## Q2. Why Kafka (Amazon MSK) as the ingestion backbone?

### 🟦 Data Architect
- **Why:** Payment streams have variable volume and require ordering per account/transaction and the ability to reprocess history when models change.
- **What:** Kafka topics **partitioned by a payment key** (e.g., `account_id` or `transaction_id` hash) with retention long enough to replay; schema governed by a **Schema Registry** (Avro/Protobuf).
- **What-For:** Preserves per-key ordering, enables backfills/reprocessing, and enforces contract-based schemas so downstream data stays consistent.

### 🟩 Solution Architect
- **Why:** We want managed Kafka to avoid operating brokers, with AWS-native security and scaling.
- **What:** **Amazon MSK** (or MSK Serverless) with IAM/TLS auth, multi-AZ brokers, **MSK Connect** for source/sink connectors, and **Glue Schema Registry** for schema management.
- **What-For:** High-throughput, durable, HA buffer that smooths spikes, decouples SQL Server from Glue/Aurora, and lets each consumer scale independently.

### 🟪 Enterprise Architect
- **Why:** A shared streaming backbone is a strategic capability, not a project-local tool.
- **What:** Position MSK as the **enterprise event backbone** with topic naming standards, data-domain ownership, and a Center-of-Excellence governance model.
- **What-For:** Enables event-driven architecture across the enterprise (payments, fraud, ledger, notifications) and avoids each team standing up its own queue.

---

## Q3. How do we migrate/replicate SQL Server → Aurora PostgreSQL?

### 🟦 Data Architect
- **Why:** SQL Server and PostgreSQL differ in data types, identity columns, collation, and T-SQL vs PL/pgSQL. A naive copy corrupts data or semantics.
- **What:** Do **schema conversion** (types, keys, constraints) then a **full load + ongoing CDC** replication; define type-mapping rules (e.g., `DATETIME2`→`timestamptz`, `MONEY`→`numeric(19,4)`, `UNIQUEIDENTIFIER`→`uuid`).
- **What-For:** A faithful, continuously-synced PostgreSQL copy that preserves financial precision (critical for money) and referential integrity.

### 🟩 Solution Architect
- **Why:** We need managed migration tooling with minimal downtime and cutover safety.
- **What:** **AWS SCT (Schema Conversion Tool)** for DDL/code conversion + **AWS DMS** for full load and CDC into **Amazon Aurora PostgreSQL** (multi-AZ). Validate with DMS data validation.
- **What-For:** Near-zero-downtime migration with rollback capability, and a PostgreSQL operational store that removes SQL Server licensing cost and fits the AWS-native strategy.

### 🟪 Enterprise Architect
- **Why:** Migrating a system-of-record is high-risk and must satisfy compliance, resilience, and TCO goals.
- **What:** Approve **Aurora PostgreSQL** as the strategic OLTP standard, mandate parallel-run validation, data reconciliation sign-off, and a documented cutover/rollback runbook.
- **What-For:** Reduces licensing/vendor lock-in, improves resiliency (Aurora multi-AZ), and satisfies audit/regulatory requirements for controlled migration of financial data.

---

## Q4. Why AWS Glue + PySpark for transformation?

### 🟦 Data Architect
- **Why:** Transformations (cleansing, deduplication, currency normalization, enrichment, SCD handling) operate over large volumes and evolving schemas.
- **What:** Author **PySpark** transforms implementing the **medallion pattern** (Bronze→Silver→Gold): parse/validate in Bronze, conform/dedupe in Silver, aggregate/model in Gold.
- **What-For:** Distributed, testable transformation logic that scales with volume and produces clean, conformed, analytics-ready payment data.

### 🟩 Solution Architect
- **Why:** We want serverless Spark to avoid managing clusters, with both streaming and batch modes.
- **What:** **AWS Glue** jobs — **Glue Streaming** (reads MSK) for near-real-time Silver, **Glue batch ETL** for Gold aggregates; Glue Data Catalog as the metastore; jobs orchestrated by **Glue Workflows / Step Functions**.
- **What-For:** Pay-per-use Spark that auto-scales, integrates natively with S3/Iceberg/MSK/Catalog, and cuts operational overhead versus self-managed EMR.

### 🟪 Enterprise Architect
- **Why:** Transformation tooling should be standardized, cost-governed, and skills-sustainable.
- **What:** Endorse **Glue/PySpark** as the enterprise transformation standard with reusable libraries, CI/CD for jobs, and cost guardrails (worker limits, budgets).
- **What-For:** Consistent engineering practice, portable Spark skills, and predictable cost across all data-domain teams.

---

## Q5. Why Apache Iceberg as the table format?

### 🟦 Data Architect
- **Why:** Payments data needs **upserts/deletes** (CDC corrections, late-arriving data), **schema evolution**, and **time travel** for audit — things raw Parquet + Hive partitions can't do safely.
- **What:** Store Silver/Gold as **Apache Iceberg** tables on S3 with `MERGE INTO` for CDC upserts, hidden partitioning (e.g., by `payment_date`), and snapshot-based time travel.
- **What-For:** ACID guarantees, correct handling of updates/deletes, safe schema changes, and point-in-time reproducibility for reconciliation and audit.

### 🟩 Solution Architect
- **Why:** We want an open table format that works across Glue, Athena, EMR, and Redshift Spectrum without lock-in.
- **What:** **Iceberg on S3**, registered in **Glue Data Catalog**, queried by **Athena (engine v3)** and Spark; compaction + snapshot expiration jobs for maintenance.
- **What-For:** One copy of data, many engines; serverless SQL access; and controlled storage cost via compaction and retention.

### 🟪 Enterprise Architect
- **Why:** Open standards reduce lock-in and align with a long-term lakehouse strategy.
- **What:** Adopt **Iceberg** as the enterprise lakehouse table-format standard, with governance via Lake Formation.
- **What-For:** Future-proof, vendor-neutral data platform that any current or future engine can read, protecting the data investment.

---

## Q6. How do we design the data models out of payment data?

### 🟦 Data Architect
- **Why:** Raw payment events aren't usable for reporting/fraud/regulatory needs without conformed dimensions and facts.
- **What:** Build a **dimensional model (star schema)** in Gold: `fact_payment_transaction` (grain = one payment event) with `dim_account`, `dim_customer`, `dim_merchant`, `dim_currency`, `dim_date`, plus **SCD Type-2** for changing attributes; also a reconciliation/aggregate mart.
- **What-For:** Fast, intuitive analytics; consistent KPIs (settled volume, decline rate, chargebacks); and a single version of truth for finance and risk.

### 🟩 Solution Architect
- **Why:** Models must be queryable and servable to BI and applications efficiently.
- **What:** Gold Iceberg tables exposed via **Athena** for BI (**QuickSight**), and curated aggregates pushed to **Aurora PostgreSQL** for low-latency app/API serving.
- **What-For:** Right storage for right workload — lake for analytics, Postgres for operational/API reads — without duplicating transformation logic.

### 🟪 Enterprise Architect
- **Why:** Data models are shared business assets that must map to enterprise business capabilities and definitions.
- **What:** Govern models against an **enterprise data model / business glossary** (canonical definitions of "payment", "settlement", "chargeback") and publish them as **data products** in a data-mesh/marketplace.
- **What-For:** Cross-domain consistency, reuse, discoverability, and alignment of data to business capabilities and regulatory reporting.

---

## Q7. How do we secure the platform (PCI / financial data)?

### 🟦 Data Architect
- **Why:** Payment data includes sensitive/PII and PCI-scope fields (PAN, account numbers).
- **What:** **Tokenize/mask PAN** at ingestion, classify columns, and store only what's needed; apply **column/row-level security** in the catalog.
- **What-For:** Minimizes PCI scope, protects cardholder data, and enforces least-privilege access at the data level.

### 🟩 Solution Architect
- **Why:** Controls must be enforced by AWS services end-to-end.
- **What:** **KMS** encryption at rest (S3, Aurora, MSK), TLS in transit, **Lake Formation** fine-grained access, **IAM** least-privilege roles, VPC isolation, **Secrets Manager** for credentials, CloudTrail + GuardDuty for monitoring.
- **What-For:** Defense-in-depth that satisfies PCI-DSS technical controls and provides auditable, centrally-governed access.

### 🟪 Enterprise Architect
- **Why:** Security must satisfy regulators, corporate policy, and risk appetite.
- **What:** Map controls to **PCI-DSS, SOX, GDPR/CCPA**; define data-classification and retention policies; require security sign-off and periodic audit.
- **What-For:** Regulatory compliance, reduced breach/fine risk, and demonstrable governance to auditors and the board.

---

## Q8. How do we handle scale, reliability, and cost?

### 🟦 Data Architect
- **Why:** Volume grows; skew and small files degrade performance; storage cost compounds.
- **What:** Partition Iceberg tables sensibly, run **compaction + snapshot expiration**, tier cold data to S3 Glacier, and design idempotent, replayable transforms.
- **What-For:** Sustained query performance and controlled storage cost as data grows into billions of rows.

### 🟩 Solution Architect
- **Why:** Managed, elastic services let us scale without ops burden and pay for use.
- **What:** MSK multi-AZ + auto-scaling storage, Glue auto-scaling workers, Aurora auto-scaling replicas, S3 for infinite storage; monitor with CloudWatch, alarm on lag/DLQ; **DLQs** for bad records.
- **What-For:** Elastic throughput, high availability (multi-AZ), graceful failure handling, and predictable, usage-based cost.

### 🟪 Enterprise Architect
- **Why:** Reliability and cost are enterprise NFRs tied to SLAs and budgets.
- **What:** Define **SLAs/SLOs** (freshness, availability), **DR strategy** (cross-region), **FinOps** tagging/budgets, and a capacity/cost review cadence.
- **What-For:** Predictable service levels, business-continuity assurance, and cost accountability across the portfolio.

---

## Q9. How do we orchestrate, monitor, and ensure data quality?

### 🟦 Data Architect
- **Why:** Pipelines have dependencies; bad data must be caught before it reaches models.
- **What:** **Data-quality checks** (row counts, null/format rules, referential checks, financial totals reconciliation) via **Glue Data Quality** / Deequ; quarantine failures.
- **What-For:** Trustworthy data, early failure detection, and reconciled financial totals.

### 🟩 Solution Architect
- **Why:** Orchestration and observability must be automated and alertable.
- **What:** **Step Functions / Glue Workflows / MWAA (Airflow)** for orchestration; **CloudWatch dashboards + alarms**, lineage via Glue/OpenLineage.
- **What-For:** Reliable, observable, self-healing pipelines with clear ops runbooks.

### 🟪 Enterprise Architect
- **Why:** Quality and lineage are governance mandates for regulated data.
- **What:** Enforce enterprise **data-quality SLAs**, **lineage/audit** standards, and stewardship roles (data owners/stewards).
- **What-For:** Auditable, accountable data supply chain that regulators and business leaders can trust.

---

## Q10. Batch vs. Streaming — which and why?

### 🟦 Data Architect
- **Why:** Different consumers need different freshness — fraud needs seconds, regulatory reports need daily.
- **What:** **Hybrid (Lambda-style):** streaming path (MSK→Glue Streaming→Silver Iceberg) for near-real-time; batch path for heavy Gold aggregates and reconciliation.
- **What-For:** Meets both low-latency and heavy-aggregate needs without over-engineering everything to real-time.

### 🟩 Solution Architect
- **Why:** AWS supports both cheaply within one toolset.
- **What:** Glue Streaming jobs for continuous micro-batches; scheduled Glue batch jobs for Gold; Iceberg unifies the storage layer for both.
- **What-For:** Single storage, dual velocity — simpler than separate stacks, and cost-optimized per workload.

### 🟪 Enterprise Architect
- **Why:** Processing style should match business value and cost, not tech fashion.
- **What:** Set enterprise guidance: real-time only where business value justifies it, batch otherwise.
- **What-For:** Cost-conscious, value-aligned processing decisions across all teams.


---
---

# Part 2 — Sunrise-Specific Questions (Green Dot Prepaid Modernization)

> These questions are grounded in the actual AWS proposal (see
> [`05-project-context.md`](05-project-context.md)). Same three lenses, same why/what/what-for.

---

## Q11. How do we get off SQL Server 2016 before end-of-support (Jul 14, 2026)?

### 🟦 Data Architect
- **Why:** All 68 databases are on the **Simple recovery model** — no HA, no point-in-time recovery — and the platform is on an unsupported engine after July 2026.
- **What:** First move off Simple recovery and stand up **Always On Availability Groups**; inventory schema/procs for the later Aurora re-platform.
- **What-For:** Immediate recoverability + HA, and a clean baseline for the PostgreSQL migration.

### 🟩 Solution Architect
- **Why:** Need a fast, low-behavioral-change lift that also adds HA.
- **What:** **Phase 1:** lift SQL Server to **EC2 Multi-AZ with Always On AG** (auto-failover 10–30s). **Phase 2:** re-platform to **RDS Aurora PostgreSQL** (2a) / **RDS SQL Server** (2b).
- **What-For:** Exits on-prem and the EOL risk quickly, then modernizes to a managed, license-free DB.

### 🟪 Enterprise Architect
- **Why:** EOL is a hard compliance/risk deadline; extended-support costs and unpatched risk are unacceptable.
- **What:** Mandate the **phased plan** with the Phase 1 HA milestone ahead of the EOL date; track via the bi-weekly Steering Committee.
- **What-For:** De-risks the estate against a fixed regulatory/vendor deadline while controlling cost.

---

## Q12. How do we move stored-procedure business logic out of the database?

### 🟦 Data Architect
- **Why:** Logic embedded in SPs tightly couples app and DB, blocks scaling, and prevents a clean PostgreSQL cutover.
- **What:** Inventory + classify every SP by the **7 business purposes**; target a **CRUD-only** data model where the DB just persists state.
- **What-For:** A portable database and a clear boundary between logic (services) and data (tables).

### 🟩 Solution Architect
- **Why:** The strategic target is microservices, not another SQL dialect.
- **What:** **Extract logic into Java/Spring Boot services on EKS** (multi-AZ autoscaling); analytical/settlement logic → **Glue Spark**; **SOAP .NET → REST**; drop pure data-movement procs (DMS + service CRUD).
- **What-For:** Horizontal scale, testability/CI, and a DB reduced to CRUD so Aurora migration is clean.

### 🟪 Enterprise Architect
- **Why:** SP extraction is the Phase 2 critical path and the biggest risk/effort item.
- **What:** Govern it as a **per-purpose migration slice** with parity testing and financial reconciliation sign-off; allow **RDS SQL Server (2b)** for not-ready slices so nothing blocks the program.
- **What-For:** Predictable, de-risked delivery of the highest-value modernization outcome.

---

## Q13. How do we reach 99.99% availability (from 99.95%)?

### 🟦 Data Architect
- **Why:** Simple recovery + single-active DB = no real HA today.
- **What:** **Always On AG** (Phase 1) then **Aurora Multi-AZ** (Phase 2); continuous backups + point-in-time recovery.
- **What-For:** Sub-minute failover and recoverable data — the DB foundation for 99.99%.

### 🟩 Solution Architect
- **Why:** Availability is an end-to-end property (app + DB + DR).
- **What:** **EKS multi-AZ autoscaling** for the app, **AG/Aurora Multi-AZ** for data, **multi-region active-warm DR**, failover orchestration, **chaos engineering** to validate.
- **What-For:** Measured, tested 99.99% across the whole stack, not just the DB.

### 🟪 Enterprise Architect
- **Why:** 99.99% is a business SLO with financial/reputational stakes for a payments platform.
- **What:** Define the **SLO, DR RTO/RPO, and validation cadence**; require chaos-test evidence at Steering Committee.
- **What-For:** Auditable, contractually-defensible availability commitment.

---

## Q14. How do we retire the 1,771-article bi-directional replication safely?

### 🟦 Data Architect
- **Why:** A 1,771-article bi-directional mesh across 7 purposes is fragile, hard to reason about, and a migration hazard.
- **What:** Map articles → 7 purposes; retire each purpose's articles **only after** its logic moves to a service; never recreate the mesh on AWS.
- **What-For:** Incremental de-risking with a clear, purpose-by-purpose exit.

### 🟩 Solution Architect
- **Why:** HA must not depend on replication anymore.
- **What:** Replace the replication *HA role* with **Always On AG** in Phase 1; Aurora Multi-AZ + cross-region in Phase 2 needs no bi-directional mesh.
- **What-For:** Native, managed HA/DR without the operational burden of custom replication.

### 🟪 Enterprise Architect
- **Why:** Decommissioning a core replication topology touches all 7 business capabilities.
- **What:** Sequence retirement as governed slices with rollback to the AG cluster; track dependencies.
- **What-For:** Controlled removal of a systemic risk without business disruption.

---

## Q15. How do we modernize Settlement specifically?

### 🟦 Data Architect
- **Why:** Settlement is batch-heavy and currently slow; it must handle 30% YoY growth.
- **What:** Model settlement as **parallelizable partitions** (by network/day/batch) processed with Spark; reconcile totals exactly.
- **What-For:** Settlement processing time cut ~half with correct, reconciled outputs.

### 🟩 Solution Architect
- **Why:** Serverless parallelism beats a monolithic batch job.
- **What:** **AWS Glue Spark** for parallel settlement, **Lambda** for event steps, **Transfer Family** for secure file exchange with networks/partners; **Kinesis/SQS** to decouple.
- **What-For:** Faster, elastic, decoupled settlement with a **Settlement Ops UI** and runbooks for operability.

### 🟪 Enterprise Architect
- **Why:** Settlement is a revenue-critical capability with SLAs and partner obligations.
- **What:** Treat settlement modernization as a flagship Phase 1 outcome with explicit performance SLOs and reconciliation controls.
- **What-For:** Demonstrable early business value (halved settlement time) that funds and de-risks the rest of the program.

---

## Q16. How do we introduce DevOps and eliminate ~1-day/server manual deployments?

### 🟦 Data Architect
- **Why:** Manual DB changes are error-prone and unversioned.
- **What:** Version schema/migrations (e.g., Flyway/Liquibase) in the pipeline; treat DB changes as code.
- **What-For:** Repeatable, auditable database changes.

### 🟩 Solution Architect
- **Why:** Manual, day-long deploys don't scale and hurt availability.
- **What:** **CI/CD (CodePipeline)**, **IaC with Terraform**, **Image Builder** for AMIs, automated tests, **chaos engineering**; capacity validation automated.
- **What-For:** Minutes-not-days deployments, consistent environments, and safer releases.

### 🟪 Enterprise Architect
- **Why:** DevOps maturity is an enterprise standard tied to reliability and cost.
- **What:** Adopt the existing **AWS/FIS delivery model** — two-week sprints, demos, bi-weekly Steering Committee — with IaC/CI-CD as mandated practice.
- **What-For:** Sustainable delivery velocity and governance across the portfolio.
