\set ON_ERROR_STOP on
\echo 'WARNING: This script drops/recreates the saas schema and loads demo data. Use a disposable development database.'
DROP SCHEMA IF EXISTS saas CASCADE;
\ir ../migrations/001_initial_schema.sql
\ir ../fixtures/001_seed_data.sql
\ir ./verify_seed_counts.sql
\ir ./verify_constraints.sql
\echo '--- Query set 1: CTEs and recursive logic ---'
\ir ../queries/01_ctes_and_recursive_logic.sql
\echo '--- Query set 2: Window functions ---'
\ir ../queries/02_window_functions.sql
\echo '--- Query set 3: Joins and subqueries ---'
\ir ../queries/03_joins_and_subqueries.sql
\echo 'SUCCESS: schema, seed fixtures, integrity tests, and analytical query scripts completed.'
