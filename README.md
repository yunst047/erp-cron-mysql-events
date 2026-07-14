# ERP Cron Demo — MySQL Event Scheduler

ERP schema บน MySQL 8 ใช้ **built-in Event Scheduler** (`CREATE EVENT`) update/seed ข้อมูล — ไม่ต้องมี service ภายนอกเลย logic ทั้งหมดอยู่ใน DB

## Run

```bash
docker compose up -d
```

Init scripts รันตามลำดับ: `01_schema.sql` → `02_seed.sql` → `03_events.sql`
Event scheduler เปิดผ่าน `command: --event-scheduler=ON` ใน compose

## Events

| Event | Demo schedule | Production | ทำอะไร |
|---|---|---|---|
| `ev_update_exchange_rates` | 1 min | 1 hour | seed FX rate ใหม่ต่อคู่เงิน (random walk ±0.5%) เก็บ history |
| `ev_daily_sales_summary` | 1 min | daily 01:00 | upsert ยอดขายรวมรายวันลง `daily_sales_summary` |
| `ev_mark_overdue_invoices` | 1 min | daily 00:30 | `pending` → `overdue` เมื่อเลย due date |
| `ev_check_low_stock` | 1 min | 1 hour | insert `stock_alerts` เมื่อ stock ≤ reorder level |
| `ev_cleanup` | 1 hour | daily | ลบ log เก่า 7 วัน / FX history เก่า 30 วัน |

## Verify ว่า cron วิ่งจริง

```bash
docker exec -it erp-mysql-events mysql -uerp -perp erp
```

```sql
SHOW VARIABLES LIKE 'event_scheduler';   -- ต้องเป็น ON
SHOW EVENTS;                             -- เห็น 5 events

-- รอ ~1 นาทีแล้วดู
SELECT * FROM cron_job_logs ORDER BY run_at DESC LIMIT 10;
SELECT * FROM exchange_rates ORDER BY fetched_at DESC LIMIT 8;
SELECT * FROM invoices WHERE status = 'overdue';     -- INV-1001, INV-1003 โดน flip
SELECT * FROM stock_alerts;                          -- product 2 (qty 6 ≤ 10), 7 (qty 12 ≤ 25)
SELECT * FROM daily_sales_summary;
```

## ข้อควรรู้

- Event หายถ้า `event_scheduler=OFF` ตอน restart → ตั้งใน config/command เสมอ ไม่ใช่ `SET GLOBAL`
- Event รันด้วยสิทธิ์ของ definer — ระวังตอน migrate ระหว่าง server
- ไม่มี retry/backoff ในตัว — ถ้า statement fail จะเงียบ (ดูได้จาก `performance_schema.events_errors` หรือ error log) จึงให้ทุก event เขียน `cron_job_logs` ไว้ตรวจ


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
