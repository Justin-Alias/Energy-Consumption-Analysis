-- ============================================================
-- Energy Consumption Analysis — Snowflake Setup Script
-- Project: Tableau Energy Consumption Dashboard
-- ============================================================
 
-- ------------------------------------------------------------
-- STEP 1: Storage Integration (AWS S3)
-- ------------------------------------------------------------
CREATE OR REPLACE STORAGE INTEGRATION tableau_Integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::195335759238:role/tableau.role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://tableau.project1.1/')
  COMMENT = 'S3 integration for Tableau energy dataset';
 
DESC INTEGRATION tableau_Integration;
 
-- ------------------------------------------------------------
-- STEP 2: Database & Schema
-- ------------------------------------------------------------
CREATE DATABASE tableau;
CREATE SCHEMA tableau_Data;
 
-- ------------------------------------------------------------
-- STEP 3: Raw Staging Table
-- ------------------------------------------------------------
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
 
-- ------------------------------------------------------------
-- STEP 4: External Stage (S3)
-- ------------------------------------------------------------
CREATE STAGE tableau.tableau_Data.tableau_stage
  URL = 's3://tableau.project1.1'
  STORAGE_INTEGRATION = tableau_Integration;
 
-- ------------------------------------------------------------
-- STEP 5: Load Data from S3 into Staging Table
-- ------------------------------------------------------------
COPY INTO tableau_dataset
FROM @tableau_stage
FILE_FORMAT = (TYPE = CSV FIELD_DELIMITER = ',' SKIP_HEADER = 1)
ON_ERROR = 'continue';
 
-- ------------------------------------------------------------
-- STEP 6: Create Final Working Table
-- ------------------------------------------------------------
CREATE TABLE energy_consumption AS
  SELECT * FROM tableau_dataset;
 
SELECT * FROM energy_consumption;
 
-- ------------------------------------------------------------
-- STEP 7: Adjust Monthly Usage by Income Level
-- Logic:
--   Low    income → usage × 1.1  (+10%)
--   Middle income → usage × 1.2  (+20%)
--   High   income → usage × 1.3  (+30%)
-- ------------------------------------------------------------
UPDATE energy_consumption
SET monthly_usage_kwh = monthly_usage_kwh * 1.1
WHERE income_level = 'Low';
 
UPDATE energy_consumption
SET monthly_usage_kwh = monthly_usage_kwh * 1.2
WHERE income_level = 'Middle';
 
UPDATE energy_consumption
SET monthly_usage_kwh = monthly_usage_kwh * 1.3
WHERE income_level = 'High';
 
-- ------------------------------------------------------------
-- STEP 8: Adjust Cost Savings by Income Level
-- Logic:
--   Low    income → savings × 0.9  (-10%)
--   Middle income → savings × 0.8  (-20%)
--   High   income → savings × 0.7  (-30%)
-- ------------------------------------------------------------
UPDATE energy_consumption
SET cost_savings_usd = cost_savings_usd * 0.9
WHERE income_level = 'Low';
 
UPDATE energy_consumption
SET cost_savings_usd = cost_savings_usd * 0.8
WHERE income_level = 'Middle';
 
UPDATE energy_consumption
SET cost_savings_usd = cost_savings_usd * 0.7
WHERE income_level = 'High';
 
SELECT * FROM energy_consumption;