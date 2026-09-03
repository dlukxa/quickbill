import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/sale.dart';
import '../../providers/preference_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/sale_provider.dart';
import '../../services/export_service.dart';
import '../../services/pdf_service.dart';
import '../../services/sync_service.dart';
import '../../utils/formatters.dart';
import '../../utils/pos_l10n.dart';
import '../../widgets/animate_in.dart';
import 'sale_details_screen.dart';

/// State provider for live search query in Bill History
final _billSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// State provider for payment method filter in Bill History ('all', 'cash', 'card', 'credit', 'other')
final _billPaymentFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

/// Modern, dedicated BILL HISTORY & Sales Report Screen.
class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final l10n = PosL10n.of(settings.languageCode);
    final dateRange = ref.watch(reportDateRangeProvider);
    final salesAsync = ref.watch(salesByRangeProvider(dateRange));
    final searchQuery = ref.watch(_billSearchQueryProvider).trim().toLowerCase();
    final paymentFilter = ref.watch(_billPaymentFilterProvider).toLowerCase();

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          l10n.billHistory,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: titleColor,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Filter by Date',
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => _showDateRangePicker(context, ref, dateRange),
          ),
          salesAsync.when(
            data: (sales) => Row(
              children: [
                IconButton(
                  tooltip: 'Export CSV',
                  icon: const Icon(Icons.table_view_outlined),
                  onPressed: () => ExportService.instance.exportSalesToCsv(sales, dateRange.start, dateRange.end),
                ),
                IconButton(
                  tooltip: 'Export PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () {
                    PdfService.instance.generateSalesReport(sales, dateRange.start, dateRange.end, settings: settings);
                  },
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: salesAsync.when(
        data: (sales) {
          // Calculate KPI aggregates
          final int totalBills = sales.length;
          final double totalSales = sales.fold(0.0, (sum, s) => sum + s.total);
          
          double cashSales = 0.0;
          double cardSales = 0.0;
          double otherSales = 0.0;

          for (final s in sales) {
            final method = s.paymentMethod.toLowerCase();
            if (method == 'cash') {
              cashSales += s.total;
            } else if (method == 'card') {
              cardSales += s.total;
            } else {
              otherSales += s.total;
            }
          }

          // Apply live search and payment method filter
          final filteredSales = sales.where((s) {
            if (paymentFilter != 'all' && s.paymentMethod.toLowerCase() != paymentFilter) {
              return false;
            }
            if (searchQuery.isNotEmpty) {
              final billMatches = s.billNumber.toLowerCase().contains(searchQuery);
              final custMatches = s.customerName != null && s.customerName!.toLowerCase().contains(searchQuery);
              final cashMatches = s.cashierName != null && s.cashierName!.toLowerCase().contains(searchQuery);
              final amountMatches = s.total.toString().contains(searchQuery);
              if (!billMatches && !custMatches && !cashMatches && !amountMatches) {
                return false;
              }
            }
            return true;
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── QUICK DATE PRESETS ──
                      _buildQuickDatePresets(dateRange),
                      const SizedBox(height: 14),

                      // ── SUMMARY KPI DASHBOARD CARD ──
                      _buildSummaryCard(
                        dateRange: dateRange,
                        totalBills: totalBills,
                        totalSales: totalSales,
                        cashSales: cashSales,
                        cardSales: cardSales,
                        otherSales: otherSales,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        titleColor: titleColor,
                        subColor: subColor,
                        l10n: l10n,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 18),

                      // ── SEARCH & PAYMENT FILTERS ──
                      _buildSearchAndFilters(
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        titleColor: titleColor,
                        subColor: subColor,
                        paymentFilter: paymentFilter,
                      ),
                      const SizedBox(height: 18),

                      // ── BILLS COUNT SUBHEADER ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filteredSales.length} Bills',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          if (filteredSales.length != totalBills)
                            Text(
                              'Filtered from $totalBills bills',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: subColor, fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ── BILLS LIST ──
              if (filteredSales.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 64, color: subColor.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No bills found for this period',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: subColor),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final sale = filteredSales[index];
                        return AnimateIn(
                          delay: Duration(milliseconds: (index * 15).clamp(0, 300)),
                          child: _buildBillCard(
                            sale: sale,
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                            titleColor: titleColor,
                            subColor: subColor,
                            isDark: isDark,
                          ),
                        );
                      },
                      childCount: filteredSales.length,
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
        error: (e, _) => Center(child: Text('Error loading bills: $e')),
      ),
    );
  }

  // ── QUICK DATE PRESET CHIPS ──
  Widget _buildQuickDatePresets(ReportDateRange currentRange) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final isToday = currentRange.start.year == now.year &&
        currentRange.start.month == now.month &&
        currentRange.start.day == now.day &&
        currentRange.end.day == now.day;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _PresetChip(
            label: 'Today',
            isSelected: isToday,
            onTap: () {
              ref.read(reportDateRangeProvider.notifier).state = ReportDateRange(start: todayStart, end: todayEnd);
            },
          ),
          const SizedBox(width: 8),
          _PresetChip(
            label: 'Yesterday',
            isSelected: false,
            onTap: () {
              final yStart = todayStart.subtract(const Duration(days: 1));
              final yEnd = DateTime(yStart.year, yStart.month, yStart.day, 23, 59, 59);
              ref.read(reportDateRangeProvider.notifier).state = ReportDateRange(start: yStart, end: yEnd);
            },
          ),
          const SizedBox(width: 8),
          _PresetChip(
            label: 'Last 7 Days',
            isSelected: false,
            onTap: () {
              final s = todayStart.subtract(const Duration(days: 6));
              ref.read(reportDateRangeProvider.notifier).state = ReportDateRange(start: s, end: todayEnd);
            },
          ),
          const SizedBox(width: 8),
          _PresetChip(
            label: 'This Month',
            isSelected: false,
            onTap: () {
              final mStart = DateTime(now.year, now.month, 1);
              ref.read(reportDateRangeProvider.notifier).state = ReportDateRange(start: mStart, end: todayEnd);
            },
          ),
          const SizedBox(width: 8),
          _PresetChip(
            label: 'Custom Range...',
            isSelected: false,
            onTap: () => _showDateRangePicker(context, ref, currentRange),
          ),
        ],
      ),
    );
  }

  // ── SUMMARY KPI DASHBOARD CARD ──
  Widget _buildSummaryCard({
    required ReportDateRange dateRange,
    required int totalBills,
    required double totalSales,
    required double cashSales,
    required double cardSales,
    required double otherSales,
    required Color cardBg,
    required Color cardBorder,
    required Color titleColor,
    required Color subColor,
    required PosL10n l10n,
    required bool isDark,
  }) {
    final String dateLabel = _formatDateRangeDisplay(dateRange);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dateLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showDateRangePicker(context, ref, dateRange),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Change',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: cardBorder, height: 1),
          const SizedBox(height: 16),

          // Primary Figures: Total Bills & Total Sales
          _buildSummaryRow(
            label: l10n.totalBills,
            value: '$totalBills',
            isBold: true,
            titleColor: titleColor,
            subColor: subColor,
            valueColor: titleColor,
            fontSize: 15,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            label: l10n.totalSales,
            value: Formatters.currency(totalSales),
            isBold: true,
            titleColor: titleColor,
            subColor: subColor,
            valueColor: AppTheme.primaryGreen,
            fontSize: 18,
          ),
          const SizedBox(height: 14),
          Divider(color: cardBorder, height: 1),
          const SizedBox(height: 12),

          // Payment Breakdown: Cash, Card, Other
          _buildSummaryRow(
            label: l10n.cash,
            value: Formatters.currency(cashSales),
            isBold: false,
            titleColor: titleColor,
            subColor: subColor,
            valueColor: titleColor,
            leadingIcon: Icons.payments_rounded,
            iconColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: l10n.card,
            value: Formatters.currency(cardSales),
            isBold: false,
            titleColor: titleColor,
            subColor: subColor,
            valueColor: titleColor,
            leadingIcon: Icons.credit_card_rounded,
            iconColor: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: l10n.other,
            value: Formatters.currency(otherSales),
            isBold: false,
            titleColor: titleColor,
            subColor: subColor,
            valueColor: titleColor,
            leadingIcon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required bool isBold,
    required Color titleColor,
    required Color subColor,
    required Color valueColor,
    double fontSize = 14,
    IconData? leadingIcon,
    Color? iconColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 16, color: iconColor ?? subColor),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isBold ? titleColor : subColor,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ── SEARCH & PAYMENT FILTERS ──
  Widget _buildSearchAndFilters({
    required Color cardBg,
    required Color cardBorder,
    required Color titleColor,
    required Color subColor,
    required String paymentFilter,
  }) {
    return Column(
      children: [
        // Search textfield
        TextField(
          controller: _searchController,
          onChanged: (val) => ref.read(_billSearchQueryProvider.notifier).state = val,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: titleColor),
          decoration: InputDecoration(
            hintText: 'Search by Bill # (e.g. QB-00125), Customer, Amount...',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: subColor),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: subColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(_billSearchQueryProvider.notifier).state = '';
                    },
                  )
                : null,
            filled: true,
            fillColor: cardBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cardBorder),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Payment method pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterPill(
                label: 'All Bills',
                isSelected: paymentFilter == 'all',
                onTap: () => ref.read(_billPaymentFilterProvider.notifier).state = 'all',
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Cash',
                isSelected: paymentFilter == 'cash',
                onTap: () => ref.read(_billPaymentFilterProvider.notifier).state = 'cash',
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Card',
                isSelected: paymentFilter == 'card',
                onTap: () => ref.read(_billPaymentFilterProvider.notifier).state = 'card',
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Store Credit',
                isSelected: paymentFilter == 'credit',
                onTap: () => ref.read(_billPaymentFilterProvider.notifier).state = 'credit',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── BILL CARD (MATCHING USER MOCKUP) ──
  Widget _buildBillCard({
    required Sale sale,
    required Color cardBg,
    required Color cardBorder,
    required Color titleColor,
    required Color subColor,
    required bool isDark,
  }) {
    final String timeStr = DateFormat('hh:mm a').format(sale.createdAt);
    final String methodStr = sale.paymentMethod.toUpperCase();

    Color methodBadgeBg = const Color(0xFF10B981).withValues(alpha: 0.12);
    Color methodBadgeText = const Color(0xFF10B981);

    if (sale.paymentMethod.toLowerCase() == 'card') {
      methodBadgeBg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
      methodBadgeText = const Color(0xFF3B82F6);
    } else if (sale.paymentMethod.toLowerCase() == 'credit') {
      methodBadgeBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      methodBadgeText = const Color(0xFFEF4444);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SaleDetailsScreen(sale: sale),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Bill Number & Time + Payment Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            sale.billNumber,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryBlue,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          timeStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: methodBadgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        methodStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: methodBadgeText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Middle Row: Items Count & Customer / Cashier Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 15, color: subColor),
                        const SizedBox(width: 6),
                        Text(
                          '${sale.itemsCount} ${sale.itemsCount == 1 ? "Item" : "Items"}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: subColor,
                          ),
                        ),
                        if (sale.customerName != null && sale.customerName!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: subColor)),
                          const SizedBox(width: 8),
                          Icon(Icons.person_outline_rounded, size: 14, color: subColor),
                          const SizedBox(width: 4),
                          Text(
                            sale.customerName!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Bottom Row: Price & Navigation indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      Formatters.currency(sale.total),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'View Slip',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primaryBlue),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateRangeDisplay(ReportDateRange range) {
    final now = DateTime.now();
    final isSameDay = range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day;

    if (isSameDay) {
      if (range.start.year == now.year &&
          range.start.month == now.month &&
          range.start.day == now.day) {
        return 'Today (${DateFormat('MMMM dd, yyyy').format(range.start)})';
      }
      return DateFormat('MMMM dd, yyyy').format(range.start);
    }
    return '${DateFormat('MMM dd, yyyy').format(range.start)} - ${DateFormat('MMM dd, yyyy').format(range.end)}';
  }

  Future<void> _showDateRangePicker(BuildContext context, WidgetRef ref, ReportDateRange current) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(reportDateRangeProvider.notifier).state = current.copyWith(
        start: picked.start,
        end: picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      );
    }
  }
}

// ── PRESET CHIP ──
class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}

// ── FILTER PILL ──
class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryGreen
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppTheme.primaryGreen : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}

// Helper provider for filtered sales
final salesByRangeProvider = FutureProvider.family<List<Sale>, ReportDateRange>((ref, range) async {
  // Trigger background lazy fetch for older sales to ensure reports are accurate
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final container = ProviderContainer();
    final syncService = container.read(syncServiceProvider);
    syncService.pullHistoricalData('sales').then((_) {
      syncService.pullHistoricalData('sales_returns');
      container.dispose();
    });
  });

  return await ref.read(saleActionsProvider).getSalesByRange(range.start, range.end);
});
