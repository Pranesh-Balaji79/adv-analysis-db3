# Advanced SQL Queries, CTEs & Window Functions

A PostgreSQL 14+ analytics project that answers business-intelligence questions for a multi-tenant SaaS work-management application. It demonstrates multi-step and recursive Common Table Expressions (CTEs), window functions, aggregation, subqueries, and multi-table `INNER`, `LEFT`, and `FULL OUTER JOIN`s.

## What is included

- `migrations/001_initial_schema.sql` — normalized `saas` schema used as the analytical dataset.
- `fixtures/001_seed_data.sql` — repeatable multi-row seed data across two tenants; task timestamps span multiple months to support trend analysis.
- `queries/01_ctes_and_recursive_logic.sql` — project delivery metrics, tenant rollups, and recursive weekly calendar.
- `queries/02_window_functions.sql` — `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, `LAG()`, `LEAD()`, and running totals using `OVER (PARTITION BY ...)`.
- `queries/03_joins_and_subqueries.sql` — multi-table `INNER JOIN`, `LEFT JOIN`, `FULL OUTER JOIN`, aggregated subqueries, and a correlated subquery.
- `tests/verify_constraints.sql` — negative tests for invalid tenant references/roles and cascade update/delete checks.
- `tests/verify_seed_counts.sql` — checks the expected sample-data counts.
- `tests/run_all.sql` — one entry point that rebuilds the schema, loads data, runs integrity tests, then prints the analytical query result sets.
- `docs/query-catalog.md` — question and technique summary for each query.
- `docs/expected-results.md` — baseline row counts and expected behavior of the analytics.

## Requirements

- PostgreSQL 14 or later (PostgreSQL 16.15 is suitable).
- `psql` command-line client.

## Run with Windows PowerShell

Extract the ZIP. Open PowerShell in the folder containing this `README.md`.

```powershell
Set-Location -LiteralPath "C:\path\to\advanced_sql_analytics"
psql --version
```

Create a dedicated demo database if it does not exist:

```powershell
createdb -U postgres -h localhost -p 5432 advanced_sql_demo
```

Run all integrity checks and analytical queries:

```powershell
psql -U postgres -h localhost -p 5432 -d advanced_sql_demo -v ON_ERROR_STOP=1 -f ".\tests\run_all.sql"
```

To save your **actual local execution output** as evidence:

```powershell
psql -U postgres -h localhost -p 5432 -d advanced_sql_demo -v ON_ERROR_STOP=1 -f ".\tests\run_all.sql" 2>&1 | Tee-Object ".\docs\local-test-output.txt"
$LASTEXITCODE
```

A `0` exit code means `psql` completed successfully. The script intentionally drops and recreates only the `saas` schema. Run it only against a dedicated development/demo database; it will destroy existing objects in that schema.

PowerShell versions can display PostgreSQL `NOTICE` output as `NativeCommandError` records even when the server is reporting a notice rather than a SQL failure. Review the PASS notices and `$LASTEXITCODE`.

## Run just the analytical queries

After schema and seed data already exist:

```powershell
psql -U postgres -h localhost -p 5432 -d advanced_sql_demo -v ON_ERROR_STOP=1 -f ".\queries\01_ctes_and_recursive_logic.sql"
psql -U postgres -h localhost -p 5432 -d advanced_sql_demo -v ON_ERROR_STOP=1 -f ".\queries\02_window_functions.sql"
psql -U postgres -h localhost -p 5432 -d advanced_sql_demo -v ON_ERROR_STOP=1 -f ".\queries\03_joins_and_subqueries.sql"
```

## Main techniques demonstrated

| Technique | Where demonstrated |
|---|---|
| Multi-step CTEs | Queries 1 and 2 in `01_ctes_and_recursive_logic.sql` |
| Recursive CTE | Query 3 in `01_ctes_and_recursive_logic.sql` |
| `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()` | Query 4 in `02_window_functions.sql` |
| `LAG()`, `LEAD()` | Query 5 in `02_window_functions.sql` |
| Running total with `SUM() OVER (PARTITION BY ... ORDER BY ...)` | Query 6 in `02_window_functions.sql` |
| Multi-table `INNER JOIN` | Query 7 in `03_joins_and_subqueries.sql` |
| `LEFT JOIN` with pre-aggregated subqueries | Query 8 in `03_joins_and_subqueries.sql` |
| `FULL OUTER JOIN` reconciliation | Query 9 in `03_joins_and_subqueries.sql` |
| Correlated subquery | Query 10 in `03_joins_and_subqueries.sql` |

## GitHub

```powershell
git init
git add .
git status
git commit -m "Add advanced SQL analytics queries"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
git push -u origin main
```

Replace the URL with your own GitHub repository URL. See `docs/github-setup.md` for details.

## Important

The SQL and project files were authored for PostgreSQL. The included test scripts should be executed on your local PostgreSQL instance before submission. Do not claim local runtime verification until the command has run successfully on your machine. The scenario and data are illustrative; align requirements and business definitions with your assigned brief if it specifies different metrics.
