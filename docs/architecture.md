# Data Platform Architecture

## Overview

The Infrastructure Project Financial Analytics solution transforms project, contractor, and expense records into structured analytical data for financial and operational reporting.

## Data Pipeline

```text
Raw Data
   |
   v
Data Quality Validation
   |
   v
Clean Data
   |
   v
SQL Transformations
   |
   v
Gold Dimensional Model
   |
   v
Power BI Dashboard
```

## Data Layers

### Raw

Contains the original project, contractor, project-contractor assignment, and expense records.

### Clean

Applies expense validation rules and excludes rejected expense records from downstream financial calculations.

### Analytics and Gold

Produces project and contractor performance metrics, cumulative expenditure, and analytical tables for reporting.

## Dimensional Model

### Dimensions

| Table | Grain | Purpose |
|---|---|---|
| `dim_project` | One row per project | Project attributes and contractor assignment |
| `dim_contractor` | One row per contractor | Contractor attributes |
| `dim_date` | One row per calendar date | Calendar analysis |

### Fact Tables

| Table | Grain | Purpose |
|---|---|---|
| `fact_expenses` | One row per expense | Expense-level financial analysis |
| `fact_project_performance` | One row per project | Budget and project-performance metrics |

## Technologies

- Databricks SQL and Spark SQL
- Delta Lake
- Dimensional data modeling
- Power BI

## Implementation Notes

The Gold tables are persisted in the Databricks schema `workspace.infrastructure_analytics`.

The incremental `MERGE` example demonstrates updating an existing expense and inserting a new expense. It remains a separate demonstration and is not yet integrated into the clean-data-to-Gold refresh process.

The project uses sample data for portfolio demonstration purposes.
