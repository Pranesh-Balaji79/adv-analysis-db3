# Expected Results and Local Verification

## Seed baseline

On a fresh run with the included fixture, expected row counts are:

| Table | Expected rows |
|---|---:|
| `saas.tenants` | 2 |
| `saas.tenant_settings` | 2 |
| `saas.users` | 4 |
| `saas.tenant_memberships` | 5 |
| `saas.projects` | 4 |
| `saas.tasks` | 10 |
| `saas.tags` | 5 |
| `saas.project_tags` | 5 |

## Sanity checks

- Query 1 (`project delivery health`) should return four project rows.
- Query 2 (`tenant workload`) should return two tenant rows.
- Query 3 (`weekly due-date calendar`) should return 16 rows: 8 weeks for each of 2 tenants.
- Query 4 (rankings) should return 4 project rows, partitioned by tenant.
- Query 5 (assignee sequencing) includes assigned tasks only; the one unassigned task is intentionally omitted.
- Query 6 should return multiple monthly rows for each tenant because seeded `created_at` values span August, September, and October 2026.
- Query 8 preserves every project even if no task/tag aggregate exists.
- Query 9 should include `Mobile Companion App` as “open tasks only; no tags” and `Operations Archive` as “tags only; no open tasks”.
- Query 10 returns projects whose task counts are above their own tenant's project-average.

## Integrity tests

`tests/verify_constraints.sql` prints PASS notices for duplicate membership, cross-tenant tag association, cross-tenant assignee, invalid status, orphan membership, cascading project-key update, and cascading project deletion. These checks use exception blocks, so a matching constraint violation is considered a pass.

The project has not been claimed as executed on a local PostgreSQL server here. Run `tests/run_all.sql` and capture the real terminal output before sharing evidence with an instructor or mentor. Exact weekly counts are date-sensitive because the calendar query starts from `CURRENT_DATE`; the seeded task values are dated in 2026.
