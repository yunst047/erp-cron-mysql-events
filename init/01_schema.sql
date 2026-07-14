-- =====================================================
-- ERP Schema (MySQL 8) — master data + transactions
-- + tables maintained by EVENT scheduler
-- =====================================================

-- ---------- Master data ----------

CREATE TABLE departments (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL UNIQUE,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE employees (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  department_id INT NOT NULL,
  first_name    VARCHAR(100) NOT NULL,
  last_name     VARCHAR(100) NOT NULL,
  email         VARCHAR(255) NOT NULL UNIQUE,
  position      VARCHAR(100),
  salary        DECIMAL(12,2) NOT NULL DEFAULT 0,
  hired_at      DATE,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT fk_emp_dept FOREIGN KEY (department_id) REFERENCES departments(id)
);

CREATE TABLE customers (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  code        VARCHAR(20) NOT NULL UNIQUE,
  name        VARCHAR(200) NOT NULL,
  email       VARCHAR(255),
  phone       VARCHAR(50),
  credit_limit DECIMAL(14,2) NOT NULL DEFAULT 0,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE suppliers (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  code        VARCHAR(20) NOT NULL UNIQUE,
  name        VARCHAR(200) NOT NULL,
  email       VARCHAR(255),
  phone       VARCHAR(50),
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_categories (
  id    INT AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE products (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  category_id   INT NOT NULL,
  sku           VARCHAR(50) NOT NULL UNIQUE,
  name          VARCHAR(200) NOT NULL,
  unit_price    DECIMAL(12,2) NOT NULL,
  cost_price    DECIMAL(12,2) NOT NULL,
  reorder_level INT NOT NULL DEFAULT 10,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT fk_prod_cat FOREIGN KEY (category_id) REFERENCES product_categories(id)
);

CREATE TABLE inventory (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  product_id  INT NOT NULL,
  warehouse   VARCHAR(50) NOT NULL DEFAULT 'MAIN',
  quantity    INT NOT NULL DEFAULT 0,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_inv (product_id, warehouse),
  CONSTRAINT fk_inv_prod FOREIGN KEY (product_id) REFERENCES products(id)
);

-- ---------- Transactions ----------

CREATE TABLE sales_orders (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  order_no     VARCHAR(30) NOT NULL UNIQUE,
  customer_id  INT NOT NULL,
  status       ENUM('draft','confirmed','shipped','completed','cancelled') NOT NULL DEFAULT 'confirmed',
  order_date   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  currency     CHAR(3) NOT NULL DEFAULT 'THB',
  total_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  CONSTRAINT fk_so_cust FOREIGN KEY (customer_id) REFERENCES customers(id),
  INDEX idx_so_date (order_date)
);

CREATE TABLE sales_order_items (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  order_id    INT NOT NULL,
  product_id  INT NOT NULL,
  quantity    INT NOT NULL,
  unit_price  DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_soi_order FOREIGN KEY (order_id) REFERENCES sales_orders(id),
  CONSTRAINT fk_soi_prod  FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE purchase_orders (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  po_no        VARCHAR(30) NOT NULL UNIQUE,
  supplier_id  INT NOT NULL,
  status       ENUM('draft','sent','received','cancelled') NOT NULL DEFAULT 'sent',
  order_date   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  CONSTRAINT fk_po_sup FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
);

CREATE TABLE purchase_order_items (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  po_id       INT NOT NULL,
  product_id  INT NOT NULL,
  quantity    INT NOT NULL,
  unit_cost   DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_poi_po   FOREIGN KEY (po_id) REFERENCES purchase_orders(id),
  CONSTRAINT fk_poi_prod FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE invoices (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  invoice_no  VARCHAR(30) NOT NULL UNIQUE,
  order_id    INT NOT NULL,
  issue_date  DATE NOT NULL,
  due_date    DATE NOT NULL,
  amount      DECIMAL(14,2) NOT NULL,
  status      ENUM('pending','paid','overdue','cancelled') NOT NULL DEFAULT 'pending',
  CONSTRAINT fk_inv_order FOREIGN KEY (order_id) REFERENCES sales_orders(id),
  INDEX idx_inv_status_due (status, due_date)
);

CREATE TABLE payments (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id  INT NOT NULL,
  paid_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  amount      DECIMAL(14,2) NOT NULL,
  method      ENUM('transfer','credit_card','cash','cheque') NOT NULL DEFAULT 'transfer',
  CONSTRAINT fk_pay_inv FOREIGN KEY (invoice_id) REFERENCES invoices(id)
);

-- ---------- Tables maintained by the EVENT scheduler ----------

-- seeded every minute by ev_update_exchange_rates (keeps history)
CREATE TABLE exchange_rates (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  base_currency  CHAR(3) NOT NULL,
  quote_currency CHAR(3) NOT NULL,
  rate           DECIMAL(18,6) NOT NULL,
  fetched_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_fx_pair_time (base_currency, quote_currency, fetched_at)
);

-- upserted by ev_daily_sales_summary
CREATE TABLE daily_sales_summary (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  summary_date    DATE NOT NULL UNIQUE,
  total_orders    INT NOT NULL DEFAULT 0,
  total_revenue   DECIMAL(16,2) NOT NULL DEFAULT 0,
  avg_order_value DECIMAL(16,2) NOT NULL DEFAULT 0,
  generated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- inserted by ev_check_low_stock
CREATE TABLE stock_alerts (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  product_id    INT NOT NULL,
  warehouse     VARCHAR(50) NOT NULL,
  current_qty   INT NOT NULL,
  reorder_level INT NOT NULL,
  alert_status  ENUM('open','resolved') NOT NULL DEFAULT 'open',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_alert_prod FOREIGN KEY (product_id) REFERENCES products(id)
);

-- every event writes here — check this table to verify events are firing
CREATE TABLE cron_job_logs (
  id       INT AUTO_INCREMENT PRIMARY KEY,
  job_name VARCHAR(100) NOT NULL,
  run_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status   ENUM('success','error') NOT NULL DEFAULT 'success',
  message  VARCHAR(500),
  INDEX idx_log_job_time (job_name, run_at)
);
