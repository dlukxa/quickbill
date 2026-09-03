import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../services/database_service.dart';
import 'branch_provider.dart';
import 'customer_provider.dart';

enum CustomerSegment {
  champion,   // High Value + Recent
  loyalist,   // High Frequency
  bigSpender, // High Monetary
  atRisk,     // High Value + Not Recent
  lost,       // Not Recent
  recent,     // New Customer
  regular,    // Everyone else
}

class CustomerInsight {
  final Customer customer;
  final int purchaseCount;
  final double totalSpent;
  final DateTime? lastPurchaseDate;
  final CustomerSegment segment;

  CustomerInsight({
    required this.customer,
    required this.purchaseCount,
    required this.totalSpent,
    required this.lastPurchaseDate,
    required this.segment,
  });
}

final customerInsightsProvider = FutureProvider<List<CustomerInsight>>((ref) async {
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  final customers = await ref.watch(customersProvider.future);
  
  // Fetch aggregated stats from DB
  final stats = await DatabaseService.instance.getCustomerAnalytics(branchId);
  final statsMap = {for (var s in stats) s['customer_id']: s};

  final List<CustomerInsight> insights = [];

  for (final customer in customers) {
    if (customer.id == null) continue;

    final stat = statsMap[customer.id];
    final count = (stat?['frequency'] as int?) ?? 0;
    final spent = (stat?['monetary'] as num?)?.toDouble() ?? 0.0;
    final lastDateStr = stat?['last_purchase_date'] as String?;
    final lastDate = lastDateStr != null ? DateTime.parse(lastDateStr) : null;

    final segment = _calculateSegment(count, spent, lastDate);

    insights.add(CustomerInsight(
      customer: customer,
      purchaseCount: count,
      totalSpent: spent,
      lastPurchaseDate: lastDate,
      segment: segment,
    ));
  }

  // Sort by segment priority (Champions first)
  insights.sort((a, b) => a.segment.index.compareTo(b.segment.index));

  return insights;
});

CustomerSegment _calculateSegment(int count, double spent, DateTime? lastDate) {
  if (count == 0 || lastDate == null) return CustomerSegment.regular;

  final daysSinceLast = DateTime.now().difference(lastDate).inDays;

  // Simple Rule-Based Segmentation
  // These thresholds can be made dynamic/configurable later

  if (daysSinceLast < 30 && count >= 5 && spent > 5000) {
    return CustomerSegment.champion;
  }
  
  if (daysSinceLast > 45 && spent > 5000) {
    return CustomerSegment.atRisk;
  }

  if (daysSinceLast > 90) {
    return CustomerSegment.lost;
  }

  if (count >= 5) {
    return CustomerSegment.loyalist;
  }

  if (spent > 10000) {
    return CustomerSegment.bigSpender;
  }

  if (daysSinceLast < 30 && count == 1) {
    return CustomerSegment.recent;
  }

  return CustomerSegment.regular;
}

extension SegmentColor on CustomerSegment {
  Color get color {
    switch (this) {
      case CustomerSegment.champion: return Colors.purple;
      case CustomerSegment.loyalist: return Colors.blue;
      case CustomerSegment.bigSpender: return Colors.green;
      case CustomerSegment.atRisk: return Colors.orange;
      case CustomerSegment.lost: return Colors.grey;
      case CustomerSegment.recent: return Colors.teal;
      case CustomerSegment.regular: return Colors.blueGrey;
    }
  }

  String get label {
    switch (this) {
      case CustomerSegment.champion: return '🏆 Champion';
      case CustomerSegment.loyalist: return '💎 Loyalist';
      case CustomerSegment.bigSpender: return '💰 Big Spender';
      case CustomerSegment.atRisk: return '⚠️ At Risk';
      case CustomerSegment.lost: return '💤 Lost';
      case CustomerSegment.recent: return '🌱 New';
      case CustomerSegment.regular: return 'Regular';
    }
  }
}

final customerSegmentFilterProvider = StateProvider<CustomerSegment?>((ref) => null);

final filteredCustomerInsightsProvider = Provider<List<CustomerInsight>>((ref) {
  final insights = ref.watch(customerInsightsProvider).value ?? [];
  final segmentFilter = ref.watch(customerSegmentFilterProvider);
  final searchQuery = ref.watch(customerSearchProvider).toLowerCase();

  return insights.where((insight) {
    // 1. Filter by Segment
    if (segmentFilter != null && insight.segment != segmentFilter) {
      return false;
    }

    // 2. Filter by Search Query
    if (searchQuery.isNotEmpty) {
      final nameMatches = insight.customer.name.toLowerCase().contains(searchQuery);
      final phoneMatches = insight.customer.phone?.contains(searchQuery) ?? false;
      if (!nameMatches && !phoneMatches) {
        return false;
      }
    }

    return true;
  }).toList();
});
