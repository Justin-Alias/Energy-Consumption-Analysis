# ⚡ Energy Consumption Analysis

A Tableau analytics project exploring global household energy consumption patterns — built on a cloud data pipeline from AWS S3 → Snowflake → Tableau, with six interactive worksheets analyzing usage and cost savings across countries, regions, and energy sources.

---

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Tools & Technologies](#tools--technologies)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Dataset](#dataset)
- [Snowflake Setup](#snowflake-setup)
  - [Step 1 — Storage Integration (S3)](#step-1--storage-integration-s3)
  - [Step 2 — Database & Schema](#step-2--database--schema)
  - [Step 3 — Staging Table & External Stage](#step-3--staging-table--external-stage)
  - [Step 4 — Load Data](#step-4--load-data)
  - [Step 5 — Transformations](#step-5--transformations)
- [Dashboard Breakdown](#dashboard-breakdown)
- [Key Questions Explored](#key-questions-explored)
- [How to Run This Project](#how-to-run-this-project)

---

## Project Overview

This project analyzes household energy usage and cost savings across different countries, regions, income levels, and energy sources. The data originates in an **AWS S3 bucket**, is loaded and transformed in **Snowflake**, and is visualized live in **Tableau Desktop** — reflecting a real-world cloud analytics pipeline.

Two business adjustments were applied to the data to reflect realistic consumption and savings behaviour by income bracket before visualization.

---

## Tools & Technologies

| Tool | Purpose |
|---|---|
| **AWS S3** | Raw data storage (source bucket) |
| **AWS IAM** | Role-based access control for Snowflake → S3 integration |
| **Snowflake** | Cloud data warehouse — staging, transformation, final table |
| **SQL (Snowflake)** | Data loading, table creation, and business-rule transformations |
| **Tableau Desktop** | Live Snowflake connection and dashboard building |

---

## Project Structure

```
Energy Consumption Analysis/
│
├── Energy_Consumption.twb       # Tableau workbook — live Snowflake connection
└── snowflake_setup.sql          # Full Snowflake setup & transformation script
```

> No local data file — the data lives in Snowflake, loaded from S3, and queried live by Tableau.

---

## Architecture

```
AWS S3 Bucket                Snowflake                        Tableau
(tableau.project1.1)  →   External Stage                        │
                       →   tableau_dataset  (raw)               │
                       →   energy_consumption (transformed)  →  Dashboard
                              ↑
                         Business rules applied
                         (KWH & savings by income level)
```

---

## Dataset

**Final table:** `TABLEAU.TABLEAU_DATA.ENERGY_CONSUMPTION`
**Loaded from:** `s3://tableau.project1.1`

| Column | Type | Description |
|---|---|---|
| `HOUSEHOLD_ID` | string | Unique household identifier |
| `REGION` | string | Geographic region |
| `COUNTRY` | string | Country name |
| `ENERGY_SOURCE` | string | Type of energy (Solar, Gas, Coal, etc.) |
| `MONTHLY_USAGE_KWH` | float | Monthly usage in kWh — **adjusted by income level** |
| `YEAR` | integer | Year of record |
| `HOUSEHOLD_SIZE` | integer | Number of people in the household |
| `INCOME_LEVEL` | string | Low / Middle / High |
| `URBAN_RURAL` | string | Urban or Rural classification |
| `ADOPTION_YEAR` | integer | Year the energy source was adopted |
| `SUBSIDY_RECEIVED` | string | Whether household received an energy subsidy |
| `COST_SAVINGS_USD` | float | Cost savings in USD — **adjusted by income level** |

> ⚠️ `MONTHLY_USAGE_KWH` and `COST_SAVINGS_USD` reflect **post-transformation values** — see the transformation rules below.

---

## Snowflake Setup

The full setup is in `snowflake_setup.sql`. Here is a breakdown of each step:

### Step 1 — Storage Integration (S3)

Establishes a secure, role-based connection between Snowflake and the S3 bucket using an AWS IAM role:

```sql
CREATE OR REPLACE STORAGE INTEGRATION tableau_Integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::195335759238:role/tableau.role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://tableau.project1.1/')
  COMMENT = 'S3 integration for Tableau energy dataset';
```

### Step 2 — Database & Schema

```sql
CREATE DATABASE tableau;
CREATE SCHEMA tableau_Data;
```

### Step 3 — Staging Table & External Stage

Creates the raw landing table and points an external stage at the S3 bucket:

```sql
CREATE TABLE tableau_dataset (
  Household_ID       STRING,
  Region             STRING,
  Country            STRING,
  Energy_Source      STRING,
  Monthly_Usage_kWh  FLOAT,
  Year               INT,
  Household_Size     INT,
  Income_Level       STRING,
  Urban_Rural        STRING,
  Adoption_Year      INT,
  Subsidy_Received   STRING,
  Cost_Savings_USD   FLOAT
);

CREATE STAGE tableau.tableau_Data.tableau_stage
  URL = 's3://tableau.project1.1'
  STORAGE_INTEGRATION = tableau_Integration;
```

### Step 4 — Load Data

Copies the CSV from S3 into the staging table:

```sql
COPY INTO tableau_dataset
FROM @tableau_stage
FILE_FORMAT = (TYPE = CSV FIELD_DELIMITER = ',' SKIP_HEADER = 1)
ON_ERROR = 'continue';
```

Then creates the final working table:

```sql
CREATE TABLE energy_consumption AS
  SELECT * FROM tableau_dataset;
```

### Step 5 — Transformations

Two business-rule adjustments were applied to reflect realistic consumption and savings differences by income level.

#### Monthly Usage Adjustments

| Income Level | Multiplier | Effect |
|---|---|---|
| Low | × 1.1 | +10% usage |
| Middle | × 1.2 | +20% usage |
| High | × 1.3 | +30% usage |

```sql
UPDATE energy_consumption SET monthly_usage_kwh = monthly_usage_kwh * 1.1 WHERE income_level = 'Low';
UPDATE energy_consumption SET monthly_usage_kwh = monthly_usage_kwh * 1.2 WHERE income_level = 'Middle';
UPDATE energy_consumption SET monthly_usage_kwh = monthly_usage_kwh * 1.3 WHERE income_level = 'High';
```

#### Cost Savings Adjustments

| Income Level | Multiplier | Effect |
|---|---|---|
| Low | × 0.9 | −10% savings |
| Middle | × 0.8 | −20% savings |
| High | × 0.7 | −30% savings |

```sql
UPDATE energy_consumption SET cost_savings_usd = cost_savings_usd * 0.9 WHERE income_level = 'Low';
UPDATE energy_consumption SET cost_savings_usd = cost_savings_usd * 0.8 WHERE income_level = 'Middle';
UPDATE energy_consumption SET cost_savings_usd = cost_savings_usd * 0.7 WHERE income_level = 'High';
```

> **Design rationale:** Higher-income households consume more energy (larger homes, more appliances) but realize proportionally less savings — reflecting diminishing returns on energy efficiency investments at higher consumption levels.

---

## Dashboard Breakdown

The **Tableau Dashboard** contains six worksheets organized across two metrics and three geographic dimensions:

### Metrics

| Metric | Description |
|---|---|
| **KWH** | Transformed monthly energy usage in kilowatt-hours |
| **CSU** | Consumption Score Unit — normalized energy index |

### Sheets

| Sheet | Description |
|---|---|
| KWH by Country | Monthly usage ranked by country |
| KWH by Energy Source | Usage split by energy type |
| KWH by Region | Usage aggregated by geographic region |
| CSU by Country | Normalized score by country |
| CSU by Energy Source | Normalized score split by energy type |
| CSU by Region | Normalized score by region |

---

## Key Questions Explored

- Which countries and regions have the highest household energy consumption?
- How does energy usage differ across Low, Middle, and High income households?
- Which energy sources are most prevalent by region?
- What is the relationship between income level and cost savings from energy?
- How does urban vs. rural classification affect consumption patterns?
- Which regions have seen the highest adoption of renewable energy sources?

---

## How to Run This Project

### Prerequisites
- AWS account with access to the S3 bucket `tableau.project1.1`
- Snowflake account with the IAM role `arn:aws:iam::195335759238:role/tableau.role` configured
- Tableau Desktop with the Snowflake connector

### Connection Details

| Parameter | Value |
|---|---|
| Server | `suxejkx-lv18180.snowflakecomputing.com` |
| Warehouse | `COMPUTE_WH` |
| Database | `TABLEAU` |
| Schema | `TABLEAU_DATA` |
| Username | `STUTORIAL` |

### Steps

1. **Run the Snowflake script** — open `snowflake_setup.sql` in Snowsight and run all steps in order
2. **Open the Tableau workbook** — open `Energy_Consumption.twb` in Tableau Desktop
3. **Re-authenticate** — enter your Snowflake credentials when prompted
4. **Explore the dashboard** — all six sheets will query live from `ENERGY_CONSUMPTION`

> **Tip:** Switch to an Extract connection (**Data → Extract Data**) if you want a cached local snapshot and faster load times without hitting Snowflake on every refresh.

---

*Built as part of a Udemy Tableau learning portfolio — demonstrating a full cloud data pipeline: AWS S3 → Snowflake → Tableau.*
