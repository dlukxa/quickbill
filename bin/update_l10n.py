import json
import os

l10n_dir = "/Users/dlukxa/Development/projects/POS/quickbill/lib/l10n"

en_translations = {
    "reportsDashboard": "Reports Dashboard",
    "globalView": "Global",
    "revenue": "Revenue",
    "netProfit": "Net Profit",
    "salesTrend": "Sales Trend",
    "salesByCategory": "Sales by Category",
    "inventorySnapshot": "Inventory Snapshot",
    "totalStockValueRetail": "Total Stock Value (Retail)",
    "totalStockValueCost": "Total Stock Value (Cost)",
    "potentialProfit": "Potential Profit",
    "topSellingProducts": "Top Selling Products",
    "highValueCustomers": "High-Value Customers",
    "detailedReports": "Detailed Reports",
    "profitabilityAnalytics": "Profitability Analytics",
    "profitabilityAnalyticsDesc": "Margins, expenses & profitability deep-dive",
    "salesReport": "Sales Report",
    "salesReportDesc": "Detailed transaction history",
    "profitLoss": "Profit & Loss",
    "profitLossDesc": "Revenue vs Cost of Goods Sold",
    "inventoryAudit": "Inventory Audit",
    "inventoryAuditDesc": "Valuation and stock status",
    "refundReport": "Refund Report",
    "refundReportDesc": "Itemized sales returns",
    "employeePerformance": "Employee Performance",
    "employeePerformanceDesc": "Sales and hours by staff",
    "peakHours": "Peak Hours",
    "peakHoursDesc": "Heatmap of busiest days & hours",
    "today": "Today",
    "thisWeek": "This Week",
    "thisMonth": "This Month",
    "threeMonths": "3 Months",
    "thisYear": "This Year",
    "showingPeriod": "Showing: {start} - {end}",
    "globalPeriod": "GLOBAL VIEW: {start} - {end}",
    "totalInventoryValue": "TOTAL INVENTORY VALUE",
    "totalItems": "Total Items",
    "categories": "Categories",
    "productValuation": "Product Valuation",
    "value": "Value",
    "profitLossStatement": "Profit & Loss Statement",
    "discountsGiven": "Discounts Given",
    "refunds": "Refunds",
    "cogs": "Cost of Goods Sold (COGS)",
    "grossProfit": "Gross Profit",
    "profitCalculationNote": "Profit is calculated based on the cost price of items at the time of sale.",
    "forPeriod": "For: {start} - {end}",
    
    # New additions
    "detailedSalesReport": "Detailed Sales Report",
    "noSalesPeriod": "No sales found for this period",
    "transactionsCount": "{count} transactions",
    "exportCsv": "Export CSV",
    "exportPdf": "Export PDF",
    "customerLabel": "Customer: {name}",
    "customer": "Customer",
    "billNo": "Bill No: {number}",
    "dateLabel": "Date",
    "timeLabel": "Time",
    "paymentLabel": "Payment",
    "phoneLabel": "Phone",
    "itemsHeading": "ITEMS",
    "receipt80mm": "Receipt (80mm)",
    "invoiceA4": "Invoice (A4)",
    "returnRefundItems": "Return / Refund Items",
    "aiPredictiveInsights": "AI PREDICTIVE INSIGHTS 🤖",
    "profitWaterfall": "PROFIT WATERFALL",
    "profitabilityTrend": "PROFITABILITY TREND",
    "categoryProfitability": "CATEGORY PROFITABILITY",
    "topProfitContributors": "TOP PROFIT CONTRIBUTORS",
    "grossMargin": "Gross Margin",
    "netMargin": "Net Margin",
    "expenseRatio": "Expense Ratio",
    "operatingExpenses": "Operating Expenses",
    "marginPercent": "Margin: {margin}%",
    "soldUnits": "Sold: {quantity} units",
    "noTrendData": "No trend data",
    "countLabel": "Count",
    "busiest": "Busiest",
    "quietest": "Quietest",
    "activityHeatmap": "ACTIVITY HEATMAP",
    "top5PeakSlots": "TOP 5 PEAK SLOTS",
    "noSalesDataPeriod": "No sales data in this period",
    "low": "Low",
    "high": "High",
    "noRefundsExport": "No refunds to export",
    "noRefundsPeriod": "No refunds found for this period",
    "totalRefunded": "TOTAL REFUNDED",
    "returnedToStock": "Returned to Stock",
    "damagedWaste": "Damaged / Waste",
    "reasonLabel": "Reason: {reason}",
    "returnedItemsHeading": "RETURNED ITEMS",
    "performanceReport": "Performance Report",
    "noPerformanceData": "No performance data available",
    "billsLabel": "Bills",
    "hoursLabel": "Hours",
    "avgBillLabel": "Avg/Bill",
    "expenseManagement": "Expense Management",
    "noExpensesRecorded": "No expenses recorded yet.",
    "logExpense": "Log Expense",
    "logNewExpense": "Log New Expense",
    "category": "Category",
    "amount": "Amount",
    "noteOptional": "Note (Optional)",
    "required": "Required",
    "saveExpense": "Save Expense",
    "deleteExpenseQuery": "Delete Expense?",
    "deleteExpenseConfirm": "Are you sure you want to remove this expense record?",
    "expRent": "Rent",
    "expElectricity": "Electricity",
    "expWater": "Water",
    "expSalary": "Salary",
    "expTransport": "Transport",
    "expRepairs": "Repairs",
    "expMarketing": "Marketing",
    "expInventoryPurchase": "Inventory Purchase",
    "expGeneral": "General",
    "inventoryStockPrice": "Stock: {stock} {unit} • Price: {price}",
    
    # Settings screen keys
    "shopTeamSettings": "Shop & Team Settings",
    "shopTeamSettingsDesc": "Logo, contact details, staff & branch management",
    "devicePrinting": "Device & Printing",
    "devicePrintingDesc": "Bluetooth receipt printer & barcode scanner settings",
    "preferencesAlerts": "Preferences & Alerts",
    "preferencesAlertsDesc": "Language, region, theme mode & low stock limits",
    "dataBackups": "Data & Backups",
    "dataBackupsDesc": "Auto-sync, database backups, import/export & reset",
    "countryRegion": "Country/Region",
    "uploadingLogo": "Uploading logo...",
    "logoUpdated": "Logo updated successfully!",
    "uploadFailed": "Upload failed: {error}",
    "mainBranch": "Main Branch",
    "localization": "Localization",
    "entityCode": "Invoice Entity Code (QQQQ)",
    "editEntityCode": "Edit Invoice Entity Code",
    "entityCodeError": "Invalid code. Must be 1-15 alphanumeric characters without spaces."
}

# Metadata keys for placeholders
en_metadata = {
    "@showingPeriod": {
        "placeholders": {
            "start": {},
            "end": {}
        }
    },
    "@globalPeriod": {
        "placeholders": {
            "start": {},
            "end": {}
        }
    },
    "@forPeriod": {
        "placeholders": {
            "start": {},
            "end": {}
        }
    },
    "@transactionsCount": {
        "placeholders": {
            "count": {}
        }
    },
    "@customerLabel": {
        "placeholders": {
            "name": {}
        }
    },
    "@billNo": {
        "placeholders": {
            "number": {}
        }
    },
    "@marginPercent": {
        "placeholders": {
            "margin": {}
        }
    },
    "@soldUnits": {
        "placeholders": {
            "quantity": {}
        }
    },
    "@reasonLabel": {
        "placeholders": {
            "reason": {}
        }
    },
    "@uploadFailed": {
        "placeholders": {
            "error": {}
        }
    },
    "@inventoryStockPrice": {
        "placeholders": {
            "stock": {},
            "unit": {},
            "price": {}
        }
    }
}

si_translations = {
    "reportsDashboard": "වාර්තා උපකරණ පුවරුව",
    "globalView": "පොදු",
    "revenue": "ආදායම",
    "netProfit": "ශුද්ධ ලාභය",
    "salesTrend": "විකුණුම් ප්‍රවණතාවය",
    "salesByCategory": "කාණ්ඩ අනුව විකුණුම්",
    "inventorySnapshot": "තොග සාරාංශය",
    "totalStockValueRetail": "මුළු තොග වටිනාකම (සිල්ලර)",
    "totalStockValueCost": "මුළු තොග වටිනාකම (පිරිවැය)",
    "potentialProfit": "විභව ලාභය",
    "topSellingProducts": "වැඩිපුරම අලෙවි වන භාණ්ඩ",
    "highValueCustomers": "ඉහළ වටිනාකමක් ඇති පාරිභෝගිකයින්",
    "detailedReports": "විස්තරාත්මක වාර්තා",
    "profitabilityAnalytics": "ලාභදායීතා විශ්ලේෂණය",
    "profitabilityAnalyticsDesc": "ලාභ තීරුව, වියදම් සහ ලාභදායීතා විශ්ලේෂණය",
    "salesReport": "විකුණුම් වාර්තාව",
    "salesReportDesc": "විස්තරාත්මක ගනුදෙනු ඉතිහාසය",
    "profitLoss": "ලාභ හා අලාභ",
    "profitLossDesc": "ආදායම සහ විකුණන ලද භාණ්ඩවල පිරිවැය",
    "inventoryAudit": "තොග විගණනය",
    "inventoryAuditDesc": "තොග වටිනාකම සහ තත්ත්වය",
    "refundReport": "මුදල් ආපසු ගෙවීමේ වාර්තාව",
    "refundReportDesc": "විකුණුම් ආපසු හැරවීම්",
    "employeePerformance": "සේවක කාර්ය සාධනය",
    "employeePerformanceDesc": "සේවකයින්ගේ විකුණුම් සහ සේවා කාලය",
    "peakHours": "වැඩිම කාර්යබහුල වේලාවන්",
    "peakHoursDesc": "කාර්යබහුල දින සහ වේලාවන්හි සිතියම",
    "today": "අද",
    "thisWeek": "මේ සතිය",
    "thisMonth": "මේ මාසය",
    "threeMonths": "මාස 3",
    "thisYear": "මේ වසර",
    "showingPeriod": "පෙන්වන්නේ: {start} - {end}",
    "globalPeriod": "ගෝලීය දසුන: {start} - {end}",
    "totalInventoryValue": "මුළු තොග වටිනාකම",
    "totalItems": "මුළු භාණ්ඩ",
    "categories": "කාණ්ඩ",
    "productValuation": "භාණ්ඩ තක්සේරුව",
    "value": "වටිනාකම",
    "profitLossStatement": "ලාභ අලාභ ගිණුම් ප්‍රකාශය",
    "discountsGiven": "ලබා දුන් වට්ටම්",
    "refunds": "ආපසු ගෙවීම්",
    "cogs": "විකුණන ලද භාණ්ඩවල පිරිවැය (COGS)",
    "grossProfit": "දළ ලාභය",
    "profitCalculationNote": "ලාභය ගණනය කරනු ලබන්නේ විකිණූ අවස්ථාවේ භාණ්ඩවල පිරිවැය මිල මත පදනම්වය.",
    "forPeriod": "කාලය: {start} - {end}",
    
    # New additions
    "detailedSalesReport": "විස්තරාත්මක විකුණුම් වාර්තාව",
    "noSalesPeriod": "මෙම කාලසීමාව සඳහා විකුණුම් හමු නොවුණි",
    "transactionsCount": "ගනුදෙනු {count}",
    "exportCsv": "CSV අපනයනය",
    "exportPdf": "PDF අපනයනය",
    "customerLabel": "පාරිභෝගිකයා: {name}",
    "customer": "පාරිභෝගිකයා",
    "billNo": "බිල්පත් අංකය: {number}",
    "dateLabel": "දිනය",
    "timeLabel": "වේලාව",
    "paymentLabel": "ගෙවීම් ක්‍රමය",
    "phoneLabel": "දුරකථන අංකය",
    "itemsHeading": "භාණ්ඩ",
    "receipt80mm": "රසීදුව (මි.මී. 80)",
    "invoiceA4": "ඉන්වොයිසිය (A4)",
    "returnRefundItems": "භාණ්ඩ ආපසු හැරවීම / මුදල් ආපසු ගෙවීම",
    "aiPredictiveInsights": "AI අනාවැකි තොරතුරු 🤖",
    "profitWaterfall": "ලාභ ගැලීම් සටහන",
    "profitabilityTrend": "ලාභදායීතා ප්‍රවණතාවය",
    "categoryProfitability": "කාණ්ඩ අනුව ලාභදායීතාවය",
    "topProfitContributors": "ප්‍රධාන ලාභ දායකයින්",
    "grossMargin": "දළ ආන්තිකය",
    "netMargin": "ශුද්ධ ආන්තිකය",
    "expenseRatio": "වියදම් අනුපාතය",
    "operatingExpenses": "මෙහෙයුම් වියදම්",
    "marginPercent": "ආන්තිකය: {margin}%",
    "soldUnits": "විකුණන ලද ප්‍රමාණය: {quantity}",
    "noTrendData": "ප්‍රවණතා දත්ත නොමැත",
    "countLabel": "ගණන",
    "busiest": "කාර්යබහුලම",
    "quietest": "නිශ්ශබ්දම",
    "activityHeatmap": "ක්‍රියාකාරකම් තාප සිතියම",
    "top5PeakSlots": "ප්‍රධාන කාර්යබහුල වේලාවන් 5",
    "noSalesDataPeriod": "මෙම කාලසීමාව තුළ විකුණුම් දත්ත නොමැත",
    "low": "අඩු",
    "high": "වැඩි",
    "noRefundsExport": "අපනයනය කිරීමට මුදල් ආපසු ගෙවීම් නොමැත",
    "noRefundsPeriod": "මෙම කාලසීමාව සඳහා මුදල් ආපසු ගෙවීම් හමු නොවුණි",
    "totalRefunded": "මුළු ආපසු ගෙවූ මුදල",
    "returnedToStock": "නැවත තොගයට එක් කරන ලදී",
    "damagedWaste": "හානි වූ / නාස්ති වූ",
    "reasonLabel": "හේතුව: {reason}",
    "returnedItemsHeading": "ආපසු හැරවූ භාණ්ඩ",
    "performanceReport": "කාර්ය සාධන වාර්තාව",
    "noPerformanceData": "කාර්ය සාධන දත්ත නොමැත",
    "billsLabel": "බිල්පත්",
    "hoursLabel": "පැය",
    "avgBillLabel": "බිලක සාමාන්‍යය",
    "expenseManagement": "වියදම් කළමනාකරණය",
    "noExpensesRecorded": "තවමත් වියදම් කිසිවක් සටහන් කර නොමැත.",
    "logExpense": "වියදම් සටහන් කරන්න",
    "logNewExpense": "නව වියදමක් සටහන් කරන්න",
    "category": "කාණ්ඩය",
    "amount": "මුදල",
    "noteOptional": "සටහන (විකල්ප)",
    "required": "අත්‍යවශ්‍යයි",
    "saveExpense": "වියදම සුරකින්න",
    "deleteExpenseQuery": "වියදම මකන්නද?",
    "deleteExpenseConfirm": "මෙම වියදම් වාර්තාව ඉවත් කිරීමට ඔබට විශ්වාසද?",
    "expRent": "කුලිය",
    "expElectricity": "විදුලිය",
    "expWater": "ජලය",
    "expSalary": "වැටුප්",
    "expTransport": "ප්‍රවාහනය",
    "expRepairs": "අලුත්වැඩියා කටයුතු",
    "expMarketing": "අලෙවිකරණය",
    "expInventoryPurchase": "තොග මිලදී ගැනීම්",
    "expGeneral": "පොදු",
    "inventoryStockPrice": "තොගය: {stock} {unit} • මිල: {price}",
    
    # Settings screen keys
    "shopTeamSettings": "වෙළඳසැල් සහ කණ්ඩායම් සැකසුම්",
    "shopTeamSettingsDesc": "ලාංඡනය, සම්බන්ධතා තොරතුරු, කාර්ය මණ්ඩලය සහ ශාඛා කළමනාකරණය",
    "devicePrinting": "උපාංග සහ මුද්‍රණය",
    "devicePrintingDesc": "බ්ලූටූත් රසීදු මුද්‍රණ යන්ත්‍රය සහ තීරු කේත ස්කෑනර් සැකසුම්",
    "preferencesAlerts": "අභිප්‍රේත සහ ඇඟවීම්",
    "preferencesAlertsDesc": "භාෂාව, කලාපය, තේමාව සහ අඩු තොග සීමාවන්",
    "dataBackups": "දත්ත සහ උපස්ථ",
    "dataBackupsDesc": "ස්වයංක්‍රීය සමමුහුර්තකරණය, දත්ත සමුදාය උපස්ථ, ආනයනය/අපනයනය සහ නැවත සැකසීම",
    "countryRegion": "රට/කලාපය",
    "uploadingLogo": "ලාංඡනය උඩුගත කරමින්...",
    "logoUpdated": "ලාංඡනය සාර්ථකව යාවත්කාලීන කරන ලදී!",
    "uploadFailed": "උඩුගත කිරීම අසාර්ථක විය: {error}",
    "mainBranch": "ප්‍රධාන ශාඛාව",
    "localization": "දේශීයකරණය",
    "entityCode": "ඉන්වොයිස් ආයතන කේතය (QQQQ)",
    "editEntityCode": "ඉන්වොයිස් ආයතන කේතය සංස්කරණය කරන්න",
    "entityCodeError": "වලංගු නොවන කේතයකි. හිස්තැන් රහිතව අකුරු/ඉලක්කම් 1-15 අතර විය යුතුය."
}

ta_translations = {
    "reportsDashboard": "அறிக்கைகள் டாஷ்போர்டு",
    "globalView": "ஒட்டுமொத்த",
    "revenue": "வருவாய்",
    "netProfit": "நிகர லாபம்",
    "salesTrend": "விற்பனை போக்கு",
    "salesByCategory": "வகை வாரியாக விற்பனை",
    "inventorySnapshot": "சரக்கு இருப்பு சுருக்கம்",
    "totalStockValueRetail": "மொத்த இருப்பு மதிப்பு (சில்லறை)",
    "totalStockValueCost": "மொத்த இருப்பு மதிப்பு (அடக்கம்)",
    "potentialProfit": "சாத்தியமான லாபம்",
    "topSellingProducts": "அதிகம் விற்பனையாகும் தயாரிப்புகள்",
    "highValueCustomers": "அதிக மதிப்புள்ள வாடிக்கையாளர்கள்",
    "detailedReports": "விரிவான அறிக்கைகள்",
    "profitabilityAnalytics": "லாபத்தன்மை பகுப்பாய்வு",
    "profitabilityAnalyticsDesc": "லாப வரம்புகள், செலவுகள் & லாபத்தன்மை பற்றிய விரிவான ஆய்வு",
    "salesReport": "விற்பனை அறிக்கை",
    "salesReportDesc": "விரிவான பரிவர்த்தனை வரலாறு",
    "profitLoss": "லாப நஷ்டம்",
    "profitLossDesc": "வருவாய் மற்றும் விற்கப்பட்ட பொருட்களின் அடக்க விலை",
    "inventoryAudit": "சரக்கு இருப்பு தணிக்கை",
    "inventoryAuditDesc": "மதிப்பீடு மற்றும் இருப்பு நிலை",
    "refundReport": "திரும்பப் பெற்ற தொகை அறிக்கை",
    "refundReportDesc": "விற்பனை வருமான விவரம்",
    "employeePerformance": "ஊழியர் செயல்திறன்",
    "employeePerformanceDesc": "ஊழியர்களின் விற்பனை மற்றும் வேலை நேரம்",
    "peakHours": "உச்ச நேரங்கள்",
    "peakHoursDesc": "பரபரப்பான நாட்கள் மற்றும் மணிநேரங்களின் வரைபடம்",
    "today": "இன்று",
    "thisWeek": "இந்த வாரம்",
    "thisMonth": "இந்த மாதம்",
    "threeMonths": "3 மாதங்கள்",
    "thisYear": "இந்த வருடம்",
    "showingPeriod": "காண்பிக்கப்படுவது: {start} - {end}",
    "globalPeriod": "ஒட்டுமொத்த பார்வை: {start} - {end}",
    "totalInventoryValue": "மொத்த சரக்கு இருப்பு மதிப்பு",
    "totalItems": "மொத்த பொருட்கள்",
    "categories": "வகைகள்",
    "productValuation": "தயாரிப்பு மதிப்பீடு",
    "value": "மதிப்பு",
    "profitLossStatement": "லாப நஷ்ட கணக்கு அறிக்கை",
    "discountsGiven": "வழங்கப்பட்ட தள்ளுபடிகள்",
    "refunds": "திரும்பப் பெற்றவை",
    "cogs": "விற்கப்பட்ட பொருட்களின் அடக்க விலை (COGS)",
    "grossProfit": "மொத்த லாபம்",
    "profitCalculationNote": "விற்பனை செய்யப்பட்ட நேரத்தில் பொருட்களின் அடக்க விலையின் அடிப்படையில் லாபம் கணக்கிடப்படுகிறது.",
    "forPeriod": "கால அளவு: {start} - {end}",
    
    # New additions
    "detailedSalesReport": "விரிவான விற்பனை அறிக்கை",
    "noSalesPeriod": "இந்த காலப்பகுதியில் விற்பனை எதுவும் காணப்படவில்லை",
    "transactionsCount": "{count} பரிவர்த்தனைகள்",
    "exportCsv": "CSV ஏற்றுமதி",
    "exportPdf": "PDF ஏற்றுமதி",
    "customerLabel": "வாடிக்கையாளர்: {name}",
    "customer": "வாடிக்கையாளர்",
    "billNo": "பில் எண்: {number}",
    "dateLabel": "தேதி",
    "timeLabel": "நேரம்",
    "paymentLabel": "பணம் செலுத்துதல்",
    "phoneLabel": "தொலைபேசி",
    "itemsHeading": "பொருட்கள்",
    "receipt80mm": "ரசீது (80 மிமீ)",
    "invoiceA4": "விலைப்பட்டியல் (A4)",
    "returnRefundItems": "பொருட்களைத் திருப்பித் தருதல் / பணத்தைத் திரும்பப் பெறுதல்",
    "aiPredictiveInsights": "AI கணிப்பு விவரங்கள் 🤖",
    "profitWaterfall": "லாப நீர்வீழ்ச்சி வரைபடம்",
    "profitabilityTrend": "லாபத்தன்மை போக்கு",
    "categoryProfitability": "வகை வாரியான லாபத்தன்மை",
    "topProfitContributors": "முக்கிய லாபப் பங்களிப்பாளர்கள்",
    "grossMargin": "மொத்த லாப வரம்பு",
    "netMargin": "நிகர லாப வரம்பு",
    "expenseRatio": "செலவு விகிதம்",
    "operatingExpenses": "இயக்கச் செலவுகள்",
    "marginPercent": "வரம்பு: {margin}%",
    "soldUnits": "விற்பனை: {quantity} அலகுகள்",
    "noTrendData": "போக்குத் தரவு இல்லை",
    "countLabel": "எண்ணிக்கை",
    "busiest": "மிகவும் பரபரப்பான",
    "quietest": "அமைதியான",
    "activityHeatmap": "செயல்பாட்டு வெப்ப வரைபடம்",
    "top5PeakSlots": "முதல் 5 உச்ச நேரங்கள்",
    "noSalesDataPeriod": "இந்த காலப்பகுதியில் விற்பனை தரவு எதுவும் இல்லை",
    "low": "குறைவு",
    "high": "அதிகம்",
    "noRefundsExport": "ஏற்றுமதி செய்ய பணத்தைத் திரும்பப் பெற்ற விவரங்கள் எதுவும் இல்லை",
    "noRefundsPeriod": "இந்த காலப்பகுதியில் பணத்தைத் திரும்பப் பெற்ற விவரங்கள் எதுவும் காணப்படவில்லை",
    "totalRefunded": "மொத்தமாகத் திரும்பப் பெறப்பட்டது",
    "returnedToStock": "இருப்புக்குத் திரும்பியது",
    "damagedWaste": "சேதமடைந்தது / கழிவு",
    "reasonLabel": "காரணம்: {reason}",
    "returnedItemsHeading": "திருப்பி அனுப்பப்பட்ட பொருட்கள்",
    "performanceReport": "செயல்திறன் அறிக்கை",
    "noPerformanceData": "செயல்திறன் தரவு எதுவும் கிடைக்கவில்லை",
    "billsLabel": "பில்கள்",
    "hoursLabel": "மணிநேரம்",
    "avgBillLabel": "சராசரி/பில்",
    "expenseManagement": "செலவு மேலாண்மை",
    "noExpensesRecorded": "செலவுகள் எதுவும் இன்னும் பதிவு செய்யப்படவில்லை.",
    "logExpense": "செலவைப் பதிவு செய்",
    "logNewExpense": "புதிய செலவைப் பதிவு செய்",
    "category": "வகை",
    "amount": "தொகை",
    "noteOptional": "குறிப்பு (விரும்பினால்)",
    "required": "தேவைப்படுகிறது",
    "saveExpense": "செலவைச் சேமி",
    "deleteExpenseQuery": "செலவை நீக்க வேண்டுமா?",
    "deleteExpenseConfirm": "இந்த செலவுப் பதிவை நீக்கப் போவது உறுதிதானா?",
    "expRent": "வாடகை",
    "expElectricity": "மின்சாரம்",
    "expWater": "தண்ணீர்",
    "expSalary": "சம்பளம்",
    "expTransport": "போக்குவரத்து",
    "expRepairs": "பழுதுபார்ப்பு",
    "expMarketing": "சந்தைப்படுத்தல்",
    "expInventoryPurchase": "சரக்கு கொள்முதல்",
    "expGeneral": "பொது",
    "inventoryStockPrice": "இருப்பு: {stock} {unit} • விலை: {price}",
    
    # Settings screen keys
    "shopTeamSettings": "கடை மற்றும் குழு அமைப்புகள்",
    "shopTeamSettingsDesc": "லோகோ, தொடர்பு விவரங்கள், ஊழியர்கள் மற்றும் கிளை மேலாண்மை",
    "devicePrinting": "சாதனம் மற்றும் அச்சிடுதல்",
    "devicePrintingDesc": "புளூடூத் ரசீது அச்சுப்பொறி மற்றும் பார்கோடு ஸ்கேனர் அமைப்புகள்",
    "preferencesAlerts": "விருப்பங்கள் மற்றும் விழிப்பூட்டல்கள்",
    "preferencesAlertsDesc": "மொழி, பிராந்தியம், தீம் முறை மற்றும் குறைந்த இருப்பு வரம்புகள்",
    "dataBackups": "தரவு மற்றும் காப்புப்பிரதிகள்",
    "dataBackupsDesc": "தானியங்கு ஒத்திசைவு, தரவுத்தள காப்புப்பிரதிகள், இறக்குமதி/ஏற்றுமதி மற்றும் மீட்டமைப்பு",
    "countryRegion": "நாடு/பிராந்தியம்",
    "uploadingLogo": "லோகோ பதிவேற்றப்படுகிறது...",
    "logoUpdated": "லோகோ வெற்றிகரமாக புதுப்பிக்கப்பட்டது!",
    "uploadFailed": "பதிவேற்றம் தோல்வியடைந்தது: {error}",
    "mainBranch": "முதன்மை கிளை",
    "localization": "மொழிபெயர்ப்பு",
    "entityCode": "இன்வாய்ஸ் நிறுவனக் குறியீடு (QQQQ)",
    "editEntityCode": "இன்வாய்ஸ் நிறுவனக் குறியீட்டைத் திருத்துக",
    "entityCodeError": "தவறான குறியீடு. இடைவெளிகள் இல்லாமல் 1-15 எழுத்துக்கள்/எண்கள் இருக்க வேண்டும்."
}

def update_file(filename, translations, metadata=None):
    filepath = os.path.join(l10n_dir, filename)
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Merge translations
    for k, v in translations.items():
        data[k] = v
        
    if metadata:
        for k, v in metadata.items():
            data[k] = v
            
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Updated {filename}")

update_file("app_en.arb", en_translations, en_metadata)
update_file("app_si.arb", si_translations)
update_file("app_ta.arb", ta_translations)

hi_extra = {
    "entityCode": "इन्वॉयस इकाई कोड (QQQQ)",
    "editEntityCode": "इन्वॉयस इकाई कोड संपादित करें",
    "entityCodeError": "अमान्य कोड। बिना रिक्त स्थान के 1-15 अल्फ़ान्यूमेरिक वर्ण होने चाहिए।"
}
bn_extra = {
    "entityCode": "ইনভয়েস এন্টিটি কোড (QQQQ)",
    "editEntityCode": "ইনভয়েস এন্টিটি কোড সম্পাদনা করুন",
    "entityCodeError": "অকার্যকর কোড। ফাঁকা স্থান ছাড়া ১-১৫ আলফানিউমেরিক অক্ষর হতে হবে।"
}
dv_extra = {
    "entityCode": "އިންވޮއިސް އެންޓިޓީ ކޯޑު (QQQQ)",
    "editEntityCode": "އިންވޮއިސް އެންޓިޓީ ކޯޑު ބަދަލުކުރައްވާ",
    "entityCodeError": "ނުބައި ކޯޑެއް. ހުސްތަން ނުލައި 1 އާއި 15 އާ ދެމެދުގެ އަކުރު ނުވަތަ ނަންބަރު ހުންނަންވާނެ."
}

update_file("app_hi.arb", hi_extra)
update_file("app_bn.arb", bn_extra)
update_file("app_dv.arb", dv_extra)
