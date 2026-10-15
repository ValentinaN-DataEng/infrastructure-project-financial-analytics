-- Infrastructure Project Financial Analytics
-- Source: exported Databricks notebook.
-- Execution notes:
-- 1) Run these scripts in order in the same Databricks SQL environment.
-- 2) TEMP VIEW objects are session-scoped; persistent Gold tables are created in 03_data_model.sql.
-- 3) The sample data and reference date are illustrative project data.

-- ============================================================
-- 01. PROJECT-LEVEL FINANCIAL METRICS (RAW EXPENSE LAYER)
-- ============================================================
CREATE OR REPLACE TEMP VIEW projects_budget_ut AS

WITH projects_expenses AS (
    SELECT
        p.project_id,
        p.project_name,
        p.budget,
        e.amount
    FROM projects_raw p
    LEFT JOIN expenses_raw e
        ON p.project_id = e.project_id
),

projects_cost AS (
    SELECT
        project_id,
        project_name,
        budget,
        COALESCE(SUM(amount), 0) AS actual_cost
    FROM projects_expenses
    GROUP BY
        project_id,
        project_name,
        budget
)

SELECT
    project_id,
    project_name,
    budget,
    actual_cost,
    budget - actual_cost AS remaining_budget,
    ROUND((actual_cost / budget) * 100, 2) AS budget_utilization_pct
FROM projects_cost;

SELECT * FROM projects_budget_ut

-- ============================================================
-- 02. MONTHLY CUMULATIVE EXPENDITURE
-- ============================================================
CREATE OR REPLACE TEMP VIEW cumulative_expenses AS

WITH expenses_total_monthly AS (
    SELECT
        DATE_TRUNC ('MONTH',expense_date) AS month,
        SUM (amount) AS total_expenditure
    FROM expenses_raw
    GROUP BY DATE_TRUNC ('MONTH',expense_date)
)

SELECT
    month,
    total_expenditure,
    SUM (total_expenditure) OVER (
            ORDER BY month ASC
    ) AS cumulative_expenditure
FROM expenses_total_monthly;

SELECT * FROM cumulative_expenses

-- ============================================================
-- 03. PROJECT / MONTH CUMULATIVE EXPENDITURE
-- ============================================================
CREATE OR REPLACE TEMP VIEW projects_expenses_cum AS

WITH projects_expenses_all AS (
    SELECT
        p.project_id,
        p.project_name,
        e.amount,
        DATE_TRUNC ('MONTH',e.expense_date) AS month
    FROM projects_raw p
    LEFT JOIN expenses_raw e
        ON p.project_id = e.project_id
),

projects_expenses_monthly AS (
    SELECT
        month,
        project_id,
        project_name,
        SUM (amount) AS monthly_expenditure
    FROM projects_expenses_all
    GROUP BY month, project_id, project_name
)

SELECT
    month,
    project_id,
    project_name,
    monthly_expenditure,
    SUM (monthly_expenditure) OVER (
        PARTITION BY project_id
        ORDER BY month ASC
    ) AS cumulative_project_expenditure
FROM projects_expenses_monthly;

SELECT * FROM projects_expenses_cum

-- ============================================================
-- 04. HIGHEST-EXPENSE PROJECTS
-- ============================================================
CREATE OR REPLACE TEMP VIEW highest_expenses AS
SELECT
    project_id,
    project_name,
    budget,
    actual_cost,
    remaining_budget,
    budget_utilization_pct
FROM projects_budget_ut
WHERE budget_utilization_pct > 50
ORDER BY budget_utilization_pct DESC;

SELECT * FROM highest_expenses

-- ============================================================
-- 05. PROJECT SCHEDULE STATUS
-- ============================================================
-- The original notebook uses 2026-09-27 as its reference date.
CREATE OR REPLACE TEMP VIEW projects_currently_state AS
SELECT
    project_id,
    project_name,
    planned_end_date,
    status,
    DATEDIFF(planned_end_date, '2026-09-27') AS days_to_deadline,
    CASE
        WHEN status = 'Completed'
            THEN 'Completed'
        WHEN planned_end_date < '2026-09-27'
            THEN 'Overdue'
        ELSE 'On Track'
    END AS schedule_status
FROM projects_raw;

SELECT * FROM projects_currently_state

-- ============================================================
-- 06. PROJECT PERFORMANCE RISK VIEW
-- ============================================================
-- This is a filtered risk view, not the complete project-performance dataset.
CREATE OR REPLACE TEMP VIEW project_performance AS
SELECT
    p.project_id,
    p.project_name,
    p.budget,
    p.actual_cost,
    p.remaining_budget,
    p.budget_utilization_pct,
    s.planned_end_date,
    s.status,
    s.days_to_deadline,
    s.schedule_status
FROM projects_budget_ut p
INNER JOIN projects_currently_state s
    ON p.project_id = s.project_id
    WHERE p.budget_utilization_pct > 50 AND s.schedule_status ='Overdue';

SELECT * FROM project_performance

-- ============================================================
-- 07. CONTRACTOR FINANCIAL PERFORMANCE
-- ============================================================
CREATE OR REPLACE TEMP VIEW contractor_performance AS

WITH project_and_contractors AS (
    SELECT
        c.contractor_id,
        c.contractor_name,
        c.contractor_type,
        p.project_id
    FROM contractors_raw c
    JOIN project_contractors_raw p
        ON c.contractor_id = p.contractor_id
),

projects_contractors_expenses AS (
    SELECT
        o.contractor_id,
        o.contractor_name,
        o.contractor_type,
        o.project_id,
        u.budget,
        u.actual_cost
    FROM project_and_contractors o
    JOIN projects_budget_ut u
        ON o.project_id = u.project_id
)

SELECT
    contractor_id,
    contractor_name,
    contractor_type,
    COUNT (DISTINCT project_id) AS number_of_projects,
    SUM (budget) AS total_budget,
    SUM (actual_cost) AS total_actual_cost,
    ROUND ((SUM (actual_cost)/SUM (budget)*100),2) AS budget_utilization_pct
FROM projects_contractors_expenses
GROUP BY contractor_id, contractor_name, contractor_type;

SELECT * FROM contractor_performance

-- ============================================================
-- 08. CONTRACTOR RISK PROJECTS
-- ============================================================
CREATE OR REPLACE TEMP VIEW contractors_risk_projects AS

WITH projects_and_contractors AS (
    SELECT
        p.contractor_id,
        p.contractor_name,
        p.number_of_projects AS total_projects,
        r.project_id
    FROM contractor_performance p
    JOIN project_contractors_raw r
        ON p.contractor_id = r.contractor_id
),

projects_performance_risk AS (
    SELECT
        c.contractor_id,
        c.contractor_name,
        c.total_projects,
        p.project_id AS risk_project_id
    FROM projects_and_contractors c
    LEFT JOIN project_performance p
        ON c.project_id = p.project_id
)

SELECT
    contractor_id,
    contractor_name,
    total_projects,
    COUNT(DISTINCT risk_project_id) AS at_risk_projects,
    ROUND(
        COUNT(DISTINCT risk_project_id) * 100.0 / total_projects,
        2
    ) AS risk_project_pct
FROM projects_performance_risk
GROUP BY contractor_id, contractor_name, total_projects;

SELECT * FROM contractors_risk_projects

-- ============================================================
-- 09. CONTRACTOR CUMULATIVE EXPENDITURE
-- ============================================================
CREATE OR REPLACE TEMP VIEW contractor_cumulative_expenses AS

WITH project_and_contractors AS (
    SELECT
        p.contractor_id,
        p.contractor_name,
        c.project_id
    FROM contractors_raw p
    JOIN project_contractors_raw c
        ON p.contractor_id = c.contractor_id
),

contractors_all_expenses AS (
    SELECT
        a.contractor_id,
        a.contractor_name,
        a.project_id,
        DATE_TRUNC ('MONTH',e.expense_date) AS month,
        e.amount
    FROM project_and_contractors a
    JOIN expenses_raw e
        ON a.project_id = e.project_id
),

contractor_expenses_monthly AS (
    SELECT
        contractor_id,
        contractor_name,
        month,
        SUM (amount) AS monthly_expenditure
    FROM contractors_all_expenses
    GROUP BY contractor_id, contractor_name, month
)

SELECT 
    contractor_id,
    contractor_name,
    month,
    monthly_expenditure,
    SUM (monthly_expenditure) OVER (
        PARTITION BY contractor_id
        ORDER BY month ASC
    ) AS cumulative_expenditure
FROM contractor_expenses_monthly;

SELECT * FROM contractor_cumulative_expenses

-- ============================================================
-- 10. CLEAN-LAYER FINANCIAL TRANSFORMATIONS
-- ============================================================
CREATE OR REPLACE TEMP VIEW projects_budget_clean AS

WITH projects_expenses AS (
    SELECT
        p.project_id,
        p.project_name,
        p.budget,
        e.amount
    FROM projects_raw p
    LEFT JOIN clean_expenses e
        ON p.project_id = e.project_id
),

projects_cost AS (
    SELECT
        project_id,
        project_name,
        budget,
        COALESCE(SUM(amount), 0) AS actual_cost
    FROM projects_expenses
    GROUP BY
        project_id,
        project_name,
        budget
)

SELECT
    project_id,
    project_name,
    budget,
    actual_cost,
    budget - actual_cost AS remaining_budget,
    ROUND(actual_cost / NULLIF(budget,0) * 100, 2) AS budget_utilization_pct
FROM projects_cost;

SELECT * FROM projects_budget_clean

-- Clean monthly cumulative expenditure
CREATE OR REPLACE TEMP VIEW cumulative_expenses_clean AS

WITH expenses_total_monthly AS (
    SELECT
        DATE_TRUNC ('MONTH',expense_date) AS month,
        SUM (amount) AS total_expenditure
    FROM clean_expenses
    GROUP BY DATE_TRUNC ('MONTH',expense_date)
)

SELECT
    month,
    total_expenditure,
    SUM (total_expenditure) OVER (
            ORDER BY month ASC
    ) AS cumulative_expenditure
FROM expenses_total_monthly;

SELECT * FROM cumulative_expenses_clean

-- Complete project-performance output based on clean financial metrics
CREATE OR REPLACE TEMP VIEW projects_performance_clean AS
SELECT
    b.project_id,
    b.project_name,
    b.budget,
    b.actual_cost,
    b.remaining_budget,
    b.budget_utilization_pct,
    s.planned_end_date,
    s.status,
    s.days_to_deadline,
    s.schedule_status
FROM projects_budget_clean b
LEFT JOIN projects_currently_state s
    ON b.project_id = s.project_id;

SELECT * FROM projects_performance_clean

-- Clean contractor performance
CREATE OR REPLACE TEMP VIEW contractor_performance_clean AS

WITH project_and_contractors AS (
    SELECT
        c.contractor_id,
        c.contractor_name,
        c.contractor_type,
        p.project_id
    FROM contractors_raw c
    JOIN project_contractors_raw p
        ON c.contractor_id = p.contractor_id
),

projects_contractors_expenses AS (
    SELECT
        o.contractor_id,
        o.contractor_name,
        o.contractor_type,
        o.project_id,
        c.budget,
        c.actual_cost
    FROM project_and_contractors o
    JOIN projects_budget_clean c
        ON o.project_id = c.project_id
)

SELECT
    contractor_id,
    contractor_name,
    contractor_type,
    COUNT (DISTINCT project_id) AS number_of_projects,
    SUM (budget) AS total_budget,
    SUM (actual_cost) AS total_actual_cost,
    ROUND ((SUM (actual_cost)/SUM (budget)*100),2) AS budget_utilization_pct
FROM projects_contractors_expenses
GROUP BY contractor_id, contractor_name, contractor_type;

SELECT * FROM contractor_performance_clean

-- ============================================================
-- 11. INCREMENTAL MERGE DEMONSTRATION (ISOLATED EXAMPLE)
-- ============================================================
-- This example demonstrates an upsert into expenses_target.
-- It is not integrated with clean_expenses or the Gold refresh process.
CREATE OR REPLACE TEMP VIEW expenses_incremental AS
SELECT * FROM VALUES
    (1002, 101, '2026-09-28', 'Labor', 185000),
    (1015, 103, '2026-09-28', 'Materials', 95000)
AS t(
    expense_id,
    project_id,
    expense_date,
    category,
    amount
);

SELECT *
FROM expenses_incremental;

-- Create the Delta target from raw expenses
CREATE OR REPLACE TABLE expenses_target
USING DELTA
AS
SELECT *
FROM expenses_raw;

-- Apply update/insert logic by expense_id
MERGE INTO expenses_target AS target
USING expenses_incremental AS source
ON target.expense_id = source.expense_id

WHEN MATCHED THEN
    UPDATE SET
        target.project_id = source.project_id,
        target.expense_date = source.expense_date,
        target.category = source.category,
        target.amount = source.amount

WHEN NOT MATCHED THEN
    INSERT (
        expense_id,
        project_id,
        expense_date,
        category,
        amount
    )
    VALUES (
        source.expense_id,
        source.project_id,
        source.expense_date,
        source.category,
        source.amount
    );

-- Validate the MERGE result
SELECT *
FROM expenses_target
ORDER BY expense_id;
