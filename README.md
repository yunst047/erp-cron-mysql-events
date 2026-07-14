# ERP Cron Demo — MySQL Event Scheduler

ERP schema on MySQL 8 using the **built-in Event Scheduler** (`CREATE EVENT`) to update/seed data on a schedule — no external service required, all logic lives inside the database.

## Run

```bash
docker compose up -d
```

Init scripts run in order: `01_schema.sql` → `02_seed.sql` → `03_events.sql`
The event scheduler is enabled via `command: --event-scheduler=ON` in the compose file.

## Events

| Event | Demo schedule | Production | What it does |
|---|---|---|---|
| `ev_update_exchange_rates` | 1 min | 1 hour | Seeds a new FX rate per currency pair (random walk ±0.5%), keeps history |
| `ev_daily_sales_summary` | 1 min | daily 01:00 | Upserts daily sales totals into `daily_sales_summary` |
| `ev_mark_overdue_invoices` | 1 min | daily 00:30 | Flips `pending` → `overdue` once past the due date |
| `ev_check_low_stock` | 1 min | 1 hour | Inserts `stock_alerts` when stock ≤ reorder level |
| `ev_cleanup` | 1 hour | daily | Deletes logs older than 7 days / FX history older than 30 days |

## Verify the events are firing

```bash
docker exec -it erp-mysql-events mysql -uerp -perp erp
```

```sql
SHOW VARIABLES LIKE 'event_scheduler';   -- must be ON
SHOW EVENTS;                             -- should list 5 events

-- wait ~1 minute, then:
SELECT * FROM cron_job_logs ORDER BY run_at DESC LIMIT 10;
SELECT * FROM exchange_rates ORDER BY fetched_at DESC LIMIT 8;
SELECT * FROM invoices WHERE status = 'overdue';     -- INV-1001, INV-1003 get flipped
SELECT * FROM stock_alerts;                          -- product 2 (qty 6 ≤ 10), 7 (qty 12 ≤ 25), ...
SELECT * FROM daily_sales_summary;
```

## Things to know

- Events stop firing if `event_scheduler=OFF` after a restart → always set it in config/command, never via `SET GLOBAL` alone
- Events run with the definer's privileges — watch out when migrating between servers
- No built-in retry/backoff — a failing statement fails silently (visible in `performance_schema.events_errors` or the error log), which is why every event also writes to `cron_job_logs`

---

## About this demo

This repo is part of the **ERP Cron DB** demo series — one shared ERP schema (master data, sales/purchase orders, invoices, payments) implemented three ways to compare strategies for letting scheduled jobs update/seed data directly in the database (FX rates, daily sales summaries, overdue invoice flagging, low-stock alerts):

| Repo | Engine | Scheduler |
|---|---|---|
| [erp-cron-mysql-events](https://github.com/yunst047/erp-cron-mysql-events) | MySQL 8 | `CREATE EVENT` (built-in) |
| [erp-cron-postgres-pgcron](https://github.com/yunst047/erp-cron-postgres-pgcron) | PostgreSQL 16 | `pg_cron` extension |
| [erp-cron-postgres-go](https://github.com/yunst047/erp-cron-postgres-go) | PostgreSQL 16 | Go service (`robfig/cron`) |

Every job writes to a `cron_job_logs` table, and each stack was spun up and verified end-to-end (jobs firing, data changing as expected) before publishing.

> 🤖 Built and tested entirely by [Claude Code](https://claude.com/claude-code) (Claude Fable 5) — schema design, seed data, cron jobs, Docker setup, and live verification.
