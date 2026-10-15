-- Infrastructure Project Financial Analytics
-- Source: exported Databricks notebook.
-- Execution notes:
-- 1) Run these scripts in order in the same Databricks SQL environment.
-- 2) TEMP VIEW objects are session-scoped; persistent Gold tables are created in 03_data_model.sql.
-- 3) The sample data and reference date are illustrative project data.

-- ============================================================
-- 01. DIMENSION VIEWS
-- ============================================================
CREATE OR REPLACE TEMP VIEW dim_project AS
SELECT
    r.project_id,
    r.project_name,
    c.contractor_id
FROM projects_raw r
LEFT JOIN project_contractors_raw c
    ON r.project_id = c.project_id;

SELECT * FROM dim_project

CREATE OR REPLACE TEMP VIEW dim_contractor AS
SELECT
    contractor_id,
    contractor_name,
    contractor_type
FROM contractors_raw;

SELECT * FROM dim_contractor

CREATE OR REPLACE TEMP VIEW dim_date AS

WITH calendar AS (
    SELECT 
    EXPLODE(
        SEQUENCE(
            DATE('2026-01-01'),
            DATE('2026-12-31'),
            INTERVAL 1 DAY
        )
    ) AS date
)

SELECT
    date,
    YEAR (date) AS year,
    QUARTER (date) AS quarter,
    MONTH (date) AS month_number,
    MONTHNAME (date) AS month_name,
    DATE_FORMAT(date, 'yyyy-MM') AS year_month
FROM calendar;

SELECT * FROM dim_date

-- ============================================================
-- 02. FACT VIEWS
-- ============================================================
CREATE OR REPLACE TEMP VIEW fact_expenses AS
SELECT
    expense_id,
    project_id,
    expense_date,
    category,
    amount
FROM clean_expenses;

SELECT * FROM fact_expenses

CREATE OR REPLACE TEMP VIEW fact_project_performance AS
SELECT
    project_id,
    budget,
    actual_cost,
    remaining_budget,
    budget_utilization_pct,
    planned_end_date,
    days_to_deadline,
    status,
    schedule_status
FROM projects_performance_clean;

SELECT * FROM fact_project_performance

-- ============================================================
-- 03. GRAIN / KEY VALIDATION
-- ============================================================
SELECT
    'fact_expenses' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT expense_id) AS distinct_keys
FROM fact_expenses

UNION ALL

SELECT
    'fact_project_performance' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT project_id) AS distinct_keys
FROM fact_project_performance;

SELECT
    'dim_project' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT project_id) AS distinct_keys
FROM dim_project

UNION ALL

SELECT
    'dim_contractor',
    COUNT(*),
    COUNT(DISTINCT contractor_id)
FROM dim_contractor

UNION ALL

SELECT
    'dim_date',
    COUNT(*),
    COUNT(DISTINCT date)
FROM dim_date;

-- ============================================================
-- 04. CREATE SCHEMA AND PERSIST GOLD TABLES
-- ============================================================
-- The original notebook uses the workspace catalog and creates this schema.
CREATE SCHEMA IF NOT EXISTS workspace.infrastructure_analytics;

CREATE OR REPLACE TABLE workspace.infrastructure_analytics.dim_project
USING DELTA
AS
SELECT *
FROM dim_project;

CREATE OR REPLACE TABLE workspace.infrastructure_analytics.dim_contractor
USING DELTA
AS
SELECT *
FROM dim_contractor;

CREATE OR REPLACE TABLE workspace.infrastructure_analytics.dim_date
USING DELTA
AS
SELECT *
FROM dim_date;

CREATE OR REPLACE TABLE workspace.infrastructure_analytics.fact_expenses
USING DELTA
AS
SELECT *
FROM fact_expenses;

CREATE OR REPLACE TABLE workspace.infrastructure_analytics.fact_project_performance
USING DELTA
AS
SELECT *
FROM fact_project_performance;

-- ============================================================
-- 05. FINAL GOLD TABLE ROW-COUNT CHECK
-- ============================================================
SELECT 'dim_project' AS table_name, COUNT(*) AS total_rows
FROM workspace.infrastructure_analytics.dim_project

UNION ALL

SELECT 'dim_contractor', COUNT(*)
FROM workspace.infrastructure_analytics.dim_contractor

UNION ALL

SELECT 'dim_date', COUNT(*)
FROM workspace.infrastructure_analytics.dim_date

UNION ALL

SELECT 'fact_expenses', COUNT(*)
FROM workspace.infrastructure_analytics.fact_expenses

UNION ALL

SELECT 'fact_project_performance', COUNT(*)
FROM workspace.infrastructure_analytics.fact_project_performance;
