-- =====================================================
-- MySQL EVENT scheduler jobs
-- Requires event_scheduler=ON (already set via docker-compose command)
-- Check status: SHOW VARIABLES LIKE 'event_scheduler'; SHOW EVENTS;
--
-- NOTE: demo schedules are aggressive (every 1 min) so you can
-- watch them fire — production schedules noted per event.
-- =====================================================

DELIMITER $$

-- -----------------------------------------------------
-- 1) Seed exchange rates every minute
--    (simulates an external FX feed: random walk ±0.5% from the latest
--    rate of each currency pair)
--    production: EVERY 1 HOUR
-- -----------------------------------------------------
CREATE EVENT ev_update_exchange_rates
ON SCHEDULE EVERY 1 MINUTE
STARTS CURRENT_TIMESTAMP + INTERVAL 1 MINUTE
COMMENT 'Seed a new FX rate row per currency pair (random walk)'
DO
BEGIN
  INSERT INTO exchange_rates (base_currency, quote_currency, rate, fetched_at)
  SELECT t.base_currency, t.quote_currency,
         ROUND(t.rate * (1 + ((RAND() - 0.5) * 0.01)), 6),
         NOW()
  FROM (
    SELECT er.base_currency, er.quote_currency, er.rate
    FROM exchange_rates er
    JOIN (
      SELECT base_currency AS b, quote_currency AS q, MAX(fetched_at) AS m
      FROM exchange_rates
      GROUP BY base_currency, quote_currency
    ) latest
      ON  er.base_currency  = latest.b
      AND er.quote_currency = latest.q
      AND er.fetched_at     = latest.m
  ) t;

  INSERT INTO cron_job_logs (job_name, status, message)
  VALUES ('ev_update_exchange_rates', 'success',
          CONCAT('seeded ', ROW_COUNT(), ' new rate rows'));
END$$

-- -----------------------------------------------------
-- 2) Upsert daily sales summary
--    production: EVERY 1 DAY STARTS ... 01:00 (summarizing yesterday)
--    demo: every minute over recent days so you can watch numbers move
-- -----------------------------------------------------
CREATE EVENT ev_daily_sales_summary
ON SCHEDULE EVERY 1 MINUTE
STARTS CURRENT_TIMESTAMP + INTERVAL 1 MINUTE
COMMENT 'Aggregate sales_orders into daily_sales_summary (upsert)'
DO
BEGIN
  INSERT INTO daily_sales_summary (summary_date, total_orders, total_revenue, avg_order_value)
  SELECT DATE(order_date),
         COUNT(*),
         COALESCE(SUM(total_amount), 0),
         COALESCE(AVG(total_amount), 0)
  FROM sales_orders
  WHERE status <> 'cancelled'
    AND order_date >= CURDATE() - INTERVAL 7 DAY
  GROUP BY DATE(order_date)
  ON DUPLICATE KEY UPDATE
    total_orders    = VALUES(total_orders),
    total_revenue   = VALUES(total_revenue),
    avg_order_value = VALUES(avg_order_value);

  INSERT INTO cron_job_logs (job_name, status, message)
  VALUES ('ev_daily_sales_summary', 'success', 'summary upserted for last 7 days');
END$$

-- -----------------------------------------------------
-- 3) Mark overdue invoices
--    production: EVERY 1 DAY STARTS ... 00:30
-- -----------------------------------------------------
CREATE EVENT ev_mark_overdue_invoices
ON SCHEDULE EVERY 1 MINUTE
STARTS CURRENT_TIMESTAMP + INTERVAL 1 MINUTE
COMMENT 'Flip pending invoices past due_date to overdue'
DO
BEGIN
  UPDATE invoices
  SET status = 'overdue'
  WHERE status = 'pending'
    AND due_date < CURDATE();

  INSERT INTO cron_job_logs (job_name, status, message)
  VALUES ('ev_mark_overdue_invoices', 'success',
          CONCAT(ROW_COUNT(), ' invoice(s) marked overdue'));
END$$

-- -----------------------------------------------------
-- 4) Low-stock alerts
--    production: EVERY 1 HOUR
-- -----------------------------------------------------
CREATE EVENT ev_check_low_stock
ON SCHEDULE EVERY 1 MINUTE
STARTS CURRENT_TIMESTAMP + INTERVAL 1 MINUTE
COMMENT 'Insert stock_alerts for items at/below reorder level (skip if open alert exists)'
DO
BEGIN
  INSERT INTO stock_alerts (product_id, warehouse, current_qty, reorder_level)
  SELECT i.product_id, i.warehouse, i.quantity, p.reorder_level
  FROM inventory i
  JOIN products p ON p.id = i.product_id
  WHERE i.quantity <= p.reorder_level
    AND p.is_active = TRUE
    AND NOT EXISTS (
      SELECT 1 FROM stock_alerts a
      WHERE a.product_id = i.product_id
        AND a.warehouse  = i.warehouse
        AND a.alert_status = 'open'
    );

  INSERT INTO cron_job_logs (job_name, status, message)
  VALUES ('ev_check_low_stock', 'success',
          CONCAT(ROW_COUNT(), ' new alert(s)'));
END$$

-- -----------------------------------------------------
-- 5) Housekeeping: trim old cron logs + old FX history
--    production: EVERY 1 DAY
-- -----------------------------------------------------
CREATE EVENT ev_cleanup
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP + INTERVAL 1 HOUR
COMMENT 'Delete cron logs older than 7 days and FX history older than 30 days'
DO
BEGIN
  DELETE FROM cron_job_logs  WHERE run_at    < NOW() - INTERVAL 7 DAY;
  DELETE FROM exchange_rates WHERE fetched_at < NOW() - INTERVAL 30 DAY;

  INSERT INTO cron_job_logs (job_name, status, message)
  VALUES ('ev_cleanup', 'success', 'old logs and fx history trimmed');
END$$

DELIMITER ;
