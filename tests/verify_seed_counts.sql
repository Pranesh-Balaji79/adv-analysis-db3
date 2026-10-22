\set ON_ERROR_STOP on
\echo '--- Baseline data counts ---'
SELECT 'tenants' AS table_name, count(*) AS row_count FROM saas.tenants
UNION ALL SELECT 'tenant_settings', count(*) FROM saas.tenant_settings
UNION ALL SELECT 'users', count(*) FROM saas.users
UNION ALL SELECT 'tenant_memberships', count(*) FROM saas.tenant_memberships
UNION ALL SELECT 'projects', count(*) FROM saas.projects
UNION ALL SELECT 'tasks', count(*) FROM saas.tasks
UNION ALL SELECT 'tags', count(*) FROM saas.tags
UNION ALL SELECT 'project_tags', count(*) FROM saas.project_tags
ORDER BY table_name;

DO $$
DECLARE
    v_count BIGINT;
BEGIN
    SELECT count(*) INTO v_count FROM saas.tasks;
    IF v_count <> 10 THEN RAISE EXCEPTION 'Expected 10 seeded tasks, found %', v_count; END IF;
    SELECT count(*) INTO v_count FROM saas.projects;
    IF v_count <> 4 THEN RAISE EXCEPTION 'Expected 4 seeded projects, found %', v_count; END IF;
    SELECT count(*) INTO v_count FROM saas.project_tags;
    IF v_count <> 5 THEN RAISE EXCEPTION 'Expected 5 seeded project-tag links, found %', v_count; END IF;
    RAISE NOTICE 'PASS: baseline seed row counts verified';
END $$;
