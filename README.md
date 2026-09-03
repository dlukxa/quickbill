# QuickBill POS 🛒📱

QuickBill is an advanced, offline-first Point of Sale (POS) application tailored for modern small and medium-sized shops. Built fundamentally on Flutter and SQLite, it boasts powerful on-device edge AI algorithms without relying on cloud computation for immediate answers, ensuring privacy, speed, and reliability.

## 🌟 Core Features

### 1. Robust Billing & Checkout
* **Multi-Bill Processing:** Ability to manage and park multiple bills simultaneously while serving a long queue of customers.
* **Smart Receipts:** Fully customizable receipts shared flexibly via Bluetooth Thermal Printing, WhatsApp PDF integration, or standard sharing.
* **Barcode & Object Scanning:** Direct integration with Google ML Kit for blistering-fast barcode reading using the device camera.

### 2. Multi-Agentic, Multi-Lingual AI Assistant 🪄
QuickBill stands out with an intelligent multi-agent pipeline acting directly on the local database structure securely via **Flutter Gemma** and **TensorFlow Lite**.
* **Intent-Based Agents:** When you ask a question like *"who owes me money?"* or *"restock list"*, the Orchestrator instantly routes the query to specialized sub-agents (`CustomerAgent`, `ExpenseAgent`, `AutoRestockAgent`, `SalesAgent`).
* **Instant Direct Answers:** Provides high-speed tabular factual lists bypassing LLM delay for factual data (like stock levels and direct P&L numbers).
* **Multi-Lingual Advisor:** Natively interprets your app's language settings. For instance, if Sinhala (සිංහල) or Tamil (தமிழ்) is selected, Gemma translates the complex SQL aggregations into actionable business advice in your preferred language.

### 3. Inventory & Smart Restocking
* **Stock Management:** Seamless add, edit, and organize utilities for thousands of local store products.
* **Auto-Restock Agent:** TFLite algorithms actively monitor minimum threshold levels based on `lowStockThreshold` settings and automatically generate shopping lists estimating restock costs based strictly on supplier pricing.

### 4. CRM & Daily Expense Management
* **Customer Debt Profile:** Actively monitor credit customers, tracking net totals owed across an unlimited backlog.
* **Store Expenses:** Log daily operational costs (like electricity, transport, lunch) to give the AI engine the data it needs to calculate *true net profit*, rather than just top-line revenue.

### 5. Multi-Branch & Team Management 👥
* **Role Permissions:** Distinct modes for `Owner` and `Staff`. Staff see locked-down UI layouts prioritizing speed and checkout mapping, while Owners get full access to predictive graphs and analytics.
* **Branch Switching:** Seamlessly shift between distinct geographical storefront databases.

### 6. True Offline-First Architecture ⚡
* **Zero Dependency on Cloud Connectivity:** Relies wholly on internal Sqflite schemas ensuring sub-millisecond response times at point of checkout.
* **State Syncing:** Asynchronously queues data payloads pushed to Firebase Cloud Firestore seamlessly the moment an internet connection is detected. (Offline → Cloud Sync).

### 7. Android 15 & Play Store Prepared
* The core architecture has been modernized to successfully extract local native machine-learning libraries (`.so` extraction) rendering the app fully compatible with rigid Android 15 16KB Page-Size regulations.

---

## 🛠️ Technology Stack
* **Framework:** Flutter (Dart) / Riverpod 2.0 (State Management)
* **Local Database:** sqflite (SQLite)
* **Cloud Engine:** Firebase (Auth, Firestore, Storage)
* **Machine Learning / AI:** flutter_gemma (LLM), tflite_flutter (Predictive compute), Google ML Kit.
* **Peripheral Integration:** blue_thermal_printer, path_provider, pdf generator.
