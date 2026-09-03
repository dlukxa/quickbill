# QuickBill POS - App Features Documentation

This document explains the core features and modules available in the QuickBill POS application. The application is a comprehensive Point of Sale system designed to manage billing, inventory, suppliers, customers, and business analytics.

## 1. Billing & Point of Sale (POS)
The core of the application where transactions occur.
- **Billing Screen**: A fast and responsive interface for adding items to the cart, computing totals, and applying discounts.
- **Barcode Scanning**: Integrated barcode scanner (`billing_scan_screen`) to quickly add items via hardware or camera.
- **Payment Processing**: Handling different payment methods (Cash, Card, etc.), finalizing bills, and generating receipts.
- **Quick Items**: A "Quick Item Sheet" allows cashiers to add untracked or common items rapidly without navigating the entire product catalog.

## 2. Stock & Inventory Management
Comprehensive tools to control products and stock levels.
- **Product Management**: Ability to add, edit, and archive products.
- **Batch Management**: Tracking products by batches, allowing for management of expiry dates and different cost prices per batch.
- **Stock Movement History**: Tracking all stock-in and stock-out events to prevent shrinkage and maintain clear logs (`stock_history_screen`).
- **Product Analysis**: Analyzing product performance, velocity, and stock efficiency.
- **Machine Learning Integration**: Features an `ml_training_screen` likely used for automated product recognition or smart search.

## 3. Reports & Analytics
Robust analytics to track business health.
- **Analytics Dashboard**: High-level overview of sales, profit margins, and general business metrics.
- **Sales & Profit/Loss Reports**: Detailed breakdowns of revenue, cost of goods sold (COGS), and net profits over specific intervals.
- **Peak Hours Analysis**: Tracks busy times to help merchants plan staffing accordingly.
- **Employee Reports**: Tracking sales and performance per cashier or employee.
- **Expense & Inventory Reports**: Overviews of business outflows and the financial value of the current inventory holding.
- **Refund Reports**: Auditing product returns and money refunded to customers.

## 4. Supplier & Purchase Management
Managing inward supply chains.
- **Supplier Directory**: Registering and managing suppliers (`supplier_list_screen`, `add_supplier_screen`).
- **Purchase Orders**: Adding new purchases against specific suppliers, automatically pulling inward stock and updating batches (`purchase_management_screen`, `add_purchase_screen`).

## 5. Returns & Refunds
Handling after-sales scenarios perfectly.
- **Process Returns**: Handles returning items smoothly (`process_return_screen`). Integrates with the `return_service` to allow for restocking damaged items or safely returning them to active inventory.
- **Sales History**: Viewing previous sales to select the appropriate bill for refund processing.

## 6. Customer Management
CRM capabilities within the POS.
- **Customer Directory**: Add, list, and view detailed customer profiles.
- **Customer Details**: View purchase history or potentially manage customer credit/loyalty associated with their profile.

## 7. Settings & Configuration
Tailoring the app to the merchant's operational needs.
- **Branch Management**: Multi-store/branch tracking and configuration.
- **Hardware Integrations**: Support for Bluetooth receipt printers and external scanners (`bluetooth_scanner_settings_screen`).
- **Employee Management**: Managing staff access and permissions for using the POS (`employee_list_screen`).
- **General Preferences**: Configurable settings such as customizing receipt formats, shop addresses, taxes, etc.

## 8. Subscriptions
- **SaaS Capabilities**: Built-in subscription tracking for merchants, locking premium features behind paywalls or managing subscription renewals directly within the app.
