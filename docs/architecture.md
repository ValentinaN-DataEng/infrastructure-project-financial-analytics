# Data Platform Architecture

## Pipeline Overview

Raw project and expense data is validated, cleaned, transformed, and organized into analytical tables for Power BI reporting.

Raw Data → Data Quality → Clean Data → SQL Transformations → Gold Data Model → Power BI

## Data Model

### Dimensions
- `dim_project`
- `dim_contractor`
- `dim_date`

### Fact Tables
- `fact_expenses`
- `fact_project_performance`

## Technologies

Databricks SQL, Delta Lake, dimensional modeling, and Power BI.
