-- Sample products to test the app
INSERT INTO products (name, barcode, price, cost_price, stock, min_stock, category, created_at, updated_at, synced, deleted) VALUES
('Rice (1kg)', '8901234567890', 60.00, 45.00, 50, 10, 'Grocery', datetime('now'), datetime('now'), 0, 0),
('Milk (1L)', '8901234567891', 50.00, 40.00, 30, 10, 'Grocery', datetime('now'), datetime('now'), 0, 0),
('Bread', '8901234567892', 40.00, 30.00, 20, 5, 'Grocery', datetime('now'), datetime('now'), 0, 0),
('Coca Cola (500ml)', '8901234567893', 40.00, 30.00, 100, 20, 'Beverages', datetime('now'), datetime('now'), 0, 0),
('Water Bottle (1L)', '8901234567894', 20.00, 15.00, 200, 50, 'Beverages', datetime('now'), datetime('now'), 0, 0),
('Chips (50g)', '8901234567895', 10.00, 7.00, 150, 30, 'Snacks', datetime('now'), datetime('now'), 0, 0),
('Biscuits', '8901234567896', 30.00, 22.00, 80, 20, 'Snacks', datetime('now'), datetime('now'), 0, 0),
('Shampoo (200ml)', '8901234567897', 150.00, 120.00, 15, 5, 'Personal Care', datetime('now'), datetime('now'), 0, 0),
('Soap', '8901234567898', 35.00, 25.00, 60, 15, 'Personal Care', datetime('now'), datetime('now'), 0, 0),
('Detergent (1kg)', '8901234567899', 200.00, 160.00, 25, 10, 'Household', datetime('now'), datetime('now'), 0, 0);
