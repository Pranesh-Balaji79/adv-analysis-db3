-- Query 1: What is the delivery health of every project in each tenant?
-- Business question: show task volume, completed work, completion percentage, and overdue open tasks.
-- The first CTE aggregates tasks; the outer query preserves projects with no tasks via LEFT JOIN.
WITH task_metrics AS (
    SELECT
        tenant_id,
        project_id,
        COUNT(*) AS total_tasks,
        COUNT(*) FILTER (WHERE status = 'done') AS completed_tasks,
        COUNT(*) FILTER (
            WHERE due_date < CURRENT_DATE
              AND status NOT IN ('done', 'cancelled')
        ) AS overdue_open_tasks
    FROM saas.tasks
    GROUP BY tenant_id, project_id
)
SELECT
    tenant.tenant_slug,
    project.project_key,
    project.project_name,
    COALESCE(metrics.total_tasks, 0) AS total_tasks,
    COALESCE(metrics.completed_tasks, 0) AS completed_tasks,
    COALESCE(
        ROUND(100.0 * metrics.completed_tasks / NULLIF(metrics.total_tasks, 0), 1),
        0.0
    ) AS completion_pct,
    COALESCE(metrics.overdue_open_tasks, 0) AS overdue_open_tasks
FROM saas.projects AS project
JOIN saas.tenants AS tenant
  ON tenant.tenant_id = project.tenant_id
LEFT JOIN task_metrics AS metrics
  ON metrics.tenant_id = project.tenant_id
 AND metrics.project_id = project.project_id
ORDER BY tenant.tenant_slug, project.project_key;


-- Query 2: Which tenants have the largest workload and how many tasks remain open?
-- Business question: compare each tenant's project count, task count, completed tasks, and open tasks.
-- A multi-step CTE keeps project-level and tenant-level aggregation separate and avoids join fan-out.
WITH project_task_totals AS (
    SELECT
        project.tenant_id,
        project.project_id,
        COUNT(task.task_id) AS task_count,
        COUNT(task.task_id) FILTER (WHERE task.status = 'done') AS completed_count,
        COUNT(task.task_id) FILTER (
            WHERE task.status NOT IN ('done', 'cancelled')
        ) AS open_count
    FROM saas.projects AS project
    LEFT JOIN saas.tasks AS task
      ON task.tenant_id = project.tenant_id
     AND task.project_id = project.project_id
    GROUP BY project.tenant_id, project.project_id
), tenant_rollup AS (
    SELECT
        tenant_id,
        COUNT(*) AS project_count,
        SUM(task_count) AS task_count,
        SUM(completed_count) AS completed_count,
        SUM(open_count) AS open_count,
        ROUND(AVG(task_count::numeric), 2) AS avg_tasks_per_project
    FROM project_task_totals
    GROUP BY tenant_id
)
SELECT
    tenant.tenant_slug,
    tenant.display_name,
    rollup.project_count,
    rollup.task_count,
    rollup.completed_count,
    rollup.open_count,
    rollup.avg_tasks_per_project
FROM tenant_rollup AS rollup
JOIN saas.tenants AS tenant USING (tenant_id)
ORDER BY rollup.open_count DESC, tenant.tenant_slug;


-- Query 3: What tasks are due in each of the next eight calendar weeks?
-- Business question: create a weekly due-date series, including weeks with zero due tasks.
-- This recursive CTE generates week starts; CROSS JOIN provides every tenant/week combination.
WITH RECURSIVE calendar_weeks AS (
    SELECT date_trunc('week', CURRENT_DATE)::date AS week_start, 1 AS week_number
    UNION ALL
    SELECT week_start + 7, week_number + 1
    FROM calendar_weeks
    WHERE week_number < 8
)
SELECT
    tenant.tenant_slug,
    calendar.week_number,
    calendar.week_start,
    calendar.week_start + 6 AS week_end,
    COUNT(task.task_id) AS tasks_due
FROM saas.tenants AS tenant
CROSS JOIN calendar_weeks AS calendar
LEFT JOIN saas.tasks AS task
  ON task.tenant_id = tenant.tenant_id
 AND task.due_date >= calendar.week_start
 AND task.due_date < calendar.week_start + 7
GROUP BY tenant.tenant_slug, calendar.week_number, calendar.week_start
ORDER BY tenant.tenant_slug, calendar.week_number;
