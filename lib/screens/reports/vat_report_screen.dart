import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/sale_provider.dart';
import '../../providers/preference_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';

class VatReportScreen extends ConsumerStatefulWidget {
  const VatReportScreen({super.key});

  @override
  ConsumerState<VatReportScreen> createState() => _VatReportScreenState();
}

class _VatReportScreenState extends ConsumerState<VatReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  String _selectedPreset = 'this_month'; // 'today', 'this_week', 'this_month', 'last_month', 'custom'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      if (preset == 'today') {
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (preset == 'this_week') {
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
        _endDate = now;
      } else if (preset == 'this_month') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
      } else if (preset == 'last_month') {
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        _startDate = prevMonth;
        _endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _selectedPreset = 'custom';
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final reportAsync = ref.watch(vatReportProvider(DateTimeRange(start: _startDate, end: _endDate)));

    final df = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_outlined, color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'VAT & Tax Compliance Report',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(vatReportProvider),
          ),
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            tooltip: 'Filter Date Range',
            onPressed: _pickDateRange,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: const Color(0xFF6366F1),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.view_agenda_outlined, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.calendar_today_outlined, size: 18), text: 'Daily'),
            Tab(icon: Icon(Icons.pie_chart_outline, size: 18), text: 'By Rate'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Invoices'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                const SizedBox(width: 6),
                Text(
                  '${df.format(_startDate)} – ${df.format(_endDate)}',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Wrap(
                  spacing: 6,
                  children: [
                    _buildPresetChip('Today', 'today'),
                    _buildPresetChip('This Week', 'this_week'),
                    _buildPresetChip('This Month', 'this_month'),
                    _buildPresetChip('Last Month', 'last_month'),
                  ],
                ),
              ],
            ),
          ),

          // Main Tab Views
          Expanded(
            child: reportAsync.when(
              data: (data) => TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(data, settings),
                  _buildDailyTab(data),
                  _buildRateTab(data),
                  _buildInvoicesTab(data),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error loading VAT report: $err', style: const TextStyle(color: AppTheme.errorRed)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String presetKey) {
    final isSelected = _selectedPreset == presetKey;
    return InkWell(
      onTap: () => _applyPreset(presetKey),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF6366F1) : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  // ─── Tab 1: Overview ───
  Widget _buildOverviewTab(Map<String, dynamic> data, AppSettings settings) {
    final summary = data['summary'] as Map<String, dynamic>;
    final double taxable = (summary['total_taxable'] as num?)?.toDouble() ?? 0.0;
    final double vat = (summary['total_vat'] as num?)?.toDouble() ?? 0.0;
    final double exempt = (summary['total_exempt'] as num?)?.toDouble() ?? 0.0;
    final double zeroRated = (summary['total_zero_rated'] as num?)?.toDouble() ?? 0.0;
    final double grossSales = (summary['total_sales'] as num?)?.toDouble() ?? 0.0;
    final int invoiceCount = (summary['total_invoices'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Registration Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: settings.isVatRegistered
                    ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
                    : [const Color(0xFF64748B), const Color(0xFF475569)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  settings.isVatRegistered ? Icons.verified_user : Icons.info_outline,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.isVatRegistered
                            ? 'Registered for Inland Revenue VAT'
                            : 'VAT Not Registered (Unregistered Entity)',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'TIN: ${settings.taxIdentificationNumber.isEmpty ? 'N/A' : settings.taxIdentificationNumber}  •  VAT Reg No: ${settings.vatRegistrationNumber.isEmpty ? 'N/A' : settings.vatRegistrationNumber}  •  Default Rate: ${settings.defaultVatRate.toStringAsFixed(0)}% (${settings.vatPricingType.toUpperCase()})',
                        style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4 Core KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Taxable Sales (Base)',
                  amount: taxable,
                  subtitle: 'Subject to VAT',
                  color: const Color(0xFF6366F1),
                  icon: Icons.storefront,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildKpiCard(
                  title: 'Total VAT Collected',
                  amount: vat,
                  subtitle: 'Payable to IRD',
                  color: const Color(0xFF10B981),
                  icon: Icons.payments,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Exempt Supplies',
                  amount: exempt,
                  subtitle: 'Essential Goods / Zero Tax',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.block,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildKpiCard(
                  title: 'Zero-Rated Supplies',
                  amount: zeroRated,
                  subtitle: '0% Rated Exports / Input Taxed',
                  color: const Color(0xFF06B6D4),
                  icon: Icons.exposure_zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Total Gross Sales Summary
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AGGREGATE RECONCILIATION',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.8),
                ),
                const SizedBox(height: 12),
                _buildSummaryLine('Gross Sales Turnover', Formatters.currency(grossSales), isBold: true),
                const Divider(),
                _buildSummaryLine('Total Invoices Audited', invoiceCount.toString()),
                _buildSummaryLine('Taxable Net Base', Formatters.currency(taxable)),
                _buildSummaryLine('Output VAT Collected', Formatters.currency(vat), valueColor: const Color(0xFF10B981)),
                _buildSummaryLine('Exempt Turnover', Formatters.currency(exempt), valueColor: const Color(0xFFF59E0B)),
                _buildSummaryLine('Zero-Rated Turnover', Formatters.currency(zeroRated), valueColor: const Color(0xFF06B6D4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required double amount,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            Formatters.currency(amount),
            style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 2: Daily Breakdown ───
  Widget _buildDailyTab(Map<String, dynamic> data) {
    final daily = (data['daily'] as List<dynamic>?) ?? [];
    if (daily.isEmpty) {
      return const Center(child: Text('No sales recorded in the selected period.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: daily.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = daily[index] as Map<String, dynamic>;
        final date = row['sale_date'] as String? ?? 'N/A';
        final invoices = (row['invoices'] as num?)?.toInt() ?? 0;
        final taxable = (row['daily_taxable'] as num?)?.toDouble() ?? 0.0;
        final vat = (row['daily_vat'] as num?)?.toDouble() ?? 0.0;
        final exempt = (row['daily_exempt'] as num?)?.toDouble() ?? 0.0;
        final sales = (row['daily_sales'] as num?)?.toDouble() ?? 0.0;

        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(date, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('$invoices bills', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDailyCol('Taxable Base', taxable),
                  _buildDailyCol('VAT Collected', vat, color: const Color(0xFF10B981)),
                  _buildDailyCol('Exempt', exempt, color: const Color(0xFFF59E0B)),
                  _buildDailyCol('Total Sales', sales, isBold: true),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyCol(String label, double val, {Color? color, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          Formatters.currency(val),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ─── Tab 3: Sales By VAT Rate ───
  Widget _buildRateTab(Map<String, dynamic> data) {
    final rates = (data['by_rate'] as List<dynamic>?) ?? [];
    if (rates.isEmpty) {
      return const Center(child: Text('No rate-level item data found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = rates[index] as Map<String, dynamic>;
        final rate = (r['tax_rate'] as num?)?.toDouble() ?? 0.0;
        final status = r['tax_status'] as String? ?? 'taxable';
        final itemsSold = (r['items_sold'] as num?)?.toInt() ?? 0;
        final taxable = (r['total_taxable'] as num?)?.toDouble() ?? 0.0;
        final vat = (r['total_vat'] as num?)?.toDouble() ?? 0.0;

        String badgeText = '${rate.toStringAsFixed(0)}% Standard VAT';
        Color badgeColor = const Color(0xFF6366F1);
        if (status == 'exempt') {
          badgeText = 'Exempt Supplies';
          badgeColor = const Color(0xFFF59E0B);
        } else if (status == 'zero_rated' || rate == 0) {
          badgeText = '0% Zero-Rated';
          badgeColor = const Color(0xFF06B6D4);
        }

        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: badgeColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Units / Qty Sold: $itemsSold', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text('Taxable Base: ${Formatters.currency(taxable)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('VAT Collected', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                  Text(
                    Formatters.currency(vat),
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Tab 4: Audited Invoices ───
  Widget _buildInvoicesTab(Map<String, dynamic> data) {
    final invoices = (data['invoices'] as List<dynamic>?) ?? [];
    if (invoices.isEmpty) {
      return const Center(child: Text('No invoices recorded in this date range.'));
    }

    final df = DateFormat('yyyy-MM-dd hh:mm a');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final inv = invoices[index] as Map<String, dynamic>;
        final billNo = inv['bill_number'] as String? ?? 'N/A';
        final invType = inv['invoice_type'] as String? ?? 'normal';
        final customerName = inv['customer_name'] as String?;
        final customerTin = inv['customer_tin'] as String?;
        final total = (inv['total'] as num?)?.toDouble() ?? 0.0;
        final tax = (inv['tax'] as num?)?.toDouble() ?? 0.0;
        final taxable = (inv['taxable_amount'] as num?)?.toDouble() ?? 0.0;
        final createdAtStr = inv['created_at'] as String?;
        final date = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

        final isTaxInvoice = invType == 'tax_invoice';

        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        billNo,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTaxInvoice ? const Color(0xFF6366F1).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isTaxInvoice ? const Color(0xFF6366F1).withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          isTaxInvoice ? 'TAX INVOICE' : 'POS SLIP',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isTaxInvoice ? const Color(0xFF6366F1) : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    Formatters.currency(total),
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date != null ? df.format(date) : '',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    'VAT: ${Formatters.currency(tax)}  (Base: ${Formatters.currency(taxable)})',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                  ),
                ],
              ),
              if (customerName != null || customerTin != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Buyer: ${customerName ?? 'Walk-in'}${customerTin != null ? ' (TIN: $customerTin)' : ''}',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
