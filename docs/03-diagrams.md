# Design & Process Diagrams — Sunrise / FIS Payments Data Platform

All diagrams are **Mermaid** and render on GitHub. This is the visual companion to the HLD/LLD.

---

## 1. End-to-End Data Flow (Context)

```mermaid
flowchart LR
    CUST([Customers\nApple Pay]) --> APP[FIS Apple Pay\nPayment Product]
    APP --> SQL[(SQL Server\nOLTP + Stored Procs)]
    SQL -->|CDC| DMS[AWS DMS]
    DMS --> MSK[[Amazon MSK]]
    DMS --> AUR[(Aurora PostgreSQL)]
    MSK --> GLUE[Glue / PySpark]
    GLUE --> ICE[(Iceberg Lakehouse\nS3)]
    ICE --> ATH[Athena]
    ATH --> BI[QuickSight / Fraud / Reg Reporting]
    AUR --> API[Payment APIs]
```

---

## 2. CDC Migration Flow (SQL Server → Aurora + Lake)

```mermaid
flowchart TB
    subgraph Source
        LOG[SQL Server\nTransaction Log]
    end
    LOG --> DMS[DMS Replication Instance]
    DMS -->|full load| INIT[Initial snapshot]
    DMS -->|ongoing CDC| CHG[Change stream]
    INIT --> AUR[(Aurora PostgreSQL)]
    CHG --> AUR
    CHG --> KAFKA[[MSK topic\npayments.transactions.cdc]]
    KAFKA --> BRONZE[(Bronze / Raw)]
    KAFKA --> SILVER[(Silver / Merged)]
    DMS -.validation.-> VAL[Row-count &\ndata validation]
```

---

## 3. Medallion Architecture (Bronze → Silver → Gold)

```mermaid
flowchart LR
    subgraph Bronze["🥉 Bronze — Raw / Immutable"]
        B[Raw CDC events\nas-received]
    end
    subgraph Silver["🥈 Silver — Conformed"]
        S[Deduped, validated,\ncurrent-state MERGE]
    end
    subgraph Gold["🥇 Gold — Modeled"]
        G1[Star schema\nfacts + dims]
        G2[Reconciliation\naggregates]
    end
    B -->|clean + dedupe| S
    S -->|dimensional model| G1
    S -->|aggregate| G2
    G1 --> CONSUME[BI / ML / Reg]
    G2 --> CONSUME
```

---

## 4. Streaming Ingestion Sequence

```mermaid
sequenceDiagram
    participant SQL as SQL Server
    participant DMS as AWS DMS
    participant MSK as Amazon MSK
    participant GS as Glue Streaming
    participant ICE as Silver Iceberg
    participant DQ as Data Quality

    SQL->>DMS: Transaction log change (INSERT/UPDATE/DELETE)
    DMS->>MSK: Publish change event (keyed by transaction_id)
    GS->>MSK: Poll micro-batch
    GS->>GS: Dedupe (latest per key)
    GS->>ICE: MERGE INTO (upsert/delete)
    GS->>DQ: Validate batch
    alt DQ pass
        DQ-->>ICE: commit snapshot
    else DQ fail
        DQ-->>MSK: route to DLQ + alarm
    end
```

---

## 5. Batch Gold Build Sequence

```mermaid
sequenceDiagram
    participant EB as EventBridge
    participant SF as Step Functions
    participant GB as Glue Batch (PySpark)
    participant SIL as Silver Iceberg
    participant GLD as Gold Iceberg
    participant AUR as Aurora

    EB->>SF: Hourly trigger
    SF->>GB: Run gold_dimensional
    GB->>SIL: Read conformed data
    GB->>GLD: Write facts + SCD2 dims
    GB->>GB: Data quality checks
    alt pass
        GB->>AUR: Publish curated aggregates
    else fail
        GB->>SF: Raise -> SNS alert + quarantine
    end
```

---

## 6. Stored-Procedure Migration Decision Tree

```mermaid
flowchart TD
    START[Inventory each\nstored procedure] --> Q1{Data-movement\nonly?}
    Q1 -->|Yes| DMS[Replace with DMS\n+ Glue transform]
    Q1 -->|No| Q2{Complex business\nlogic?}
    Q2 -->|Analytical / ETL| SPARK[Re-platform to\nPySpark / Glue]
    Q2 -->|Transactional / OLTP| Q3{Rewrite feasible?}
    Q3 -->|Yes| PLPG[Convert T-SQL\n-> PL/pgSQL]
    Q3 -->|Low effort / compat| BABEL[AWS Babelfish\nfor Aurora PG]
    Q3 -->|Belongs in app| APPTIER[Move logic to\napplication / API tier]
    DMS --> VALIDATE[Validate + reconcile]
    SPARK --> VALIDATE
    PLPG --> VALIDATE
    BABEL --> VALIDATE
    APPTIER --> VALIDATE
```

---

## 7. Design Process (How the Architecture Was Produced)

```mermaid
flowchart LR
    R[1. Requirements\n& constraints] --> C[2. Current-state\nassessment]
    C --> O[3. Options &\ntrade-offs]
    O --> HLD[4. High-Level\nDesign]
    HLD --> LLD[5. Low-Level\nDesign]
    LLD --> POC[6. PoC / spike\nrisky areas]
    POC --> IAC[7. IaC\nTerraform modules]
    IAC --> MIG[8. Migrate &\nvalidate]
    MIG --> CUT[9. Cutover &\nrun]
    CUT --> OPT[10. Optimize\n& govern]
```

---

## 8. Deployment / Environments (Terraform)

```mermaid
flowchart TB
    subgraph Repo["Terraform Repo"]
        NET[module: network]
        MSKm[module: msk]
        DMSm[module: dms]
        GLUEm[module: glue]
        S3m[module: s3-lakehouse]
        AURm[module: aurora]
        LFm[module: lakeformation]
        IAMm[module: iam]
    end
    Repo --> DEV[(dev account)]
    DEV --> STG[(staging account)]
    STG --> PROD[(prod account)]
    STATE[(S3 remote state\n+ DynamoDB lock)] --- Repo
```

---

## 9. Security / Compliance Overlay

```mermaid
flowchart TB
    subgraph Controls
        KMS[KMS encryption\nat rest]
        TLS[TLS in transit]
        LF[Lake Formation\nrow/column security]
        IAM[IAM least privilege]
        TOK[PAN tokenization\nDPAN for Apple Pay]
        SM[Secrets Manager]
        CT[CloudTrail + GuardDuty]
    end
    Controls --> COMPLIANCE[PCI-DSS / SOX /\nGDPR alignment]
```
