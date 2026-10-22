-- Repeatable demonstration dataset for the advanced SQL analytics assignment.
-- WARNING: this fixture truncates all tables in the saas schema. Use only in a dedicated demo database.
-- Task created_at timestamps span multiple months so running-total queries are meaningful.

BEGIN;
TRUNCATE TABLE
    saas.project_tags,
    saas.tasks,
    saas.projects,
    saas.tags,
    saas.tenant_memberships,
    saas.tenant_settings,
    saas.users,
    saas.tenants
RESTART IDENTITY CASCADE;

INSERT INTO saas.tenants (tenant_slug, display_name) VALUES
    ('acme-design', 'Acme Design Studio'),
    ('bluebird-labs', 'Bluebird Labs');

INSERT INTO saas.tenant_settings (tenant_id, time_zone, retention_days, support_email)
SELECT tenant_id, 'Asia/Kolkata', 365, 'support@acme.example'
FROM saas.tenants WHERE tenant_slug = 'acme-design';

INSERT INTO saas.tenant_settings (tenant_id, time_zone, retention_days, support_email)
SELECT tenant_id, 'UTC', 730, 'help@bluebird.example'
FROM saas.tenants WHERE tenant_slug = 'bluebird-labs';

INSERT INTO saas.users (email, display_name) VALUES
    ('alice@example.com', 'Alice Morgan'),
    ('bob@example.com', 'Bob Chen'),
    ('carla@example.com', 'Carla Singh'),
    ('daniel@example.com', 'Daniel Okafor');

INSERT INTO saas.tenant_memberships (tenant_id, user_id, role)
SELECT t.tenant_id, u.user_id, data.role
FROM (VALUES
    ('acme-design', 'alice@example.com', 'owner'),
    ('acme-design', 'bob@example.com', 'member'),
    ('bluebird-labs', 'alice@example.com', 'viewer'),
    ('bluebird-labs', 'carla@example.com', 'owner'),
    ('bluebird-labs', 'daniel@example.com', 'member')
) AS data(tenant_slug, email, role)
JOIN saas.tenants t ON t.tenant_slug = data.tenant_slug
JOIN saas.users u ON u.email = data.email;

INSERT INTO saas.projects (tenant_id, project_key, project_name, status, created_by_user_id)
SELECT t.tenant_id, data.project_key, data.project_name, data.status, u.user_id
FROM (VALUES
    ('acme-design', 'WEB', 'Website Revamp', 'active', 'alice@example.com'),
    ('acme-design', 'MOB', 'Mobile Companion App', 'on_hold', 'bob@example.com'),
    ('bluebird-labs', 'DATA', 'Analytics Dashboard', 'active', 'carla@example.com'),
    ('bluebird-labs', 'OPS', 'Operations Archive', 'completed', 'carla@example.com')
) AS data(tenant_slug, project_key, project_name, status, creator_email)
JOIN saas.tenants t ON t.tenant_slug = data.tenant_slug
JOIN saas.users u ON u.email = data.creator_email;

-- Ten tasks with varied states, due dates, assignees, and creation months.
INSERT INTO saas.tasks
    (tenant_id, project_id, assignee_user_id, title, description, status, priority, due_date, created_at)
SELECT t.tenant_id, p.project_id, u.user_id, data.title, data.description,
       data.status, data.priority, data.due_date::date, data.created_at::timestamptz
FROM (VALUES
    ('acme-design', 'WEB', 'alice@example.com', 'Create landing page', 'Implement the responsive landing page.', 'in_progress', 'high',   '2026-11-10', '2026-08-03 09:00:00+05:30'),
    ('acme-design', 'WEB', 'bob@example.com',   'Build navigation', 'Create shared site navigation components.', 'todo', 'medium', '2026-11-15', '2026-08-12 11:00:00+05:30'),
    ('acme-design', 'WEB', 'bob@example.com',   'Complete accessibility audit', 'Review accessibility and record remediation.', 'done', 'medium', '2026-09-18', '2026-08-20 14:00:00+05:30'),
    ('acme-design', 'WEB', 'alice@example.com', 'Document responsive breakpoints', 'Record responsive layout rules.', 'todo', 'low', '2026-11-17', '2026-08-25 10:00:00+05:30'),
    ('acme-design', 'MOB', NULL,                'Review offline sync', 'Document offline synchronization edge cases.', 'blocked', 'urgent', '2026-09-20', '2026-09-02 10:00:00+05:30'),
    ('bluebird-labs', 'DATA', 'carla@example.com', 'Define event metrics', 'Agree on dashboard event definitions.', 'in_progress', 'high', '2026-11-08', '2026-09-16 09:30:00+00'),
    ('bluebird-labs', 'DATA', 'daniel@example.com', 'Draft data dictionary', 'Document analytics fields and types.', 'todo', 'low', '2026-11-18', '2026-10-05 13:00:00+00'),
    ('bluebird-labs', 'DATA', 'carla@example.com', 'Validate dashboard filters', 'Verify filter behavior against sample metrics.', 'done', 'medium', '2026-10-14', '2026-10-08 15:00:00+00'),
    ('bluebird-labs', 'OPS', 'carla@example.com', 'Close legacy dashboard', 'Record sign-off for the legacy dashboard.', 'done', 'low', '2026-10-05', '2026-10-03 10:00:00+00'),
    ('bluebird-labs', 'OPS', 'carla@example.com', 'Archive legacy dashboard', 'Archive the completed dashboard workspace.', 'done', 'low', '2026-10-12', '2026-10-10 10:00:00+00')
) AS data(tenant_slug, project_key, assignee_email, title, description, status, priority, due_date, created_at)
JOIN saas.tenants t ON t.tenant_slug = data.tenant_slug
JOIN saas.projects p ON p.tenant_id = t.tenant_id AND p.project_key = data.project_key
LEFT JOIN saas.users u ON u.email = data.assignee_email;

INSERT INTO saas.tags (tenant_id, tag_name, color)
SELECT t.tenant_id, data.tag_name, data.color
FROM (VALUES
    ('acme-design', 'frontend', '#2563EB'),
    ('acme-design', 'launch', '#16A34A'),
    ('acme-design', 'backend', '#9333EA'),
    ('bluebird-labs', 'analytics', '#EA580C'),
    ('bluebird-labs', 'legacy', '#64748B')
) AS data(tenant_slug, tag_name, color)
JOIN saas.tenants t ON t.tenant_slug = data.tenant_slug;

-- Mobile Companion App intentionally has no tag and only blocked work;
-- Operations Archive has tags but only completed tasks. This demonstrates both
-- unmatched sides of the FULL OUTER JOIN example in query 03.
INSERT INTO saas.project_tags (tenant_id, project_id, tag_id)
SELECT t.tenant_id, p.project_id, tag.tag_id
FROM (VALUES
    ('acme-design', 'WEB', 'frontend'),
    ('acme-design', 'WEB', 'launch'),
    ('acme-design', 'WEB', 'backend'),
    ('bluebird-labs', 'DATA', 'analytics'),
    ('bluebird-labs', 'OPS', 'legacy')
) AS data(tenant_slug, project_key, tag_name)
JOIN saas.tenants t ON t.tenant_slug = data.tenant_slug
JOIN saas.projects p ON p.tenant_id = t.tenant_id AND p.project_key = data.project_key
JOIN saas.tags tag ON tag.tenant_id = t.tenant_id AND tag.tag_name = data.tag_name;

COMMIT;
