import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/stock_expiry_item.dart';
import '../../providers/expiry_provider.dart';
import '../../providers/preference_provider.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/add_stock_dialog.dart';
import '../stock/batch_list_screen.dart';

/// Comprehensive, supermarket-grade Expiry Management screen.
class ExpiryManagementScreen extends ConsumerStatefulWidget {
  final ExpiryTab? initialTab;
  const ExpiryManagementScreen({super.key, this.initialTab});

  @override
  ConsumerState<ExpiryManagementScreen> createState() => _ExpiryManagementScreenState();
}

class _ExpiryManagementScreenState extends ConsumerState<ExpiryManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(expiryFilterProvider.notifier).setTab(widget.initialTab!);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;

    final summary = ref.watch(expirySummaryProvider);
    final threshold = ref.watch(expiryAlertThresholdProvider);
    final filter = ref.watch(expiryFilterProvider);
    final items = ref.watch(filteredExpiryItemsProvider);
    final allItemsAsync = ref.watch(stockExpiryItemsProvider);

    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    // Extract unique categories for filter
    final categories = allItemsAsync.maybeWhen(
      data: (list) => list.map((i) => i.category).whereType<String>().toSet().toList()..sort(),
      orElse: () => <String>[],
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expiry Management & Alerts',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Track expired stock, upcoming expiries, and FEFO inventory batches',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Expiry Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(stockExpiryItemsProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(stockExpiryItemsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top KPI Summary Cards ──
              _buildSummaryCards(summary, isDark, textPrimary, textSecondary),
              const SizedBox(height: 20),

              // ── 2. Alert Threshold Selector Row ──
              _buildThresholdSelector(threshold, isDark, cardBg, borderColor, textPrimary, textSecondary),
              const SizedBox(height: 20),

              // ── 3. Tabs (Expired / Expiring Soon / All Valid / All) ──
              _buildTabsSection(filter.tab, summary, isDark, cardBg, borderColor, textPrimary),
              const SizedBox(height: 16),

              // ── 4. Search and Filters Bar ──
              _buildFilterBar(filter, categories, isDark, cardBg, borderColor, textPrimary, textSecondary),
              const SizedBox(height: 16),

              // ── 5. Items Data Table / List ──
              _buildItemsSection(items, allItemsAsync.isLoading, isDark, cardBg, borderColor, textPrimary, textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Summary Cards ──────────────────────────────────────────────────────────

  Widget _buildSummaryCards(ExpirySummary summary, bool isDark, Color textPrimary, Color textSecondary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        const cardCount = 4;
        final cardWidth = isNarrow
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - (cardCount - 1) * 12) / cardCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // 1. Total Expired Products
            _buildKpiCard(
              width: cardWidth,
              title: 'Expired Products',
              value: summary.totalExpiredProducts.toString(),
              subtitle: 'Distinct items expired',
              icon: Icons.dangerous_rounded,
              color: AppTheme.errorRed,
              isDark: isDark,
              hasWarning: summary.totalExpiredProducts > 0,
            ),
            // 2. Total Expired Stock Quantity
            _buildKpiCard(
              width: cardWidth,
              title: 'Expired Stock Units',
              value: summary.totalExpiredStockQty.toStringAsFixed(summary.totalExpiredStockQty.truncateToDouble() == summary.totalExpiredStockQty ? 0 : 1),
              subtitle: 'Units to remove from shelves',
              icon: Icons.remove_shopping_cart_rounded,
              color: const Color(0xFFDC2626),
              isDark: isDark,
              hasWarning: summary.totalExpiredStockQty > 0,
            ),
            // 3. Expiring Soon Products
            _buildKpiCard(
              width: cardWidth,
              title: 'Expiring Soon',
              value: summary.expiringSoonProducts.toString(),
              subtitle: 'Items near expiry',
              icon: Icons.timer_outlined,
              color: const Color(0xFFF59E0B),
              isDark: isDark,
              hasWarning: summary.expiringSoonProducts > 0,
            ),
            // 4. Expiring Soon Stock Quantity
            _buildKpiCard(
              width: cardWidth,
              title: 'Expiring Stock Units',
              value: summary.expiringSoonStockQty.toStringAsFixed(summary.expiringSoonStockQty.truncateToDouble() == summary.expiringSoonStockQty ? 0 : 1),
              subtitle: 'Units to discount or prioritize',
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFD97706),
              isDark: isDark,
              hasWarning: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required bool hasWarning,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasWarning ? color.withValues(alpha: 0.5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: hasWarning ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasWarning ? color.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Threshold Selector ─────────────────────────────────────────────────────

  Widget _buildThresholdSelector(
    int threshold,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final thresholds = [7, 15, 30, 60, 90];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, size: 18, color: textSecondary),
          const SizedBox(width: 10),
          Text(
            'Alert Period:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: thresholds.map((t) {
                final isSelected = t == threshold;
                return ChoiceChip(
                  label: Text('$t Days${t == 30 ? " (Default)" : ""}'),
                  selected: isSelected,
                  selectedColor: const Color(0xFFF59E0B),
                  backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFF59E0B) : borderColor,
                  ),
                  onSelected: (_) {
                    ref.read(expiryAlertThresholdProvider.notifier).state = t;
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tabs ───────────────────────────────────────────────────────────────────

  Widget _buildTabsSection(
    ExpiryTab activeTab,
    ExpirySummary summary,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _buildTabButton(
            title: 'Expired Products',
            count: summary.totalExpiredProducts,
            isSelected: activeTab == ExpiryTab.expired,
            color: AppTheme.errorRed,
            isDark: isDark,
            onTap: () => ref.read(expiryFilterProvider.notifier).setTab(ExpiryTab.expired),
          ),
          _buildTabButton(
            title: 'Expiring Soon',
            count: summary.expiringSoonProducts,
            isSelected: activeTab == ExpiryTab.expiringSoon,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            onTap: () => ref.read(expiryFilterProvider.notifier).setTab(ExpiryTab.expiringSoon),
          ),
          _buildTabButton(
            title: 'All Valid Stock',
            count: summary.validProducts,
            isSelected: activeTab == ExpiryTab.valid,
            color: const Color(0xFF10B981),
            isDark: isDark,
            onTap: () => ref.read(expiryFilterProvider.notifier).setTab(ExpiryTab.valid),
          ),
          _buildTabButton(
            title: 'All Tracked',
            count: summary.totalTrackedProducts,
            isSelected: activeTab == ExpiryTab.all,
            color: const Color(0xFF3B82F6),
            isDark: isDark,
            onTap: () => ref.read(expiryFilterProvider.notifier).setTab(ExpiryTab.all),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required int count,
    required bool isSelected,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.25 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Filter Bar ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar(
    ExpiryFilterState filter,
    List<String> categories,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 1. Search Box
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(expiryFilterProvider.notifier).setSearchQuery(val);
              },
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Search name, Sinhala, barcode...',
                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(expiryFilterProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
            ),
          ),

          // 2. Category Dropdown
          DropdownButton<String?>(
            value: filter.selectedCategory,
            hint: Text('All Categories', style: GoogleFonts.inter(fontSize: 12.5, color: textSecondary)),
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Categories'),
              ),
              ...categories.map((c) => DropdownMenuItem<String?>(
                value: c,
                child: Text(c),
              )),
            ],
            onChanged: (cat) {
              ref.read(expiryFilterProvider.notifier).setCategory(cat);
            },
          ),

          // 3. Date Range Picker
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range_rounded, size: 16),
            label: Text(
              filter.startDate != null && filter.endDate != null
                  ? '${DateFormat('MM/dd').format(filter.startDate!)} - ${DateFormat('MM/dd').format(filter.endDate!)}'
                  : 'Date Range',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: filter.startDate != null ? const Color(0xFFF59E0B) : borderColor),
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                initialDateRange: filter.startDate != null && filter.endDate != null
                    ? DateTimeRange(start: filter.startDate!, end: filter.endDate!)
                    : null,
              );
              if (picked != null) {
                ref.read(expiryFilterProvider.notifier).setDateRange(picked.start, picked.end);
              }
            },
          ),

          if (filter.startDate != null || filter.endDate != null)
            IconButton(
              tooltip: 'Clear date filter',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () {
                ref.read(expiryFilterProvider.notifier).setDateRange(null, null);
              },
            ),

          // 4. Sort Dropdown
          DropdownButton<ExpirySort>(
            value: filter.sortBy,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: ExpirySort.expiryAsc, child: Text('Sort: Oldest/Nearest Expiry')),
              DropdownMenuItem(value: ExpirySort.expiryDesc, child: Text('Sort: Furthest Expiry')),
              DropdownMenuItem(value: ExpirySort.qtyDesc, child: Text('Sort: Highest Stock')),
              DropdownMenuItem(value: ExpirySort.qtyAsc, child: Text('Sort: Lowest Stock')),
              DropdownMenuItem(value: ExpirySort.nameAsc, child: Text('Sort: Product Name A-Z')),
            ],
            onChanged: (sort) {
              if (sort != null) {
                ref.read(expiryFilterProvider.notifier).setSortBy(sort);
              }
            },
          ),
        ],
      ),
    );
  }

  // ─── Items Table / List ─────────────────────────────────────────────────────

  Widget _buildItemsSection(
    List<StockExpiryItem> items,
    bool isLoading,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
      );
    }

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            Text(
              'No products found for this section',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'All products in this filter category have valid shelf life or no items matched.',
              style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('Product', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary))),
                Expanded(flex: 3, child: Text('Barcode / Batch', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary))),
                Expanded(flex: 2, child: Text('Stock', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary))),
                Expanded(flex: 3, child: Text('Expiry Date', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary))),
                Expanded(flex: 3, child: Text('Status & Life', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary))),
                const SizedBox(width: 80, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // Items List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildItemRow(item, isDark, borderColor, textPrimary, textSecondary);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    StockExpiryItem item,
    bool isDark,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final statusColor = item.statusColor();
    final isExpired = item.isExpired;

    return Container(
      color: isExpired
          ? AppTheme.errorRed.withValues(alpha: isDark ? 0.08 : 0.04)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 1. Product Name & Category
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.nameSinhala != null && item.nameSinhala!.isNotEmpty)
                  Text(
                    item.nameSinhala!,
                    style: GoogleFonts.notoSansSinhala(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (item.category != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.category!,
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: textSecondary),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Barcode & Batch Number
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 14, color: textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.barcode ?? '-',
                        style: GoogleFonts.sourceCodePro(fontSize: 12, color: textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.batchNumber != null
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.batchNumber != null ? 'Batch: ${item.batchNumber}' : 'Direct Stock',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: item.batchNumber != null ? const Color(0xFF3B82F6) : textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Stock Quantity
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.formattedStock,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: item.stock <= 0 ? Colors.red : textPrimary,
                  ),
                ),
                Text(
                  Formatters.currency(item.price),
                  style: GoogleFonts.inter(fontSize: 11.5, color: textSecondary),
                ),
              ],
            ),
          ),

          // 4. Expiry Date
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('yyyy-MM-dd').format(item.expiryDate),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isExpired ? AppTheme.errorRed : textPrimary,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(item.expiryDate),
                  style: GoogleFonts.inter(fontSize: 11.5, color: textSecondary),
                ),
              ],
            ),
          ),

          // 5. Status & Shelf Life Badge
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpired ? Icons.warning_rounded : Icons.schedule_rounded,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      item.statusLabel(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. Action Menu
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) => _handleItemAction(context, item, action),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'adjust',
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 18, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text('Adjust / Restock'),
                      ],
                    ),
                  ),
                  if (item.batchId != null)
                    const PopupMenuItem(
                      value: 'batches',
                      child: Row(
                        children: [
                          Icon(Icons.format_list_bulleted_rounded, size: 18, color: Color(0xFF3B82F6)),
                          SizedBox(width: 8),
                          Text('View All Batches'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'write_off',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_rounded, size: 18, color: AppTheme.errorRed),
                        SizedBox(width: 8),
                        Text('Write-Off Stock (Waste)', style: TextStyle(color: AppTheme.errorRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions Handling ───────────────────────────────────────────────────────

  void _handleItemAction(BuildContext context, StockExpiryItem item, String action) async {
    final product = await DatabaseService.instance.getProductById(item.productId);
    if (product == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product not found in inventory')),
      );
      return;
    }

    if (!mounted) return;

    if (action == 'adjust') {
      await AddStockDialog.show(context, product: product!, isDark: Theme.of(context).brightness == Brightness.dark);
      ref.invalidate(stockExpiryItemsProvider);
    } else if (action == 'batches') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BatchListScreen(product: product!),
        ),
      ).then((_) => ref.invalidate(stockExpiryItemsProvider));
    } else if (action == 'write_off') {
      _showWriteOffDialog(context, item, product!);
    }
  }

  /// Stock Write-Off modal allowing staff to mark stock as expired, damaged, or spoiled.
  void _showWriteOffDialog(BuildContext context, StockExpiryItem item, dynamic product) {
    final quantityController = TextEditingController(text: item.stock.toString());
    final notesController = TextEditingController();
    String reason = item.isExpired ? 'expired' : 'damaged';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_sweep_rounded, color: AppTheme.errorRed, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mark Stock as Waste',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      Text(
                        item.displayName,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Available Stock:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${item.stock} ${item.unit}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Quantity to Remove', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Enter quantity',
                      suffixText: item.unit,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Wastage Reason', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'expired', child: Text('Expired Stock')),
                      DropdownMenuItem(value: 'damaged', child: Text('Damaged / Broken')),
                      DropdownMenuItem(value: 'spoiled', child: Text('Spoiled / Rotten')),
                      DropdownMenuItem(value: 'returned to supplier', child: Text('Returned to Supplier')),
                      DropdownMenuItem(value: 'other', child: Text('Other Write-off')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => reason = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Text('Audit Notes (Optional)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Cleared from dairy cooler by staff',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final qty = double.tryParse(quantityController.text.trim());
                  if (qty == null || qty <= 0 || qty > item.stock) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid quantity up to available stock.')),
                    );
                    return;
                  }

                  Navigator.pop(dialogCtx);

                  await ref.read(expiryActionsProvider).writeOffStock(
                    item: item,
                    quantity: qty,
                    reason: reason,
                    notes: notesController.text.trim(),
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully written off $qty ${item.unit} (${reason.toUpperCase()}).'),
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                    );
                  }
                },
                child: const Text('Confirm Write-off'),
              ),
            ],
          );
        },
      ),
    );
  }
}
