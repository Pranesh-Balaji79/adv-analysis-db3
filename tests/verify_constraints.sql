\set ON_ERROR_STOP on
\echo '--- Negative constraint tests ---'

DO $$
DECLARE v_tenant_id BIGINT; v_user_id BIGINT;
BEGIN
    SELECT tenant_id INTO v_tenant_id FROM saas.tenants WHERE tenant_slug = 'acme-design';
    SELECT user_id INTO v_user_id FROM saas.users WHERE email = 'alice@example.com';
    BEGIN
        INSERT INTO saas.tenant_memberships (tenant_id, user_id, role)
        VALUES (v_tenant_id, v_user_id, 'member');
        RAISE EXCEPTION 'FAIL: duplicate tenant membership was accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS: duplicate tenant membership rejected (SQLSTATE 23505)';
    END;
END $$;

DO $$
DECLARE v_tenant_id BIGINT; v_project_id BIGINT; v_foreign_tag_id BIGINT;
BEGIN
    SELECT tenant_id INTO v_tenant_id FROM saas.tenants WHERE tenant_slug = 'acme-design';
    SELECT project_id INTO v_project_id FROM saas.projects WHERE tenant_id = v_tenant_id AND project_key = 'WEB';
    SELECT tag_id INTO v_foreign_tag_id
      FROM saas.tags tag JOIN saas.tenants t USING (tenant_id)
      WHERE t.tenant_slug = 'bluebird-labs' AND tag.tag_name = 'analytics';
    BEGIN
        INSERT INTO saas.project_tags (tenant_id, project_id, tag_id)
        VALUES (v_tenant_id, v_project_id, v_foreign_tag_id);
        RAISE EXCEPTION 'FAIL: cross-tenant project tag association was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS: cross-tenant project/tag association rejected (SQLSTATE 23503)';
    END;
END $$;

DO $$
DECLARE v_tenant_id BIGINT; v_project_id BIGINT; v_foreign_user_id BIGINT;
BEGIN
    SELECT tenant_id INTO v_tenant_id FROM saas.tenants WHERE tenant_slug = 'acme-design';
    SELECT project_id INTO v_project_id FROM saas.projects WHERE tenant_id = v_tenant_id AND project_key = 'WEB';
    SELECT user_id INTO v_foreign_user_id FROM saas.users WHERE email = 'carla@example.com';
    BEGIN
        INSERT INTO saas.tasks (tenant_id, project_id, assignee_user_id, title)
        VALUES (v_tenant_id, v_project_id, v_foreign_user_id, 'Should be rejected: cross-tenant assignee');
        RAISE EXCEPTION 'FAIL: cross-tenant assignee was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS: task assignment to non-member of tenant rejected (SQLSTATE 23503)';
    END;
END $$;

DO $$
DECLARE v_tenant_id BIGINT; v_project_id BIGINT;
BEGIN
    SELECT tenant_id INTO v_tenant_id FROM saas.tenants WHERE tenant_slug = 'acme-design';
    SELECT project_id INTO v_project_id FROM saas.projects WHERE tenant_id = v_tenant_id AND project_key = 'WEB';
    BEGIN
        INSERT INTO saas.tasks (tenant_id, project_id, title, status)
        VALUES (v_tenant_id, v_project_id, 'Should be rejected: invalid status', 'waiting_forever');
        RAISE EXCEPTION 'FAIL: invalid task status was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: invalid task status rejected (SQLSTATE 23514)';
    END;
END $$;

DO $$
BEGIN
    BEGIN
        INSERT INTO saas.tenant_memberships (tenant_id, user_id, role)
        VALUES (999999999, 999999998, 'member');
        RAISE EXCEPTION 'FAIL: orphan membership was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS: orphan tenant/user membership rejected (SQLSTATE 23503)';
    END;
END $$;

\echo '--- Referential-action tests ---'
-- Prove ON UPDATE CASCADE works. Roll back the test transaction so fixture IDs remain stable.
-- Updating one project ID should propagate to its task rows and junction rows.
BEGIN;
DO $$
DECLARE
    v_tenant_id BIGINT;
    v_old_id BIGINT;
    v_new_id BIGINT;
    v_rows INTEGER;
BEGIN
    SELECT tenant_id INTO v_tenant_id FROM saas.tenants WHERE tenant_slug = 'acme-design';
    SELECT project_id INTO v_old_id FROM saas.projects WHERE tenant_id = v_tenant_id AND project_key = 'WEB';
    SELECT COALESCE(MAX(project_id), 0) + 1000 INTO v_new_id FROM saas.projects;
    UPDATE saas.projects SET project_id = v_new_id WHERE tenant_id = v_tenant_id AND project_id = v_old_id;

    SELECT count(*) INTO v_rows FROM saas.tasks WHERE tenant_id = v_tenant_id AND project_id = v_new_id;
    IF v_rows <> 4 THEN RAISE EXCEPTION 'FAIL: tasks did not cascade on project ID update'; END IF;
    SELECT count(*) INTO v_rows FROM saas.project_tags WHERE tenant_id = v_tenant_id AND project_id = v_new_id;
    IF v_rows <> 3 THEN RAISE EXCEPTION 'FAIL: project_tags did not cascade on project ID update'; END IF;
    RAISE NOTICE 'PASS: project primary-key update cascaded to tasks and project_tags';
END $$;
ROLLBACK;

-- Prove deleting a project cascades to its tasks and project-tag junction rows.
BEGIN;
DO $$
DECLARE
    v_tenant_id BIGINT;
    v_project_id BIGINT;
    v_task_count INTEGER;
    v_tag_count INTEGER;
BEGIN
    SELECT tenant_id INTO v_tenant_id FROM saas.tenants WHERE tenant_slug = 'acme-design';
    SELECT project_id INTO v_project_id FROM saas.projects WHERE tenant_id = v_tenant_id AND project_key = 'WEB';
    SELECT count(*) INTO v_task_count FROM saas.tasks WHERE tenant_id = v_tenant_id AND project_id = v_project_id;
    SELECT count(*) INTO v_tag_count FROM saas.project_tags WHERE tenant_id = v_tenant_id AND project_id = v_project_id;
    IF v_task_count <> 4 OR v_tag_count <> 3 THEN
        RAISE EXCEPTION 'FAIL: unexpected seed data for project cascade test';
    END IF;
    DELETE FROM saas.projects WHERE tenant_id = v_tenant_id AND project_id = v_project_id;
    IF EXISTS (SELECT 1 FROM saas.tasks WHERE tenant_id = v_tenant_id AND project_id = v_project_id) THEN
        RAISE EXCEPTION 'FAIL: deleting project did not cascade to tasks';
    END IF;
    IF EXISTS (SELECT 1 FROM saas.project_tags WHERE tenant_id = v_tenant_id AND project_id = v_project_id) THEN
        RAISE EXCEPTION 'FAIL: deleting project did not cascade to project_tags';
    END IF;
    RAISE NOTICE 'PASS: project deletion cascaded to related tasks and project_tags';
END $$;
ROLLBACK;

\echo '--- Seed row counts (baseline restored after rollback tests) ---'
SELECT 'tenants' AS table_name, count(*) AS row_count FROM saas.tenants
UNION ALL SELECT 'tenant_settings', count(*) FROM saas.tenant_settings
UNION ALL SELECT 'users', count(*) FROM saas.users
UNION ALL SELECT 'tenant_memberships', count(*) FROM saas.tenant_memberships
UNION ALL SELECT 'projects', count(*) FROM saas.projects
UNION ALL SELECT 'tasks', count(*) FROM saas.tasks
UNION ALL SELECT 'tags', count(*) FROM saas.tags
UNION ALL SELECT 'project_tags', count(*) FROM saas.project_tags
ORDER BY table_name;
