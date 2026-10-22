-- Query 4: Which projects lead each tenant in completed work?
-- Business question: compare ROW_NUMBER(), RANK(), and DENSE_RANK() for project completion counts.
-- ROW_NUMBER always assigns a unique ordinal; RANK leaves gaps after ties; DENSE_RANK does not.
WITH project_completion AS (
    SELECT
        project.tenant_id,
        project.project_id,
        project.project_key,
        project.project_name,
        COUNT(task.task_id) AS total_tasks,
        COUNT(task.task_id) FILTER (WHERE task.status = 'done') AS completed_tasks
    FROM saas.projects AS project
    LEFT JOIN saas.tasks AS task
      ON task.tenant_id = project.tenant_id
     AND task.project_id = project.project_id
    GROUP BY project.tenant_id, project.project_id, project.project_key, project.project_name
)
SELECT
    tenant.tenant_slug,
    completion.project_key,
    completion.project_name,
    completion.total_tasks,
    completion.completed_tasks,
    ROW_NUMBER() OVER (
        PARTITION BY completion.tenant_id
        ORDER BY completion.completed_tasks DESC, completion.project_name
    ) AS row_num,
    RANK() OVER (
        PARTITION BY completion.tenant_id
        ORDER BY completion.completed_tasks DESC
    ) AS completion_rank,
    DENSE_RANK() OVER (
        PARTITION BY completion.tenant_id
        ORDER BY completion.completed_tasks DESC
    ) AS dense_completion_rank
FROM project_completion AS completion
JOIN saas.tenants AS tenant USING (tenant_id)
ORDER BY tenant.tenant_slug, completion_rank, completion.project_name;


-- Query 5: What are the previous and next assigned tasks for each team member?
-- Business question: show task due-date sequence using LAG() and LEAD() within each tenant and assignee.
-- Unassigned tasks are intentionally omitted because they cannot be ordered within a person's workload.
SELECT
    tenant.tenant_slug,
    assignee.display_name AS assignee,
    project.project_key,
    task.title AS task_title,
    task.due_date,
    LAG(task.title) OVER task_sequence AS previous_task,
    LAG(task.due_date) OVER task_sequence AS previous_due_date,
    LEAD(task.title) OVER task_sequence AS next_task,
    LEAD(task.due_date) OVER task_sequence AS next_due_date
FROM saas.tasks AS task
JOIN saas.projects AS project
  ON project.tenant_id = task.tenant_id
 AND project.project_id = task.project_id
JOIN saas.tenants AS tenant
  ON tenant.tenant_id = task.tenant_id
JOIN saas.users AS assignee
  ON assignee.user_id = task.assignee_user_id
WINDOW task_sequence AS (
    PARTITION BY task.tenant_id, task.assignee_user_id
    ORDER BY task.due_date NULLS LAST, task.created_at, task.task_id
)
ORDER BY tenant.tenant_slug, assignee.display_name, task.due_date, task.task_id;


-- Query 6: How does task creation accumulate over time for each tenant?
-- Business question: calculate monthly task creation and a cumulative running total per tenant.
-- Historical created_at values in the fixture span August, September, and October 2026.
WITH monthly_task_creation AS (
    SELECT
        tenant_id,
        date_trunc('month', created_at)::date AS month_start,
        COUNT(*) AS tasks_created
    FROM saas.tasks
    GROUP BY tenant_id, date_trunc('month', created_at)::date
)
SELECT
    tenant.tenant_slug,
    monthly.month_start,
    monthly.tasks_created,
    SUM(monthly.tasks_created) OVER (
        PARTITION BY monthly.tenant_id
        ORDER BY monthly.month_start
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_tasks_created
FROM monthly_task_creation AS monthly
JOIN saas.tenants AS tenant USING (tenant_id)
ORDER BY tenant.tenant_slug, monthly.month_start;
