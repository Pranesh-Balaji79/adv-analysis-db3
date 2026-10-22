# Query Catalog

Every SQL query starts with a comment stating the business question it answers.

| Query | Business question | Main technique |
|---|---|---|
| 1 | How is each project performing, including overdue open tasks? | CTE, filtered aggregates, `LEFT JOIN` |
| 2 | Which tenant has more work and what is its average workload per project? | Multi-step CTE, aggregation |
| 3 | How much work is due in each of the next eight weeks, including empty weeks? | Recursive CTE, date spine, `CROSS JOIN`, `LEFT JOIN` |
| 4 | How do projects rank by completed tasks within their tenant? | `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()` |
| 5 | What is the prior and next due task for each assignee? | `LAG()`, `LEAD()`, named window |
| 6 | How many tasks were created per month and what is the cumulative total? | Monthly aggregate, running total with `SUM() OVER` |
| 7 | Which tasks are assigned to valid tenant members? | Multi-table `INNER JOIN` |
| 8 | Which projects have tasks/tags, including any with none? | `LEFT JOIN`, pre-aggregated subqueries |
| 9 | Which projects have open work only, tags only, or both? | `FULL OUTER JOIN` and reconciliation classification |
| 10 | Which projects have more tasks than their tenant's average project workload? | Correlated subquery, aggregation |

## Seed data designed to make the queries informative

- Two tenants with different workloads.
- Four projects, including a project with only completed tasks and a project with open tasks but no tags. These make both unmatched sides of the `FULL OUTER JOIN` example visible.
- Ten tasks with `todo`, `in_progress`, `blocked`, and `done` states, varying priorities and due dates.
- `created_at` timestamps span August, September, and October 2026 so the running-total query returns multiple periods.
- Some assignees have multiple tasks so `LAG()` and `LEAD()` return both prior and next rows.
