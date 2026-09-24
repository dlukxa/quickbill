import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../providers/report_provider.dart';
import '../../providers/branch_provider.dart';
import '../../services/export_service.dart';
import '../../utils/category_icon_util.dart';
import '../../utils/formatters.dart';
import '../../utils/l10n_extensions.dart';
import '../../widgets/app_card.dart';
import '../../widgets/sinhala_transliteration_input.dart';

/// Executive Category Intelligence & Analytics Dashboard.
/// Enables store executives and managers to analyze business performance categorically.
class CategoryDashboardScreen extends ConsumerStatefulWidget {
  const CategoryDashboardScreen({super.key});

  @override
  ConsumerState<CategoryDashboardScreen> createState() => _CategoryDashboardScreenState();
}

class _CategoryDashboardScreenState extends ConsumerState<CategoryDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterTag = 'all'; // 'all', 'top_sellers', 'high_margin', 'attention_needed'
  String _sortBy = 'valuation_desc'; // 'valuation_desc', 'sales_desc', 'margin_desc', 'units_desc', 'risk_desc'
  String _chartView = 'valuation'; // 'valuation', 'sales', 'health'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryDataAsync = ref.watch(categoryAnalyticsDashboardProvider);
    final dateRange = ref.watch(reportDateRangeProvider);
    final isConsolidated = ref.watch(isConsolidatedProvider);
    final selectedBranch = ref.watch(branchProvider).selectedBranch;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Intelligence',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              isConsolidated ? 'All Branches (ඒකාබද්ධ)' : (selectedBranch?.name ?? 'Main Branch'),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // Branch Switcher
          IconButton(
            tooltip: isConsolidated ? 'Switch to Single Branch' : 'View Consolidated',
            icon: Icon(
              isConsolidated ? Icons.apartment_rounded : Icons.store_mall_directory_outlined,
              color: isConsolidated ? AppTheme.primaryBlue : null,
            ),
            onPressed: () {
              ref.read(isConsolidatedProvider.notifier).state = !isConsolidated;
              ref.invalidate(categoryAnalyticsDashboardProvider);
            },
          ),

          // Date Range Picker
          IconButton(
            tooltip: 'Select Date Range',
            icon: const Icon(Icons.date_range_rounded),
            onPressed: () => _pickDateRange(context, ref, dateRange),
          ),

          // Refresh
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(categoryAnalyticsDashboardProvider);
            },
          ),

          // Export CSV Summary
          categoryDataAsync.when(
            data: (categories) => IconButton(
              tooltip: 'Export Categories CSV',
              icon: const Icon(Icons.download_rounded),
              onPressed: () async {
                await ExportService.instance.exportCategoryAnalytics(
                  categories,
                  localizeCategory: (cat) => context.getLocalizedCategory(cat),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Category Analytics exported to CSV!')),
                  );
                }
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: categoryDataAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Text('No category inventory or sales records found.'),
            );
          }

          // Calculate Key Highlights
          final totalCategories = categories.length;
          final topRevenueCat = (categories.toList()
                ..sort((a, b) => ((b['sales_revenue'] as num?)?.toDouble() ?? 0)
                    .compareTo((a['sales_revenue'] as num?)?.toDouble() ?? 0)))
              .first;
          final topValuationCat = (categories.toList()
                ..sort((a, b) => ((b['retail_value'] as num?)?.toDouble() ?? 0)
                    .compareTo((a['retail_value'] as num?)?.toDouble() ?? 0)))
              .first;
          final topMarginCat = (categories.toList()
                ..sort((a, b) => ((b['margin_percentage'] as num?)?.toDouble() ?? 0)
                    .compareTo((a['margin_percentage'] as num?)?.toDouble() ?? 0)))
              .first;

          // Filter and Sort Categories
          var filteredList = categories.toList();

          // Search
          if (_searchQuery.trim().isNotEmpty) {
            final query = _searchQuery.trim().toLowerCase();
            filteredList = filteredList.where((c) {
              final rawCat = (c['category'] as String? ?? '').toLowerCase();
              final localized = context.getLocalizedCategory(c['category'] as String? ?? '').toLowerCase();
              return rawCat.contains(query) || localized.contains(query);
            }).toList();
          }

          // Tag Filters
          if (_filterTag == 'top_sellers') {
            filteredList = filteredList.where((c) => ((c['sales_revenue'] as num?)?.toDouble() ?? 0) > 0).toList();
            filteredList.sort((a, b) => ((b['sales_revenue'] as num?)?.toDouble() ?? 0)
                .compareTo((a['sales_revenue'] as num?)?.toDouble() ?? 0));
          } else if (_filterTag == 'high_margin') {
            filteredList = filteredList
                .where((c) => ((c['margin_percentage'] as num?)?.toDouble() ?? 0) >= 30.0)
                .toList();
          } else if (_filterTag == 'attention_needed') {
            filteredList = filteredList.where((c) {
              final out = (c['out_of_stock_count'] as num?)?.toInt() ?? 0;
              final low = (c['low_stock_count'] as num?)?.toInt() ?? 0;
              return out > 0 || low > 0;
            }).toList();
          }

          // Sorting
          if (_sortBy == 'valuation_desc') {
            filteredList.sort((a, b) => ((b['retail_value'] as num?)?.toDouble() ?? 0)
                .compareTo((a['retail_value'] as num?)?.toDouble() ?? 0));
          } else if (_sortBy == 'sales_desc') {
            filteredList.sort((a, b) => ((b['sales_revenue'] as num?)?.toDouble() ?? 0)
                .compareTo((a['sales_revenue'] as num?)?.toDouble() ?? 0));
          } else if (_sortBy == 'margin_desc') {
            filteredList.sort((a, b) => ((b['margin_percentage'] as num?)?.toDouble() ?? 0)
                .compareTo((a['margin_percentage'] as num?)?.toDouble() ?? 0));
          } else if (_sortBy == 'units_desc') {
            filteredList.sort((a, b) => ((b['total_units'] as num?)?.toDouble() ?? 0)
                .compareTo((a['total_units'] as num?)?.toDouble() ?? 0));
          } else if (_sortBy == 'risk_desc') {
            filteredList.sort((a, b) {
              final riskA = ((a['out_of_stock_count'] as num?)?.toInt() ?? 0) * 2 +
                  ((a['low_stock_count'] as num?)?.toInt() ?? 0);
              final riskB = ((b['out_of_stock_count'] as num?)?.toInt() ?? 0) * 2 +
                  ((b['low_stock_count'] as num?)?.toInt() ?? 0);
              return riskB.compareTo(riskA);
            });
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(categoryAnalyticsDashboardProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Period & Branch Banner
                _buildPeriodBanner(context, ref, dateRange, isDark),
                const SizedBox(height: 16),

                // Top KPI Matrix
                _buildKpiMatrix(
                  totalCategories: totalCategories,
                  topRevenueCat: topRevenueCat,
                  topValuationCat: topValuationCat,
                  topMarginCat: topMarginCat,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // Visual Distribution Chart Section
                _buildChartSection(categories, isDark),
                const SizedBox(height: 24),

                // Category List Toolbar
                _buildListToolbar(isDark, filteredList.length),
                const SizedBox(height: 12),

                // Category Cards Grid / List
                if (filteredList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No categories match current filters.'),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                                _filterTag = 'all';
                              });
                            },
                            child: const Text('Reset Filters'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filteredList.map((catItem) {
                    return _buildCategoryCard(catItem, isDark);
                  }),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading category analytics: $e')),
      ),
    );
  }

  // ===========================================================================
  // DATE RANGE BANNER
  // ===========================================================================
  Widget _buildPeriodBanner(BuildContext context, WidgetRef ref, ReportDateRange range, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Text(
            'Sales Period: ${DateFormat('dd MMM').format(range.start)} - ${DateFormat('dd MMM yyyy').format(range.end)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const Spacer(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetButton(ref, 'Today', ReportPreset.day, range.preset),
                const SizedBox(width: 4),
                _buildPresetButton(ref, 'This Week', ReportPreset.week, range.preset),
                const SizedBox(width: 4),
                _buildPresetButton(ref, 'This Month', ReportPreset.month, range.preset),
                const SizedBox(width: 4),
                _buildPresetButton(ref, 'Year', ReportPreset.year, range.preset),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(WidgetRef ref, String label, ReportPreset preset, ReportPreset current) {
    final isSelected = current == preset;
    return InkWell(
      onTap: () {
        ref.read(reportDateRangeProvider.notifier).state = ReportDateRange.fromPreset(preset);
        ref.invalidate(categoryAnalyticsDashboardProvider);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // EXECUTIVE KPI MATRIX
  // ===========================================================================
  Widget _buildKpiMatrix({
    required int totalCategories,
    required Map<String, dynamic> topRevenueCat,
    required Map<String, dynamic> topValuationCat,
    required Map<String, dynamic> topMarginCat,
    required bool isDark,
  }) {
    final topRevName = context.getLocalizedCategory(topRevenueCat['category'] as String? ?? 'General');
    final topRevVal = (topRevenueCat['sales_revenue'] as num?)?.toDouble() ?? 0.0;

    final topValName = context.getLocalizedCategory(topValuationCat['category'] as String? ?? 'General');
    final topValAmount = (topValuationCat['retail_value'] as num?)?.toDouble() ?? 0.0;

    final topMarginName = context.getLocalizedCategory(topMarginCat['category'] as String? ?? 'General');
    final topMarginVal = (topMarginCat['margin_percentage'] as num?)?.toDouble() ?? 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'ACTIVE CATEGORIES',
                  mainValue: '$totalCategories',
                  subtitle: 'Categories in Store',
                  color: AppTheme.primaryBlue,
                  icon: Icons.category_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'TOP REVENUE CATEGORY',
                  mainValue: topRevName,
                  subtitle: '${Formatters.currency(topRevVal)} Sales',
                  color: AppTheme.primaryGreen,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'HIGHEST STOCK VALUE',
                  mainValue: topValName,
                  subtitle: '${Formatters.currency(topValAmount)} Retail Stock',
                  color: const Color(0xFF6366F1),
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'MOST PROFITABLE',
                  mainValue: topMarginName,
                  subtitle: '${topMarginVal.toStringAsFixed(1)}% Gross Margin',
                  color: const Color(0xFFEC4899),
                  icon: Icons.auto_graph_rounded,
                ),
              ),
            ],
          );
        }

        // Mobile 2x2 grid
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'CATEGORIES',
                    mainValue: '$totalCategories',
                    subtitle: 'Active Categories',
                    color: AppTheme.primaryBlue,
                    icon: Icons.category_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    title: 'TOP REVENUE',
                    mainValue: topRevName,
                    subtitle: Formatters.currency(topRevVal),
                    color: AppTheme.primaryGreen,
                    icon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'TOP STOCK VALUE',
                    mainValue: topValName,
                    subtitle: Formatters.currency(topValAmount),
                    color: const Color(0xFF6366F1),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    title: 'TOP MARGIN %',
                    mainValue: topMarginName,
                    subtitle: '${topMarginVal.toStringAsFixed(1)}% Margin',
                    color: const Color(0xFFEC4899),
                    icon: Icons.auto_graph_rounded,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String mainValue,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mainValue,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CHART SECTION (VALUATION vs SALES SHARE)
  // ===========================================================================
  Widget _buildChartSection(List<Map<String, dynamic>> categories, bool isDark) {
    final double totalValuation = categories.fold(
      0.0,
      (sum, item) => sum + ((item['retail_value'] as num?)?.toDouble() ?? 0.0),
    );

    final double totalSales = categories.fold(
      0.0,
      (sum, item) => sum + ((item['sales_revenue'] as num?)?.toDouble() ?? 0.0),
    );

    // Limit chart slices to top 6 + other
    final sortedForChart = categories.toList()
      ..sort((a, b) {
        final valA = _chartView == 'valuation'
            ? ((a['retail_value'] as num?)?.toDouble() ?? 0)
            : ((a['sales_revenue'] as num?)?.toDouble() ?? 0);
        final valB = _chartView == 'valuation'
            ? ((b['retail_value'] as num?)?.toDouble() ?? 0)
            : ((b['sales_revenue'] as num?)?.toDouble() ?? 0);
        return valB.compareTo(valA);
      });

    final topSlices = sortedForChart.take(6).toList();
    final remainder = sortedForChart.skip(6).toList();
    final double remainderVal = remainder.fold(
      0.0,
      (sum, item) =>
          sum +
          (_chartView == 'valuation'
              ? ((item['retail_value'] as num?)?.toDouble() ?? 0)
              : ((item['sales_revenue'] as num?)?.toDouble() ?? 0)),
    );

    final baseTotal = _chartView == 'valuation' ? totalValuation : totalSales;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CATEGORY DISTRIBUTION SHARE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'valuation',
                    label: Text('Stock Value', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 'sales',
                    label: Text('Sales Revenue', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_chartView},
                onSelectionChanged: (set) => setState(() => _chartView = set.first),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (baseTotal <= 0)
            const SizedBox(
              height: 180,
              child: Center(child: Text('No value data available for this chart view.')),
            )
          else
            Row(
              children: [
                // Donut Pie Chart
                SizedBox(
                  width: 170,
                  height: 170,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 42,
                      sections: [
                        ...topSlices.map((item) {
                          final cat = item['category'] as String? ?? 'General';
                          final val = _chartView == 'valuation'
                              ? ((item['retail_value'] as num?)?.toDouble() ?? 0)
                              : ((item['sales_revenue'] as num?)?.toDouble() ?? 0);
                          final color = CategoryIconUtil.getColorForMainCategory(cat);
                          return PieChartSectionData(
                            value: val,
                            color: color,
                            title: '',
                            radius: 35,
                          );
                        }),
                        if (remainderVal > 0)
                          PieChartSectionData(
                            value: remainderVal,
                            color: Colors.grey.shade400,
                            title: '',
                            radius: 35,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Chart Legend & Proportions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...topSlices.map((item) {
                        final cat = item['category'] as String? ?? 'General';
                        final localized = context.getLocalizedCategory(cat);
                        final val = _chartView == 'valuation'
                            ? ((item['retail_value'] as num?)?.toDouble() ?? 0)
                            : ((item['sales_revenue'] as num?)?.toDouble() ?? 0);
                        final pct = baseTotal > 0 ? (val / baseTotal) * 100 : 0.0;
                        final color = CategoryIconUtil.getColorForMainCategory(cat);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  localized,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(1)}% (${Formatters.currency(val)})',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (remainderVal > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Other Categories',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                '${((remainderVal / baseTotal) * 100).toStringAsFixed(1)}% (${Formatters.currency(remainderVal)})',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LIST TOOLBAR & FILTERS
  // ===========================================================================
  Widget _buildListToolbar(bool isDark, int resultCount) {
    return Column(
      children: [
        Row(
          children: [
            // Search Input with Singlish Transliteration support
            Expanded(
              child: SinglishTextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                showSuggestionBanner: false,
                decoration: InputDecoration(
                  hintText: 'Search category (e.g. "sini", "බීම", "grocery")...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Sort Dropdown
            DropdownButton<String>(
              value: _sortBy,
              items: const [
                DropdownMenuItem(value: 'valuation_desc', child: Text('Sort: Highest Stock Value', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'sales_desc', child: Text('Sort: Highest Sales', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'margin_desc', child: Text('Sort: Highest Margin %', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'units_desc', child: Text('Sort: Most Units', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'risk_desc', child: Text('Sort: Most Low/Out of Stock', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _sortBy = val);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Filter Tag Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterTag('All Categories ($resultCount)', 'all'),
              const SizedBox(width: 6),
              _buildFilterTag('Top Sellers', 'top_sellers'),
              const SizedBox(width: 6),
              _buildFilterTag('High Margin (≥30%)', 'high_margin'),
              const SizedBox(width: 6),
              _buildFilterTag('Attention Needed (Low/Out)', 'attention_needed'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTag(String label, String value) {
    final isSelected = _filterTag == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: AppTheme.primaryBlue,
      onSelected: (selected) {
        if (selected) setState(() => _filterTag = value);
      },
    );
  }

  // ===========================================================================
  // CATEGORY CARD
  // ===========================================================================
  Widget _buildCategoryCard(Map<String, dynamic> catItem, bool isDark) {
    final rawCat = catItem['category'] as String? ?? 'General';
    final localizedCat = context.getLocalizedCategory(rawCat);
    final icon = CategoryIconUtil.getIconForMainCategory(rawCat);
    final color = CategoryIconUtil.getColorForMainCategory(rawCat);

    final productCount = catItem['product_count'] as int? ?? 0;
    final totalUnits = (catItem['total_units'] as num?)?.toDouble() ?? 0.0;
    final retail = (catItem['retail_value'] as num?)?.toDouble() ?? 0.0;
    final cost = (catItem['cost_value'] as num?)?.toDouble() ?? 0.0;
    final margin = (catItem['margin'] as num?)?.toDouble() ?? 0.0;
    final marginPct = (catItem['margin_percentage'] as num?)?.toDouble() ?? 0.0;

    final salesRevenue = (catItem['sales_revenue'] as num?)?.toDouble() ?? 0.0;
    final unitsSold = (catItem['units_sold'] as num?)?.toDouble() ?? 0.0;

    final healthyCount = (catItem['healthy_stock_count'] as num?)?.toInt() ?? 0;
    final lowCount = (catItem['low_stock_count'] as num?)?.toInt() ?? 0;
    final outCount = (catItem['out_of_stock_count'] as num?)?.toInt() ?? 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCategoryDrilldown(rawCat, localizedCat, color, icon),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon, Titles, Drilldown Arrow
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizedCat,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '$rawCat • $productCount Products • ${NumberFormat('#,###').format(totalUnits)} units in stock',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.currency(retail),
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    ),
                    const Text('Retail Stock Value', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 14),

            // Financial & Sales Metrics Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniMetric('Cost Investment', Formatters.currency(cost)),
                  _buildMiniMetric('Est. Margin', '${Formatters.currency(margin)} (${marginPct.toStringAsFixed(1)}%)',
                      color: marginPct >= 20 ? AppTheme.primaryGreen : AppTheme.warningOrange),
                  _buildMiniMetric('Period Sales', Formatters.currency(salesRevenue),
                      sublabel: '${NumberFormat('#,###').format(unitsSold)} sold'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Stock Health Distribution Bar
            Row(
              children: [
                const Text('Stock Health: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                _buildHealthCountBadge(healthyCount, 'Healthy', AppTheme.primaryGreen),
                const SizedBox(width: 6),
                _buildHealthCountBadge(lowCount, 'Low Stock', AppTheme.warningOrange),
                const SizedBox(width: 6),
                _buildHealthCountBadge(outCount, 'Out of Stock', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, {Color? color, String? sublabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (sublabel != null)
          Text(sublabel, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  Widget _buildHealthCountBadge(int count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  // ===========================================================================
  // CATEGORY DEEP-DIVE DRILLDOWN MODAL
  // ===========================================================================
  void _openCategoryDrilldown(String rawCat, String localizedCat, Color color, IconData icon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryDrilldownSheet(
        category: rawCat,
        localizedCategory: localizedCat,
        categoryColor: color,
        categoryIcon: icon,
      ),
    );
  }

  // Date Range Picker Dialog Helper
  void _pickDateRange(BuildContext context, WidgetRef ref, ReportDateRange dateRange) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: dateRange.start, end: dateRange.end),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      ref.read(reportDateRangeProvider.notifier).state = ReportDateRange(
        start: picked.start,
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999),
        preset: ReportPreset.custom,
      );
      ref.invalidate(categoryAnalyticsDashboardProvider);
    }
  }
}

/// Drill-down sheet displaying all products inside a chosen category
class _CategoryDrilldownSheet extends ConsumerStatefulWidget {
  final String category;
  final String localizedCategory;
  final Color categoryColor;
  final IconData categoryIcon;

  const _CategoryDrilldownSheet({
    required this.category,
    required this.localizedCategory,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  ConsumerState<_CategoryDrilldownSheet> createState() => _CategoryDrilldownSheetState();
}

class _CategoryDrilldownSheetState extends ConsumerState<_CategoryDrilldownSheet> {
  final TextEditingController _productSearchController = TextEditingController();
  String _productSearchQuery = '';
  String _productHealthFilter = 'all'; // 'all', 'healthy', 'low', 'out'

  @override
  void dispose() {
    _productSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(categoryProductsDrilldownProvider(widget.category));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1E27) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.categoryIcon, color: widget.categoryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.localizedCategory,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            'Category Products Drill-down (${widget.category})',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    productsAsync.when(
                      data: (prods) => IconButton(
                        tooltip: 'Export Category CSV',
                        icon: const Icon(Icons.download_rounded),
                        onPressed: () async {
                          await ExportService.instance.exportCategoryProductsDrilldown(widget.category, prods);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${widget.localizedCategory} products exported to CSV!')),
                            );
                          }
                        },
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Search & Health Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SinglishTextField(
                        controller: _productSearchController,
                        onChanged: (val) => setState(() => _productSearchQuery = val),
                        showSuggestionBanner: false,
                        decoration: InputDecoration(
                          hintText: 'Search product in ${widget.localizedCategory}...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _productHealthFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Stock', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'healthy', child: Text('Healthy Only', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'low', child: Text('Low Stock', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'out', child: Text('Out of Stock', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _productHealthFilter = val);
                      },
                    ),
                  ],
                ),
              ),

              // Products List
              Expanded(
                child: productsAsync.when(
                  data: (products) {
                    var filtered = products.toList();

                    // Search
                    if (_productSearchQuery.trim().isNotEmpty) {
                      final q = _productSearchQuery.trim().toLowerCase();
                      filtered = filtered.where((p) {
                        final name = (p['name'] as String? ?? '').toLowerCase();
                        final sinhala = (p['name_sinhala'] as String? ?? '').toLowerCase();
                        final barcode = (p['base_barcode'] as String? ?? '').toLowerCase();
                        return name.contains(q) || sinhala.contains(q) || barcode.contains(q);
                      }).toList();
                    }

                    // Health filter
                    if (_productHealthFilter != 'all') {
                      filtered = filtered.where((p) => p['status'] == _productHealthFilter).toList();
                    }

                    if (filtered.isEmpty) {
                      return const Center(child: Text('No products match search criteria.'));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final name = p['name'] as String;
                        final sinhala = p['name_sinhala'] as String?;
                        final stock = (p['current_stock'] as num).toDouble();
                        final unit = p['unit'] as String? ?? 'pcs';
                        final price = (p['price'] as num).toDouble();
                        final cost = (p['cost_price'] as num).toDouble();
                        final retailVal = (p['retail_valuation'] as num).toDouble();
                        final marginPct = (p['margin_percentage'] as num).toDouble();
                        final status = p['status'] as String;
                        final salesQty = (p['period_sales_qty'] as num).toDouble();
                        final salesRev = (p['period_sales_revenue'] as num).toDouble();

                        Color statusColor = AppTheme.primaryGreen;
                        String statusLabel = 'In Stock';
                        if (status == 'out') {
                          statusColor = Colors.red;
                          statusLabel = 'Out of Stock';
                        } else if (status == 'low') {
                          statusColor = AppTheme.warningOrange;
                          statusLabel = 'Low Stock';
                        }

                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (sinhala != null && sinhala.isNotEmpty)
                                      Text(sinhala, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Price: ${Formatters.currency(price)} • Cost: ${Formatters.currency(cost)} • Margin: ${marginPct.toStringAsFixed(1)}%',
                                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                                    ),
                                    if (salesQty > 0)
                                      Text(
                                        'Sold: $salesQty $unit (${Formatters.currency(salesRev)})',
                                        style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${stock % 1 == 0 ? stock.toInt() : stock} $unit',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Formatters.currency(retailVal),
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    const Text('Retail Valuation', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading products: $e')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
