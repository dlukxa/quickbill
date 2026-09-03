import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../models/inventory_alert.dart';
import 'product_provider.dart';
import 'branch_provider.dart';

enum ReportPreset { day, week, month, threeMonths, year, custom }

/// Provider for custom date range reports
final reportDateRangeProvider = StateProvider<ReportDateRange>((ref) {
  return ReportDateRange.fromPreset(ReportPreset.month); // Default to this month
});

/// Provider for toggling consolidated (all branches) view
final isConsolidatedProvider = StateProvider<bool>((ref) => false);

/// Provider for dismissed alert IDs
final dismissedAlertsProvider = StateProvider<Set<String>>((ref) => {});

class ReportDateRange {
  final DateTime start;
  final DateTime end;
  final ReportPreset preset;

  ReportDateRange({
    required this.start,
    required this.end,
    this.preset = ReportPreset.custom,
  });

  factory ReportDateRange.fromPreset(ReportPreset preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999, 999);

    switch (preset) {
      case ReportPreset.day:
        start = DateTime(now.year, now.month, now.day);
        break;
      case ReportPreset.week:
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case ReportPreset.month:
        start = DateTime(now.year, now.month, 1);
        break;
      case ReportPreset.threeMonths:
        start = DateTime(now.year, now.month - 2, 1);
        break;
      case ReportPreset.year:
        start = DateTime(now.year, 1, 1);
        break;
      case ReportPreset.custom:
        start = DateTime(now.year, now.month, 1);
        break;
    }

    return ReportDateRange(start: start, end: end, preset: preset);
  }

  ReportDateRange copyWith({DateTime? start, DateTime? end, ReportPreset? preset}) {
    return ReportDateRange(
      start: start ?? this.start,
      end: end ?? this.end,
      preset: preset ?? this.preset,
    );
  }
}

/// Provider for daily sales chart data
final salesChartProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getDailySalesForPeriod(range.start, range.end, branchId);
});

/// Provider for Profit & Loss summary
final profitLossProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getProfitLossSummary(range.start, range.end, branchId);
});

/// Provider for Inventory Valuation
final inventoryAuditProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getInventoryAudit(branchId);
});

/// Provider for top selling products
final topProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getTopSellingProducts(5, range.start, range.end, branchId);
});

/// Provider for top customers
final topCustomersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getTopCustomers(5, range.start, range.end, branchId);
});

/// Provider for sales by category
final categorySalesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getSalesByCategory(range.start, range.end, branchId);
});

/// Provider for Damage and Waste Report
final damageAndWasteProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getDamageAndWasteReport(range.start, range.end, branchId);
});

/// Provider for Supplier Returns Report
final supplierReturnsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getSupplierReturnsReport(range.start, range.end, branchId);
});

/// Provider for expiring batches
final expiringBatchesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getExpiringBatches(30, branchId); // 30 day threshold
});

/// Consolidated Inventory Alerts (Low Stock + Expiry)
final inventoryAlertsProvider = FutureProvider<List<InventoryAlert>>((ref) async {
  final lowStockAsync = ref.watch(lowStockProductsProvider);
  final expiringAsync = ref.watch(expiringBatchesProvider);
  final dismissedAlerts = ref.watch(dismissedAlertsProvider);

  final List<InventoryAlert> alerts = [];

  // Handle Low Stock
  lowStockAsync.whenData((products) {
    for (var p in products) {
      final alertId = 'low-stock-${p.id}';
      if (!dismissedAlerts.contains(alertId)) {
        alerts.add(InventoryAlert(
          id: alertId,
          type: AlertType.lowStock,
          title: 'Low Stock: ${p.name}',
          subtitle: '${p.calculatedStock} remaining (Threshold: ${p.minStock ?? "N/A"})',
          productId: p.id!,
        ));
      }
    }
  });

  // Handle Expiry
  expiringAsync.whenData((batches) {
    for (var b in batches) {
      final expiryDate = DateTime.parse(b['expiry_date']);
      final daysLeft = expiryDate.difference(DateTime.now()).inDays;
      final alertId = 'expiring-${b['batch_id']}';
      
      if (!dismissedAlerts.contains(alertId)) {
        alerts.add(InventoryAlert(
          id: alertId,
          type: AlertType.expiring,
          title: 'Expiry Alert: ${b['product_name']}',
          subtitle: 'Batch ${b['batch_number']} expires in $daysLeft days',
          productId: b['product_id'],
          batchId: b['batch_id'],
          date: expiryDate,
        ));
      }
    }
  });

  return alerts;
});

/// Detailed Analytics Provider (GP/NP/Margins)
final summaryProfitabilityProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getSummaryProfitability(range.start, range.end, branchId);
});

/// Category Profitability Breakdown
final categoryProfitabilityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getCategoryProfitability(range.start, range.end, branchId);
});

/// Top Profitable Products (By Contribution Margin)
final topProfitableProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getTopProfitableProducts(5, range.start, range.end, branchId);
});

/// Operating Expenses Summary
final operatingExpensesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getOperatingExpensesSummary(range.start, range.end, branchId);
});

/// Profitability Trends (Revenue vs COGS vs Expenses)
final profitabilityTrendsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getProfitabilityTrends(range.start, range.end, branchId);
});

/// Provider for refund records
final refundsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);

  // Trigger background lazy fetch for older sales and returns to ensure reports are accurate
  // This runs in the background while local SQLite data is loaded immediately
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final syncService = ref.read(syncServiceProvider);
    syncService.pullHistoricalData('sales').then((_) {
      syncService.pullHistoricalData('sales_returns');
    });
  });

  return await DatabaseService.instance.getRefundsByRange(range.start, range.end, branchId);
});

/// Provider for employee performance
final employeePerformanceProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getEmployeePerformance(range.start, range.end, branchId);
});

/// Peak Hours heatmap data (day-of-week × hour)
final peakHoursProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final isConsolidated = ref.watch(isConsolidatedProvider);
  final branchId = isConsolidated ? 0 : (ref.watch(branchProvider).selectedBranch?.id ?? 1);
  return await DatabaseService.instance.getPeakHoursSalesData(range.start, range.end, branchId);
});

