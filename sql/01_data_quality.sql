-- Infrastructure Project Financial Analytics
-- Source: exported Databricks notebook.
-- Execution notes:
-- 1) Run these scripts in order in the same Databricks SQL environment.
-- 2) TEMP VIEW objects are session-scoped; persistent Gold tables are created in 03_data_model.sql.
-- 3) The sample data and reference date are illustrative project data.

-- ============================================================
-- 01. RAW SOURCE DATA
-- ============================================================
-- Projects
CREATE OR REPLACE TEMP VIEW projects_raw AS
SELECT * FROM VALUES
    (101, 'Water Network North', '2026-01-15', '2026-10-30', 1500000, 'Active'),
    (102, 'Drainage Upgrade West', '2026-02-01', '2026-08-15', 900000, 'Completed'),
    (103, 'Pipeline Rehabilitation', '2026-03-10', '2026-12-20', 2200000, 'Active'),
    (104, 'Treatment Plant Expansion', '2026-01-20', '2026-11-30', 3500000, 'Delayed'),
    (105, 'Stormwater Project South', '2026-04-05', '2026-09-30', 750000, 'Active')
AS t(
    project_id,
    project_name,
    start_date,
    planned_end_date,
    budget,
    status
);

-- Expenses
CREATE OR REPLACE TEMP VIEW expenses_raw AS
SELECT * FROM VALUES
    (1001, 101, '2026-01-20', 'Materials', 120000),
    (1002, 101, '2026-02-15', 'Labor', 180000),
    (1003, 101, '2026-03-10', 'Equipment', 90000),
    (1004, 102, '2026-02-20', 'Materials', 150000),
    (1005, 102, '2026-04-15', 'Labor', 200000),
    (1006, 102, '2026-06-10', 'Equipment', 80000),
    (1007, 103, '2026-03-20', 'Materials', 300000),
    (1008, 103, '2026-05-12', 'Labor', 250000),
    (1009, 103, '2026-07-05', 'Equipment', 180000),
    (1010, 104, '2026-02-10', 'Materials', 400000),
    (1011, 104, '2026-04-22', 'Labor', 500000),
    (1012, 104, '2026-07-15', 'Equipment', 300000),
    (1013, 105, '2026-04-20', 'Materials', 100000),
    (1014, 105, '2026-06-18', 'Labor', 120000)
AS t(
    expense_id,
    project_id,
    expense_date,
    category,
    amount
);

-- Contractors
CREATE OR REPLACE TEMP VIEW contractors_raw AS
SELECT * FROM VALUES
    (201, 'AquaBuild S.A.S.', 'Construction'),
    (202, 'InfraWorks Colombia', 'Infrastructure'),
    (203, 'HydroProjects S.A.S.', 'Water Resources'),
    (204, 'UrbanFlow Ltda.', 'Infrastructure')
AS t(
    contractor_id,
    contractor_name,
    contractor_type
);

-- Project-to-contractor assignments
CREATE OR REPLACE TEMP VIEW project_contractors_raw AS
SELECT * FROM VALUES
    (101, 201),
    (102, 202),
    (103, 203),
    (104, 201),
    (105, 204)
AS t(
    project_id,
    contractor_id
);

-- ============================================================
-- 02. EXPENSE DATA QUALITY
-- ============================================================
CREATE OR REPLACE TEMP VIEW expense_quality AS

WITH expenses_project AS (
    SELECT
        e.expense_id,
        e.project_id,
        p.project_id AS project_id_p,
        e.expense_date,
        e.category,
        e.amount
    FROM expenses_raw e
    LEFT JOIN projects_raw p
        ON e.project_id = p.project_id
)

SELECT
    expense_id,
    project_id,
    expense_date,
    category,
    amount,
    CASE
        WHEN amount > 0 AND project_id_p IS NOT NULL AND expense_date IS NOT NULL THEN 'Valid'
        ELSE 'Rejected'
    END AS data_quality_status
FROM expenses_project;

SELECT * FROM expense_quality

-- Summary of valid and rejected expenses
CREATE OR REPLACE TEMP VIEW expense_quality_summary AS
SELECT
    COUNT (*) AS total_expenses,
    SUM (
        CASE
            WHEN data_quality_status = 'Valid' THEN 1
            ELSE 0
        END
    ) AS valid_expenses,
    SUM (
        CASE
            WHEN data_quality_status = 'Rejected' THEN 1
            ELSE 0
        END
    ) AS rejected_expenses,
    ROUND(SUM (
        CASE
            WHEN data_quality_status = 'Rejected' THEN 1
            ELSE 0
        END
    )*100 / NULLIF(COUNT (*),0), 2) AS rejected_percentage
FROM expense_quality;

SELECT * FROM expense_quality_summary

-- Clean expense layer: only valid expense records
CREATE OR REPLACE TEMP VIEW clean_expenses AS
SELECT
    expense_id,
    project_id,
    expense_date,
    category,
    amount
FROM expense_quality
WHERE data_quality_status = 'Valid';

SELECT * FROM clean_expenses

-- ============================================================
-- 03. PROJECT QUALITY CHECKS
-- ============================================================
CREATE OR REPLACE TEMP VIEW project_quality_checks AS

SELECT
    'Duplicate projects' AS check_name,
    COUNT(*) AS failed_records,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'REVIEW'
    END AS check_status
FROM (
    SELECT project_id
    FROM projects_performance_clean
    GROUP BY project_id
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

SELECT
    'Negative budget' AS check_name,
    SUM(
        CASE
            WHEN budget < 0 THEN 1
            ELSE 0
        END
    ) AS failed_records,
    CASE
        WHEN SUM(CASE WHEN budget < 0 THEN 1 ELSE 0 END) = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END AS check_status
FROM projects_performance_clean

UNION ALL

SELECT
    'Over budget' AS check_name,
    SUM(
        CASE
            WHEN actual_cost > budget THEN 1
            ELSE 0
        END
    ) AS failed_records,
    CASE
        WHEN SUM(CASE WHEN actual_cost > budget THEN 1 ELSE 0 END) = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END AS check_status
FROM projects_performance_clean;

SELECT *
FROM project_quality_checks;

-- Optional: inspect quality-check results
SELECT * FROM project_quality_checks;
