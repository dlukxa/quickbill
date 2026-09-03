# QuickBill POS - Comprehensive Documentation

Welcome to the complete feature and architecture documentation for **QuickBill POS**. QuickBill is an offline-first, highly responsive Point of Sale application built with Flutter, SQLite, and Firebase. It is designed to empower small to medium businesses with rapid billing, comprehensive inventory management, and robust employee controls, all functioning seamlessly regardless of internet connectivity.

---

## 🚀 Core Philosophy & Architecture

### **Offline-First Resilience**
QuickBill operates entirely on a local **SQLite Database**. Every sale, product update, or employee change is written to device storage instantly. 
- **The Application Never Waits:** The user experience is never blocked by a slow or dropped internet connection.
- **Background Sync:** A background `SyncService` monitors local changes and silently synchronizes data with **Firebase Firestore** when the internet is available.

### **Tech Stack**
- **Frontend/Framework:** Flutter & Dart
- **State Management:** Riverpod (`flutter_riverpod`)
- **Local Database:** SQLite (`sqflite`)
- **Cloud Backend:** Firebase (Auth, Firestore)
- **Document Generation:** PDF (`pdf`, `printing`)
- **Barcode/Hardware Integration:** MobileScanner

---

## 📦 Key Features Deep Dive

### 1. Authentication & Role Management
QuickBill supports flexible, business-focused authentication flows.
- **Shop Owner Registration:** Owners can sign up and log in using **Email/Password**, **Phone Number (OTP Verification)**, or **Google Sign-In**. 
- **Staff PIN & QR Login:** Instead of sharing primary credentials, owners generate secure, time-sensitive "Handshake" QR/Numeric codes directly from the app. Staff members scan this code (or type the PIN) to log in perfectly authorized to the owner's database.
- **Role-Based Access Control (RBAC):** Employees operate under roles (e.g., Cashier). Staff accounts are heavily guided—they can perform billing but are restricted from accessing sensitive financial Reports, Shop Settings, or performing administrative Refunds.

### 2. Billing & Point of Sale (POS)
The heart of QuickBill is built for speed and flexibility at the checkout counter.
- **Smart Cart System:** Add products by searching their name, scanning barcodes using the device's camera (`MobileScanner` integration), or visually tapping product tiles.
- **Quick Items:** An overlay sheet allowing cashiers to ring up custom amounts instantly—perfect for un-barcoded or miscellaneous items (e.g., "Plastic Bag - $0.50").
- **Tender Types:** Support for Cash, Card, Credit, and robust tracking for customer part-payments or running tabs.
- **Multi-Device Support:** Unique Record ID generation (`generateUniqueId`) guarantees no database collisions when multiple cashier tablets bill simultaneously offline.

### 3. Dynamic Discount Engine
A fully-featured promotional engine that operates directly within the cart logic.
- **Item-Level Discounts:** Cashiers can manually apply a fixed currency reduction or percentage off specific items.
- **Scheduled Auto-Discounts:** Create discounts bound to specific date/time ranges (e.g., "Weekend Happy Hour" or "Summer Sale"). When active, these apply automatically to eligible items.
- **Bill-Level Discounts:** Global cart discounts. The POS automatically calculates and applies the **best available** active bill discount to the entire cart total, ensuring customers always get the maximum eligible promo without cashier intervention.

### 4. Inventory & Stock Management
Tracking down to the individual batch level ensures precise cost management.
- **Granular Product Profiles:** Products have cost price, selling price, categories, barcodes, and dynamic alert thresholds.
- **Batch Tracking (FIFO):** Support for businesses with perishable goods (groceries, medicine). Stocks are managed in explicit batches. When making a sale, QuickBill automatically depletes stock from the oldest batch (First-In, First-Out) ensuring accurate profit margins over time.
- **Low Stock Alerts:** Automatic background checks trigger visual warnings on the dashboard when products dip below their defined minimum thresholds.

### 5. Invoicing & Digital Receipts
Meeting modern requirements for paperless and professional billing.
- **Thermal Printing:** Formatted correctly for standard 58mm or 80mm Bluetooth/Network receipt printers.
- **Professional A4 Invoices:** Detailed, enterprise-style PDF invoices suitable for B2B transactions.
- **WhatsApp Integration:** Seamlessly share digital receipts directly to a customer's registered WhatsApp number immediately after checkout.

### 6. Customer & Supplier CRM
- **Customer Tabs:** Keep track of regular clients and run credit balances. Easily manage "Settle Credit" payments.
- **Supplier Purchasing:** Track all incoming inventory batches dynamically against supplier invoices, keeping comprehensive ledgers of what is owed to vendors.

### 7. Regional & Localization Support
QuickBill adapts to the business's location.
- **Full App Translation:** 100% localized in English, Sinhala, and Tamil. The user interface translates contextually on the fly.
- **Dynamic Regional Formatting:** Explicit support for Sri Lanka (`Rs.`, `+94`), India (`₹`, `+91`), Maldives (`Rf.`, `+960`), and Bangladesh (`৳`, `+880`). When a region is selected in Settings, the entire app converts its currency symbols and phone number UI hints instantly.

---

## ⚙️ How It Works (Technical Workflows)

### **The "Sale to Cloud" Workflow**
1. **Cart Checkout:** Cashier taps "Pay." The POS validates the cart, selects the best FIFO stock batches, and creates a `Sale` object.
2. **Local Commit (SQLite):** An atomic database transaction executes:
   - Inserts `Sale` and `SaleItems`.
   - Generates Stock History log.
   - Updates Product/Batch actual stock deducts.
3. **Queue Sync:** The `DatabaseService` flags these new rows with `synced = 0`.
4. **Receipt Generation:** The UI unblocks immediately and displays the success screen/PDF receipt.
5. **Background Push:** Within 5 minutes (or forced immediately), the `SyncService` wakes up, queries all `synced = 0` operations, packages the JSON, writes them to `users/{shopId}/sales/{saleId}` in Firestore, and marks them `synced = 1` locally.

### **The "New Employee Configuration" Workflow**
1. **Owner Setup:** The Admin creates an Employee profile locally. It syncs to Firebase.
2. **Code Generation:** The Admin requests a "Staff Login Card." `StaffLoginService` generates a 6-digit PIN and pushes an encrypted handshake document to `/temp_logins/` in Firebase, valid for 10 minutes. 
3. **Employee Device Login:** The staff tablet scans the QR code or inputs the PIN. It anonymously queries `/temp_logins/`. If valid, it receives the owner's UI token, anchors itself to the owner's database path, downloads the full product database, and transitions to the Home Screen ready to sell.

---

**End of Documentation.**
*Generated automatically to reflect the latest state of the QuickBill POS project.*
