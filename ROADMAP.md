# 📝 QuickBill POS: Roadmap & Evolution Plan

This document outlines the strategic technical and feature-based milestones for the continued evolution of QuickBill.

---

## 🏗 Phase 1: Data Integrity & Performance

*Focus: Strengthening the offline-to-cloud bridge and local database efficiency.*

### 1.1 Robust Conflict Resolution
* **The Problem:** Competing edits (e.g., two cashiers edit the same product price while offline) currently rely on simple overwrites based on sync timing.
* **The Fix:** Implement a stricter **"Last-Write-Wins"** strategy.
* **Action:** 
  - Leverage local `updated_at` timestamps in SQLite.
  - Implement a `server_timestamp` field on all Firebase documents to guarantee the cloud version acts as the absolute chronometer for conflict resolution during the `pullRemoteChanges` cycle.

### 1.2 Database Indexing
* **Task:** Apply structured SQL Indices to critical lookup columns: `barcode`, `product_name`, and `sync_status`.
* **Goal:** Ensure sub-millisecond query performance ensuring the barcode scanner remains "instant", even when local products exceed 10,000+ items.

---

## 🍎 Phase 2: The "Perishable Goods" Update

*Focus: Leveraging existing FIFO logic for deeper inventory insights and loss prevention.*

### 2.1 Expiry Date Tracking
* Modify the existing `Batch` model and SQLite schema to include `expiry_date`.
* **Visual Alerts:** Introduce an alert threshold highlighting inventory lists when batches are expiring within 30 days (Yellow) or have passed expiration (Red).

### 2.2 Wastage Management
* Introduce a "Mark as Waste" or "Write-off" user workflow.
* Allow operators to safely remove stock from a tracked batch without executing a `Sale` (e.g., due to spoilage, damages, or expiry), explicitly categorizing it for financial loss reporting.

---

## 📊 Phase 3: Business Intelligence (BI) Dashboard

*Focus: Granting Shop Owners bird's-eye view data and macro-level trends.*

| Feature | Description | Metric |
| --- | --- | --- |
| **Profit Analytics** | True net profit calculations evaluating historical FIFO batch cost vs. executed selling price. | $ |
| **Top Performers** | Leaderboards of top 5 selling products separated by volume and margin. | List |
| **Staff Performance** | Tracking total sales volume and unit quantities processed per Cashier ID to evaluate floor efficiency. | $ / Qty |
| **Peak Hours** | Chronological heatmaps revealing when the maximum sales occur to aid in staff scheduling. | Time |

---

## 🤝 Phase 4: Customer Loyalty & Retention

*Focus: Turning one-time shoppers into regulars with enterprise-grade CRM features.*

* **Loyalty Points Engine:** Configurable ratio where customers earn $X$ points for every $Y$ spent. Accumulations can be selected as an active "Tender Type" during cart checkout.
* **SMS Integration:** Integrate third-party API gateways (e.g., Twilio or regional providers) providing automated "Thank you for shopping!" SMS dispatches containing the bill total following payment processing.
* **Customer Credit Limits:** Introduce a configurable maximum "Tab" or "Credit" limit threshold on specific customer profiles to mitigate credit risk.

---

## 🛠 Technical Task Checklist

* [ ] **State Management:** Migrate legacy generic providers over to modern `AsyncNotifier` paradigms (Riverpod 2.0) for more resiliant asynchronous state handling and built-in error catching.
* [ ] **Security Rules:** Finalize and deploy tight Firestore Rules preventing authenticated Staff (Cashier role) clients from executing `Delete` operations on collections like `sales` or `employees`.
* [ ] **Compression:** Integrate an image compression layer for product photographs prior to Firebase Storage uploads, lowering bandwidth usage and cloud hosting costs.
* [ ] **Log Export:** Implement a "Debug Log" exporter on the device, allowing end-users to package local error logs into a `.txt`/`.zip` and send crash reports directly to the developer team.
