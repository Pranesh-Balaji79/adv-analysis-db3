-- Query 7: Which tasks are assigned to tenant members, with project and tenant context?
-- Business question: list assigned tasks with their tenant, project, priority, status, and assignee.
-- INNER JOINs intentionally require a valid project, tenant, user, and membership row.
SELECT
    tenant.tenant_slug,
    project.project_key,
    project.project_name,
    task.title AS task_title,
    task.status,
    task.priority,
    assignee.display_name AS assignee,
    task.due_date
FROM saas.tasks AS task
INNER JOIN saas.projects AS project
  ON project.tenant_id = task.tenant_id
 AND project.project_id = task.project_id
INNER JOIN saas.tenants AS tenant
  ON tenant.tenant_id = task.tenant_id
INNER JOIN saas.tenant_memberships AS membership
  ON membership.tenant_id = task.tenant_id
 AND membership.user_id = task.assignee_user_id
INNER JOIN saas.users AS assignee
  ON assignee.user_id = membership.user_id
ORDER BY tenant.tenant_slug, project.project_key, task.due_date, task.title;


-- Query 8: Which projects have few/no tasks or tags?
-- Business question: show every project, including projects without task or tag records.
-- The task and tag subqueries are aggregated before joining to avoid multiplying counts across a many-to-many join.
SELECT
    tenant.tenant_slug,
    project.project_key,
    project.project_name,
    COALESCE(task_summary.task_count, 0) AS task_count,
    COALESCE(task_summary.open_task_count, 0) AS open_task_count,
    COALESCE(tag_summary.tag_count, 0) AS tag_count
FROM saas.projects AS project
JOIN saas.tenants AS tenant
  ON tenant.tenant_id = project.tenant_id
LEFT JOIN (
    SELECT
        tenant_id,
        project_id,
        COUNT(*) AS task_count,
        COUNT(*) FILTER (WHERE status NOT IN ('done', 'cancelled')) AS open_task_count
    FROM saas.tasks
    GROUP BY tenant_id, project_id
) AS task_summary
  ON task_summary.tenant_id = project.tenant_id
 AND task_summary.project_id = project.project_id
LEFT JOIN (
    SELECT tenant_id, project_id, COUNT(*) AS tag_count
    FROM saas.project_tags
    GROUP BY tenant_id, project_id
) AS tag_summary
  ON tag_summary.tenant_id = project.tenant_id
 AND tag_summary.project_id = project.project_id
ORDER BY tenant.tenant_slug, project.project_key;


-- Query 9: Reconcile projects with open work against projects with tags.
-- Business question: identify projects that have open tasks but no tags, tags but no open tasks, or both.
-- FULL OUTER JOIN preserves unmatched rows from either independently aggregated subquery.
WITH open_task_metrics AS (
    SELECT tenant_id, project_id, COUNT(*) AS open_task_count
    FROM saas.tasks
    WHERE status IN ('todo', 'in_progress', 'blocked')
    GROUP BY tenant_id, project_id
), tag_metrics AS (
    SELECT tenant_id, project_id, COUNT(*) AS tag_count
    FROM saas.project_tags
    GROUP BY tenant_id, project_id
), project_reconciliation AS (
    SELECT
        COALESCE(open_tasks.tenant_id, tagged.tenant_id) AS tenant_id,
        COALESCE(open_tasks.project_id, tagged.project_id) AS project_id,
        open_tasks.open_task_count,
        tagged.tag_count
    FROM open_task_metrics AS open_tasks
    FULL OUTER JOIN tag_metrics AS tagged
      ON tagged.tenant_id = open_tasks.tenant_id
     AND tagged.project_id = open_tasks.project_id
)
SELECT
    tenant.tenant_slug,
    project.project_key,
    project.project_name,
    COALESCE(reconciliation.open_task_count, 0) AS open_task_count,
    COALESCE(reconciliation.tag_count, 0) AS tag_count,
    CASE
        WHEN reconciliation.open_task_count IS NULL THEN 'tags only; no open tasks'
        WHEN reconciliation.tag_count IS NULL THEN 'open tasks only; no tags'
        ELSE 'both open tasks and tags'
    END AS reconciliation_status
FROM project_reconciliation AS reconciliation
JOIN saas.projects AS project
  ON project.tenant_id = reconciliation.tenant_id
 AND project.project_id = reconciliation.project_id
JOIN saas.tenants AS tenant
  ON tenant.tenant_id = reconciliation.tenant_id
ORDER BY tenant.tenant_slug, project.project_key;


-- Query 10: Which projects carry a higher-than-average workload for their tenant?
-- Business question: return projects whose task count exceeds the mean task count of that tenant's projects.
-- A reusable CTE calculates each project's count once; the correlated scalar subquery computes its tenant average.
WITH project_task_counts AS (
    SELECT
        project.tenant_id,
        project.project_id,
        project.project_key,
        project.project_name,
        COUNT(task.task_id) AS task_count
    FROM saas.projects AS project
    LEFT JOIN saas.tasks AS task
      ON task.tenant_id = project.tenant_id
     AND task.project_id = project.project_id
    GROUP BY project.tenant_id, project.project_id, project.project_key, project.project_name
)
SELECT
    tenant.tenant_slug,
    current_project.project_key,
    current_project.project_name,
    current_project.task_count,
    (
        SELECT AVG(other_project.task_count::numeric)
        FROM project_task_counts AS other_project
        WHERE other_project.tenant_id = current_project.tenant_id
    ) AS tenant_avg_tasks_per_project
FROM project_task_counts AS current_project
JOIN saas.tenants AS tenant USING (tenant_id)
WHERE current_project.task_count > (
    SELECT AVG(other_project.task_count::numeric)
    FROM project_task_counts AS other_project
    WHERE other_project.tenant_id = current_project.tenant_id
)
ORDER BY tenant.tenant_slug, current_project.task_count DESC, current_project.project_key;
