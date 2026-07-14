-- =====================================================
-- Seed data — dates are relative to NOW() so the cron
-- jobs always have fresh data to work with
-- =====================================================

INSERT INTO departments (name) VALUES
  ('Sales'), ('Warehouse'), ('Finance');

INSERT INTO employees (department_id, first_name, last_name, email, position, salary, hired_at) VALUES
  (1, 'Somchai', 'Jaidee',    'somchai@erp.local', 'Sales Manager',     65000, '2022-03-01'),
  (1, 'Nida',    'Suksawat',  'nida@erp.local',    'Account Executive', 42000, '2023-06-15'),
  (2, 'Prasert', 'Wongsa',    'prasert@erp.local', 'Warehouse Lead',    38000, '2021-11-01'),
  (3, 'Kanya',   'Thongchai', 'kanya@erp.local',   'Accountant',        45000, '2022-08-20');

INSERT INTO customers (code, name, email, phone, credit_limit) VALUES
  ('CUST-001', 'Bangkok Retail Co., Ltd.', 'ap@bkkretail.co.th',  '02-111-1111', 500000),
  ('CUST-002', 'Chiang Mai Trading',       'buy@cmtrading.co.th', '053-222-222', 300000),
  ('CUST-003', 'Phuket Hospitality Group', 'proc@phg.co.th',      '076-333-333', 800000),
  ('CUST-004', 'Isaan Wholesale',          'order@isaanws.co.th', '044-444-444', 200000),
  ('CUST-005', 'Siam Mega Store',          'po@siammega.co.th',   '02-555-5555', 1000000);

INSERT INTO suppliers (code, name, email, phone) VALUES
  ('SUP-001', 'Thai Electronics Import',  'sales@thaielec.co.th', '02-666-6666'),
  ('SUP-002', 'Global Office Supply',     'cs@globaloffice.com',  '02-777-7777'),
  ('SUP-003', 'Eastern Packaging',        'info@eastpack.co.th',  '038-888-888');

INSERT INTO product_categories (name) VALUES
  ('Electronics'), ('Office Supplies'), ('Packaging');

INSERT INTO products (category_id, sku, name, unit_price, cost_price, reorder_level) VALUES
  (1, 'ELEC-001', 'Wireless Barcode Scanner',   3500.00, 2200.00, 15),
  (1, 'ELEC-002', 'Thermal Receipt Printer',    4900.00, 3100.00, 10),
  (1, 'ELEC-003', 'POS Tablet 10"',            12500.00, 8900.00,  8),
  (2, 'OFFC-001', 'A4 Paper (500 sheets)',        120.00,   85.00, 100),
  (2, 'OFFC-002', 'Ink Cartridge Black',          650.00,  420.00,  30),
  (3, 'PACK-001', 'Carton Box M (50 pcs)',        450.00,  280.00,  40),
  (3, 'PACK-002', 'Bubble Wrap Roll 50m',         380.00,  240.00,  25),
  (3, 'PACK-003', 'Packing Tape (12 rolls)',      290.00,  180.00,  60);

-- some rows intentionally below reorder_level so ev_check_low_stock fires
INSERT INTO inventory (product_id, warehouse, quantity) VALUES
  (1, 'MAIN', 42), (2, 'MAIN', 6), (3, 'MAIN', 20),
  (4, 'MAIN', 75), (5, 'MAIN', 120), (6, 'MAIN', 33),
  (7, 'MAIN', 12), (8, 'MAIN', 200);

INSERT INTO sales_orders (order_no, customer_id, status, order_date, total_amount) VALUES
  ('SO-1001', 1, 'completed', NOW() - INTERVAL 3 DAY, 17500.00),
  ('SO-1002', 2, 'completed', NOW() - INTERVAL 2 DAY,  9800.00),
  ('SO-1003', 3, 'shipped',   NOW() - INTERVAL 1 DAY, 62500.00),
  ('SO-1004', 1, 'confirmed', NOW() - INTERVAL 1 DAY,   1200.00),
  ('SO-1005', 5, 'confirmed', NOW(),                   24500.00),
  ('SO-1006', 4, 'confirmed', NOW(),                    5800.00);

INSERT INTO sales_order_items (order_id, product_id, quantity, unit_price) VALUES
  (1, 1, 5, 3500.00),
  (2, 2, 2, 4900.00),
  (3, 3, 5, 12500.00),
  (4, 4, 10, 120.00),
  (5, 1, 7, 3500.00),
  (6, 2, 1, 4900.00), (6, 7, 2, 380.00);

INSERT INTO purchase_orders (po_no, supplier_id, status, order_date, total_amount) VALUES
  ('PO-2001', 1, 'received', NOW() - INTERVAL 10 DAY, 62000.00),
  ('PO-2002', 3, 'sent',     NOW() - INTERVAL 2 DAY,  14000.00);

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_cost) VALUES
  (1, 2, 20, 3100.00),
  (2, 6, 50,  280.00);

-- invoices: some already past due (still 'pending') so ev_mark_overdue_invoices flips them
INSERT INTO invoices (invoice_no, order_id, issue_date, due_date, amount, status) VALUES
  ('INV-1001', 1, CURDATE() - INTERVAL 33 DAY, CURDATE() - INTERVAL 3 DAY, 17500.00, 'pending'),
  ('INV-1002', 2, CURDATE() - INTERVAL 32 DAY, CURDATE() - INTERVAL 2 DAY,  9800.00, 'paid'),
  ('INV-1003', 3, CURDATE() - INTERVAL 20 DAY, CURDATE() - INTERVAL 1 DAY, 62500.00, 'pending'),
  ('INV-1004', 4, CURDATE() - INTERVAL 1 DAY,  CURDATE() + INTERVAL 29 DAY, 1200.00, 'pending'),
  ('INV-1005', 5, CURDATE(),                   CURDATE() + INTERVAL 30 DAY, 24500.00, 'pending');

INSERT INTO payments (invoice_id, paid_at, amount, method) VALUES
  (2, NOW() - INTERVAL 5 DAY, 9800.00, 'transfer');

-- initial FX seed — the event rolls these forward every minute
INSERT INTO exchange_rates (base_currency, quote_currency, rate) VALUES
  ('USD', 'THB', 36.250000),
  ('EUR', 'THB', 39.480000),
  ('JPY', 'THB',  0.243100),
  ('CNY', 'THB',  4.982000);
