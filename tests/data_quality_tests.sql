
-- Infrastructure Project Financial Analytics
-- Data Quality Tests
-- Run against the persistent Gold tables in Databricks.
-- Expected result: every test has failed_records = 0 and status = 'PASS'.

WITH duplicate_expense_ids AS (
    SELECT COUNT(*) AS failed_records
    FROM (
        SELECT expense_id
        FROM workspace.infrastructure_analytics.fact_expenses
        GROUP BY expense_id
        HAVING COUNT(*) > 1
    ) duplicates
),

invalid_expenses AS (
    SELECT COUNT(*) AS failed_records
    FROM workspace.infrastructure_analytics.fact_expenses
    WHERE expense_id IS NULL
       OR project_id IS NULL
       OR expense_date IS NULL
       OR amount IS NULL
       OR amount <= 0
),

financial_reconciliation AS (
    SELECT
        CASE
            WHEN ABS(expense_total - project_cost_total) < 0.01 THEN 0
            ELSE 1
        END AS failed_records,
        expense_total,
        project_cost_total
    FROM (
        SELECT
            (
                SELECT COALESCE(SUM(amount), 0)
                FROM workspace.infrastructure_analytics.fact_expenses
            ) AS expense_total,
            (
                SELECT COALESCE(SUM(actual_cost), 0)
                FROM workspace.infrastructure_analytics.fact_project_performance
            ) AS project_cost_total
    ) totals
),

unmatched_projects AS (
    SELECT COUNT(*) AS failed_records
    FROM workspace.infrastructure_analytics.fact_expenses e
    LEFT ANTI JOIN workspace.infrastructure_analytics.dim_project p
        ON e.project_id = p.project_id
),

test_results AS (
    SELECT
        'Unique expense IDs' AS test_name,
        failed_records,
        'Duplicate expense IDs must not exist' AS details
    FROM duplicate_expense_ids

    UNION ALL

    SELECT
        'Valid expense records',
        failed_records,
        'Null keys, dates, or amounts and non-positive amounts must not exist'
    FROM invalid_expenses

    UNION ALL

    SELECT
        'Financial reconciliation',
        failed_records,
        CONCAT(
            'Expense total = ',
            CAST(expense_total AS STRING),
            '; project actual cost total = ',
            CAST(project_cost_total AS STRING)
        )
    FROM financial_reconciliation

    UNION ALL

    SELECT
        'Project referential integrity',
        failed_records,
        'Every expense project_id must exist in dim_project'
    FROM unmatched_projects
)

SELECT
    test_name,
    failed_records,
    details,
    CASE
        WHEN failed_records = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM test_results
ORDER BY test_name;
