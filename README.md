# Infrastructure Project Financial Analytics

An end-to-end analytics solution for monitoring infrastructure project budgets, expenditures, contractor allocations, and project status using Databricks SQL, Delta Lake, and Power BI.

## Business Problem

Infrastructure consulting and project-management teams need visibility into project costs, budget utilization, contractor allocations, and schedule status. Without consistent data validation and consolidated reporting, comparing project performance and identifying areas requiring attention can be difficult.

This project demonstrates a data pipeline and analytics solution that transforms raw project and expense records into structured, reporting-ready data.

## Solution

The solution uses Databricks SQL to validate, clean, and transform project and financial data, then organizes the outputs into a dimensional model consumed by Power BI.

The dashboard supports:
- Portfolio-level budget and expenditure monitoring.
- Budget-versus-actual comparisons by project.
- Monthly expenditure trend analysis.
- Budget utilization and remaining-budget comparisons.
- Contractor budget allocation analysis.
- Project status monitoring.

## Architecture

**Raw Data → Data Quality → Clean Data → SQL Transformations → Gold Data Model → Power BI**

## Technology Stack

- **Databricks SQL / Spark SQL** — data quality, transformations, aggregations, and analytical views.
- **Delta Lake** — persistent analytical tables and an incremental `MERGE` demonstration.
- **Dimensional modeling** — project, contractor, and date dimensions; expense and project-performance fact tables.
- **Power BI** — DAX measures, data modeling, and interactive dashboards.
- **Git and GitHub** — version control and project documentation.

## Data Model

| Table | Grain |
|---|---|
| `dim_project` | One row per project |
| `dim_contractor` | One row per contractor |
| `dim_date` | One row per calendar date |
| `fact_expenses` | One row per expense |
| `fact_project_performance` | One row per project |

## Data Validation

The sample dataset contains:
- 5 projects.
- 4 contractors.
- 14 expense records in the original sample.
- 365 calendar-date records.
- 5 project-performance records.

Expense validation rules identify invalid records before they enter the clean expense layer. The analytical model was checked for the expected row counts and key uniqueness.

## Business Results & Impact

The dashboard consolidates financial and operational indicators into a single reporting experience. It enables users to compare budget utilization, examine monthly expenditure patterns, review contractor allocations, and identify projects that may warrant further investigation.

The project demonstrates how data validation, consistent financial metrics, and dimensional modeling can support more reliable business reporting. It uses sample data; financial savings and operational improvements have not been measured.

## Project Structure

- `notebooks/` — Databricks notebooks.
- `sql/` — SQL transformations and validation queries.
- `powerbi/` — Power BI report and dashboard screenshots.
- `docs/` — architecture and technical documentation.
- `tests/` — data-quality and validation tests.

## Future Improvements

- Integrate incremental ingestion and `MERGE` processing into the end-to-end pipeline.
- Automate data-quality tests and pipeline execution.
- Extend schedule analysis with actual completion dates and project milestones.
- Document refresh orchestration and deployment.
