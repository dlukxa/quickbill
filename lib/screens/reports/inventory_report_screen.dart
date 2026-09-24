import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/preference_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/branch_provider.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../services/export_service.dart';
import '../../services/sinhala_search_service.dart';
import '../../utils/formatters.dart';
import '../../utils/l10n_extensions.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import '../../widgets/sinhala_transliteration_input.dart';
import '../../generated/l10n/app_localizations.dart';
import 'category_dashboard_screen.dart';

/// 10x Executive Inventory Audit, Valuation & Physical Stock Reconciliation System.
class InventoryReportScreen extends ConsumerStatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  ConsumerState<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends ConsumerState<InventoryReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filter & Search state for Tab 2 (Ledger)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _healthFilter = 'all'; // 'all', 'low', 'out', 'healthy', 'high_margin'
  String _sortBy = 'value_desc'; // 'value_desc', 'margin_desc', 'stock_asc', 'name_asc'

  // Tab 3 (Physical Audit) state
  final TextEditingController _auditSearchController = TextEditingController();
  String _auditSearchQuery = '';
  String _auditCategory = 'All';
  String _auditDiscrepancyFilter = 'all'; // 'all', 'discrepancy_only', 'matched_only'
  final Map<int, double> _physicalCounts = {};
  final Map<int, TextEditingController> _countControllers = {};
  final Map<int, String> _auditNotes = {};
  bool _isReconciling = false;

  // Tab 4 (Dead Stock) state
  final int _deadStockDays = 30;
  String _riskView = 'dead_stock'; // 'dead_stock', 'expiring'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _auditSearchController.dispose();
    for (final c in _countControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getControllerForProduct(Product p) {
    if (!_countControllers.containsKey(p.id!)) {
      final initialCount = _physicalCounts[p.id!] ?? p.calculatedStock;
      _countControllers[p.id!] = TextEditingController(
        text: initialCount % 1 == 0 ? initialCount.toInt().toString() : initialCount.toString(),
      );
    }
    return _countControllers[p.id!]!;
  }

  void _setPhysicalCount(Product p, double val) {
    setState(() {
      _physicalCounts[p.id!] = val < 0 ? 0 : val;
      final c = _countControllers[p.id!];
      if (c != null) {
        final text = val % 1 == 0 ? val.toInt().toString() : val.toString();
        if (c.text != text) {
          c.text = text;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryAuditProvider);
    final categoryBreakdownAsync = ref.watch(inventoryCategoryBreakdownProvider);
    final productsAsync = ref.watch(productsProvider);
    final isConsolidated = ref.watch(isConsolidatedProvider);
    final selectedBranch = ref.watch(branchProvider).selectedBranch;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.inventoryAudit,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              isConsolidated
                  ? 'All Branches (ඒකාබද්ධ දැක්ම)'
                  : (selectedBranch?.name ?? 'Main Branch'),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // Consolidated Toggle
          IconButton(
            tooltip: isConsolidated ? 'Switch to Single Branch' : 'View All Branches Consolidated',
            icon: Icon(
              isConsolidated ? Icons.apartment_rounded : Icons.store_mall_directory_outlined,
              color: isConsolidated ? AppTheme.primaryBlue : null,
            ),
            onPressed: () {
              ref.read(isConsolidatedProvider.notifier).state = !isConsolidated;
              ref.invalidate(inventoryAuditProvider);
              ref.invalidate(inventoryCategoryBreakdownProvider);
              ref.invalidate(deadStockAnalysisProvider);
              ref.invalidate(expiringStockRiskProvider);
            },
          ),

          // Refresh
          IconButton(
            tooltip: 'Refresh Audit Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(inventoryAuditProvider);
              ref.invalidate(inventoryCategoryBreakdownProvider);
              ref.invalidate(productsProvider);
              ref.invalidate(deadStockAnalysisProvider);
              ref.invalidate(expiringStockRiskProvider);
            },
          ),

          // Export Menu
          productsAsync.when(
            data: (products) => PopupMenuButton<String>(
              tooltip: 'Export Reports',
              icon: const Icon(Icons.download_rounded),
              onSelected: (val) async {
                final settings = ref.read(settingsProvider);

                if (val == 'csv_ledger') {
                  await ExportService.instance.exportInventoryValuationLedger(
                    products,
                    localizeCategory: (cat) => context.getLocalizedCategory(cat),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Inventory Valuation Ledger exported to CSV!')),
                    );
                  }
                } else if (val == 'pdf_report') {
                  await PdfService.instance.generateStockReport(
                    products,
                    settings: settings,
                    localizeCategory: (cat) => context.getLocalizedCategory(cat),
                  );
                } else if (val == 'csv_audit') {
                  _exportAuditReconciliation(products);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'csv_ledger',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Export Valuation Ledger (CSV)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf_report',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Export Stock Report (PDF)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv_audit',
                  child: Row(
                    children: [
                      Icon(Icons.fact_check_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Export Physical Audit Variance (CSV)'),
                    ],
                  ),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.pie_chart_outline_rounded),
              text: 'Valuation & Categories',
            ),
            Tab(
              icon: Icon(Icons.format_list_bulleted_rounded),
              text: 'Stock Ledger',
            ),
            Tab(
              icon: Icon(Icons.fact_check_outlined),
              text: 'Physical Audit (Count)',
            ),
            Tab(
              icon: Icon(Icons.warning_amber_rounded),
              text: 'Dead Stock & Risk',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Executive KPI Summary Header
          inventoryAsync.when(
            data: (inv) => _buildExecutiveKpiHeader(inv, isDark),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error loading valuation metrics: $e')),
                ],
              ),
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Valuation & Category Distribution
                _buildValuationTab(categoryBreakdownAsync, productsAsync, isDark),

                // Tab 2: Itemized Valuation Ledger
                _buildLedgerTab(productsAsync, isDark),

                // Tab 3: Physical Count & Stock Reconciliation (The 10x Feature)
                _buildPhysicalAuditTab(productsAsync, isDark),

                // Tab 4: Dead Stock & Risk Analysis
                _buildDeadStockTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EXECUTIVE KPI HEADER
  // ===========================================================================
  Widget _buildExecutiveKpiHeader(Map<String, dynamic> inv, bool isDark) {
    final retailVal = (inv['retail_value'] as num?)?.toDouble() ?? 0.0;
    final costVal = (inv['cost_value'] as num?)?.toDouble() ?? 0.0;
    final totalUnits = (inv['total_units'] as num?)?.toDouble() ?? 0.0;
    final skuCount = (inv['product_count'] as num?)?.toInt() ?? 0;
    final grossProfit = retailVal - costVal;
    final marginPct = retailVal > 0 ? (grossProfit / retailVal) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  child: _buildHeaderCard(
                    title: 'TOTAL RETAIL VALUE (සිල්ලර)',
                    value: Formatters.currency(retailVal),
                    color: AppTheme.primaryBlue,
                    icon: Icons.storefront_rounded,
                    subtitle: 'Current Selling Valuation',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHeaderCard(
                    title: 'TOTAL COST INVESTMENT (පිරිවැය)',
                    value: Formatters.currency(costVal),
                    color: const Color(0xFF6366F1),
                    icon: Icons.payments_outlined,
                    subtitle: 'Capital Invested in Stock',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHeaderCard(
                    title: 'PROJECTED MARGIN (අපේක්ෂිත ලාභය)',
                    value: Formatters.currency(grossProfit),
                    color: AppTheme.primaryGreen,
                    icon: Icons.trending_up_rounded,
                    subtitle: '${marginPct.toStringAsFixed(1)}% Gross Margin',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHeaderCard(
                    title: 'STOCK METRICS (තොග ප්‍රමාණය)',
                    value: '${NumberFormat('#,###').format(totalUnits)} Units',
                    color: AppTheme.warningOrange,
                    icon: Icons.inventory_2_rounded,
                    subtitle: '$skuCount Active SKUs',
                  ),
                ),
              ],
            );
          }

          // Mobile responsive grid
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildHeaderCard(
                      title: 'RETAIL VALUE (සිල්ලර)',
                      value: Formatters.currency(retailVal),
                      color: AppTheme.primaryBlue,
                      icon: Icons.storefront_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildHeaderCard(
                      title: 'COST VALUE (පිරිවැය)',
                      value: Formatters.currency(costVal),
                      color: const Color(0xFF6366F1),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildHeaderCard(
                      title: 'EST. PROFIT (ලාභය)',
                      value: Formatters.currency(grossProfit),
                      color: AppTheme.primaryGreen,
                      icon: Icons.trending_up_rounded,
                      subtitle: '${marginPct.toStringAsFixed(1)}% Margin',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildHeaderCard(
                      title: 'TOTAL UNITS',
                      value: '${NumberFormat('#,###').format(totalUnits)} Units',
                      color: AppTheme.warningOrange,
                      icon: Icons.inventory_2_rounded,
                      subtitle: '$skuCount SKUs',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: VALUATION & CATEGORY BREAKDOWN
  // ===========================================================================
  Widget _buildValuationTab(
    AsyncValue<List<Map<String, dynamic>>> categoryBreakdownAsync,
    AsyncValue<List<Product>> productsAsync,
    bool isDark,
  ) {
    return productsAsync.when(
      data: (products) {
        final healthyCount = products.where((p) => !p.isLowStock && !p.isOutOfStock).length;
        final lowStockCount = products.where((p) => p.isLowStock).length;
        final outOfStockCount = products.where((p) => p.isOutOfStock).length;
        final highMarginCount = products.where((p) {
          final cost = p.costPrice ?? 0.0;
          if (p.price <= 0 || cost <= 0) return false;
          return ((p.price - cost) / p.price) >= 0.30;
        }).length;

        return categoryBreakdownAsync.when(
          data: (categories) {
            final double totalStoreRetail = categories.fold(
              0.0,
              (sum, item) => sum + ((item['retail_value'] as num?)?.toDouble() ?? 0.0),
            );

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(inventoryCategoryBreakdownProvider);
                ref.invalidate(inventoryAuditProvider);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Health Quick Filters Row
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildStockHealthPill(
                        label: 'Healthy Stock',
                        sublabel: '$healthyCount Items',
                        color: AppTheme.primaryGreen,
                        icon: Icons.check_circle_outline,
                        onTap: () {
                          setState(() {
                            _healthFilter = 'healthy';
                            _tabController.animateTo(1);
                          });
                        },
                      ),
                      _buildStockHealthPill(
                        label: 'Low Stock Alert',
                        sublabel: '$lowStockCount Items',
                        color: AppTheme.warningOrange,
                        icon: Icons.warning_amber_rounded,
                        onTap: () {
                          setState(() {
                            _healthFilter = 'low';
                            _tabController.animateTo(1);
                          });
                        },
                      ),
                      _buildStockHealthPill(
                        label: 'Out of Stock',
                        sublabel: '$outOfStockCount Items',
                        color: Colors.redAccent,
                        icon: Icons.cancel_outlined,
                        onTap: () {
                          setState(() {
                            _healthFilter = 'out';
                            _tabController.animateTo(1);
                          });
                        },
                      ),
                      _buildStockHealthPill(
                        label: 'High Margin (≥30%)',
                        sublabel: '$highMarginCount Items',
                        color: const Color(0xFF8B5CF6),
                        icon: Icons.auto_graph_rounded,
                        onTap: () {
                          setState(() {
                            _healthFilter = 'high_margin';
                            _tabController.animateTo(1);
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Category Intelligence Dashboard CTA
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.analytics_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Category Intelligence & Sales Share',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'View categorical sales share, margins, stock velocity & charts',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.bar_chart_rounded, size: 16),
                          label: const Text('Open Dashboard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CategoryDashboardScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CATEGORY DISTRIBUTION & PROFITABILITY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white60 : Colors.black54,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${categories.length} Categories',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No category inventory records found.')),
                    )
                  else
                    ...categories.map((cat) {
                      final rawCat = cat['category'] as String? ?? 'General';
                      final localizedCat = context.getLocalizedCategory(rawCat);
                      final productCount = cat['product_count'] as int? ?? 0;
                      final totalUnits = (cat['total_units'] as num?)?.toDouble() ?? 0.0;
                      final retail = (cat['retail_value'] as num?)?.toDouble() ?? 0.0;
                      final cost = (cat['cost_value'] as num?)?.toDouble() ?? 0.0;
                      final margin = (cat['margin'] as num?)?.toDouble() ?? 0.0;
                      final marginPct = (cat['margin_percentage'] as num?)?.toDouble() ?? 0.0;
                      final share = totalStoreRetail > 0 ? (retail / totalStoreRetail) : 0.0;

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _selectedCategory = rawCat;
                              _tabController.animateTo(1);
                            });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.category_rounded, size: 20, color: AppTheme.primaryBlue),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          localizedCat,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          '$rawCat • $productCount SKUs • ${NumberFormat('#,###').format(totalUnits)} units',
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
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                      Text(
                                        '${(share * 100).toStringAsFixed(1)}% of total stock',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Proportional Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: share.clamp(0.0, 1.0),
                                  backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                  minHeight: 6,
                                ),
                              ),

                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Cost: ${Formatters.currency(cost)}',
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (marginPct >= 20 ? AppTheme.primaryGreen : AppTheme.warningOrange)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Est. Profit: ${Formatters.currency(margin)} (${marginPct.toStringAsFixed(1)}%)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: marginPct >= 20 ? AppTheme.primaryGreen : AppTheme.warningOrange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading categories: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading products: $e')),
    );
  }

  Widget _buildStockHealthPill({
    required String label,
    required String sublabel,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  sublabel,
                  style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: ITEMIZED VALUATION LEDGER
  // ===========================================================================
  Widget _buildLedgerTab(AsyncValue<List<Product>> productsAsync, bool isDark) {
    return productsAsync.when(
      data: (products) {
        // 1. Unique categories list
        final categories = <String>['All'];
        for (final p in products) {
          final cat = p.category?.trim();
          if (cat != null && cat.isNotEmpty && !categories.contains(cat)) {
            categories.add(cat);
          }
        }

        // 2. Filter products
        var filtered = products.toList();

        // Search filter (Sinhala/Singlish rank)
        if (_searchQuery.isNotEmpty) {
          filtered = SinhalaSearchService.filterAndRank(filtered, _searchQuery);
        }

        // Category filter
        if (_selectedCategory != 'All') {
          filtered = filtered.where((p) => p.category == _selectedCategory).toList();
        }

        // Health filter
        if (_healthFilter == 'low') {
          filtered = filtered.where((p) => p.isLowStock).toList();
        } else if (_healthFilter == 'out') {
          filtered = filtered.where((p) => p.isOutOfStock).toList();
        } else if (_healthFilter == 'healthy') {
          filtered = filtered.where((p) => !p.isLowStock && !p.isOutOfStock).toList();
        } else if (_healthFilter == 'high_margin') {
          filtered = filtered.where((p) {
            final cost = p.costPrice ?? 0.0;
            if (p.price <= 0 || cost <= 0) return false;
            return ((p.price - cost) / p.price) >= 0.30;
          }).toList();
        }

        // Sort
        if (_sortBy == 'value_desc') {
          filtered.sort((a, b) => (b.calculatedStock * b.price).compareTo(a.calculatedStock * a.price));
        } else if (_sortBy == 'margin_desc') {
          filtered.sort((a, b) {
            final marginA = a.price > 0 && a.costPrice != null ? (a.price - a.costPrice!) / a.price : 0.0;
            final marginB = b.price > 0 && b.costPrice != null ? (b.price - b.costPrice!) / b.price : 0.0;
            return marginB.compareTo(marginA);
          });
        } else if (_sortBy == 'stock_asc') {
          filtered.sort((a, b) => a.calculatedStock.compareTo(b.calculatedStock));
        } else if (_sortBy == 'name_asc') {
          filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        }

        return Column(
          children: [
            // Filter Controls Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? const Color(0xFF1B1E27) : const Color(0xFFF8F9FA),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Sinhala & Singlish Search Input
                      Expanded(
                        child: SinglishTextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          showSuggestionBanner: false,
                          decoration: InputDecoration(
                            hintText: 'Search (e.g. "sini", "කිරි", barcode)...',
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
                      const SizedBox(width: 8),

                      // Category Dropdown
                      DropdownButton<String>(
                        value: _selectedCategory,
                        items: categories.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(
                              c == 'All' ? 'All Categories' : context.getLocalizedCategory(c),
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                      const SizedBox(width: 8),

                      // Sort Dropdown
                      DropdownButton<String>(
                        value: _sortBy,
                        items: const [
                          DropdownMenuItem(value: 'value_desc', child: Text('Sort: Highest Value', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'margin_desc', child: Text('Sort: Highest Margin', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'stock_asc', child: Text('Sort: Lowest Stock', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'name_asc', child: Text('Sort: Name (A-Z)', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _sortBy = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Health Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All Items', 'all', filtered.length),
                        const SizedBox(width: 6),
                        _buildFilterChip('Healthy Stock', 'healthy', null),
                        const SizedBox(width: 6),
                        _buildFilterChip('Low Stock', 'low', null),
                        const SizedBox(width: 6),
                        _buildFilterChip('Out of Stock', 'out', null),
                        const SizedBox(width: 6),
                        _buildFilterChip('High Margin (≥30%)', 'high_margin', null),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Products Ledger List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No products match your filter criteria.', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                                _selectedCategory = 'All';
                                _healthFilter = 'all';
                              });
                            },
                            child: const Text('Reset Filters'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final stock = p.calculatedStock;
                        final cost = p.costPrice ?? 0.0;
                        final retail = p.price;
                        final retailValuation = stock * retail;
                        final costValuation = stock * cost;
                        final grossProfit = retailValuation - costValuation;
                        final marginPct = retail > 0 && cost > 0 ? ((retail - cost) / retail) * 100 : 0.0;
                        final localizedCat = context.getLocalizedCategory(p.category ?? 'General');

                        return AnimateIn(
                          delay: Duration(milliseconds: (index % 15) * 20),
                          child: AppCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product info
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (p.nameSinhala != null && p.nameSinhala!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          p.nameSinhala!,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              localizedCat,
                                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
                                            ),
                                          ),
                                          if (p.baseBarcode != null && p.baseBarcode!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Barcode: ${p.baseBarcode}',
                                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Price: ${Formatters.currency(retail)}  •  Cost: ${Formatters.currency(cost)}',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),

                                // Stock badge & margin
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (p.isOutOfStock
                                                  ? Colors.red
                                                  : (p.isLowStock ? AppTheme.warningOrange : AppTheme.primaryGreen))
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: (p.isOutOfStock
                                                    ? Colors.red
                                                    : (p.isLowStock ? AppTheme.warningOrange : AppTheme.primaryGreen))
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          '${stock % 1 == 0 ? stock.toInt() : stock} ${p.unit}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: p.isOutOfStock
                                                ? Colors.red
                                                : (p.isLowStock ? AppTheme.warningOrange : AppTheme.primaryGreen),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (marginPct >= 20 ? AppTheme.primaryGreen : Colors.grey).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${marginPct.toStringAsFixed(1)}% margin',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: marginPct >= 20 ? AppTheme.primaryGreen : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Valuations
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        Formatters.currency(retailValuation),
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Cost: ${Formatters.currency(costValuation)}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Profit: ${Formatters.currency(grossProfit)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: grossProfit >= 0 ? AppTheme.primaryGreen : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildFilterChip(String label, String value, int? count) {
    final isSelected = _healthFilter == value;
    return ChoiceChip(
      label: Text(count != null ? '$label ($count)' : label),
      selected: isSelected,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: AppTheme.primaryBlue,
      onSelected: (selected) {
        if (selected) setState(() => _healthFilter = value);
      },
    );
  }

  // ===========================================================================
  // TAB 3: PHYSICAL COUNT & STOCK RECONCILIATION (THE 10X FEATURE)
  // ===========================================================================
  Widget _buildPhysicalAuditTab(AsyncValue<List<Product>> productsAsync, bool isDark) {
    return productsAsync.when(
      data: (products) {
        // Unique categories
        final categories = <String>['All'];
        for (final p in products) {
          final cat = p.category?.trim();
          if (cat != null && cat.isNotEmpty && !categories.contains(cat)) {
            categories.add(cat);
          }
        }

        // Filter products for audit
        var auditList = products.toList();

        if (_auditSearchQuery.isNotEmpty) {
          auditList = SinhalaSearchService.filterAndRank(auditList, _auditSearchQuery);
        }

        if (_auditCategory != 'All') {
          auditList = auditList.where((p) => p.category == _auditCategory).toList();
        }

        if (_auditDiscrepancyFilter == 'discrepancy_only') {
          auditList = auditList.where((p) {
            final physical = _physicalCounts[p.id!] ?? p.calculatedStock;
            return (physical - p.calculatedStock).abs() > 0.001;
          }).toList();
        } else if (_auditDiscrepancyFilter == 'matched_only') {
          auditList = auditList.where((p) {
            final physical = _physicalCounts[p.id!] ?? p.calculatedStock;
            return (physical - p.calculatedStock).abs() <= 0.001;
          }).toList();
        }

        // Calculate audit summary
        int totalAudited = 0;
        int discrepancyCount = 0;
        double netVarianceValuation = 0.0;
        final List<Map<String, dynamic>> pendingAdjustments = [];

        for (final p in products) {
          if (_physicalCounts.containsKey(p.id!)) {
            totalAudited++;
            final physical = _physicalCounts[p.id!]!;
            final system = p.calculatedStock;
            final variance = physical - system;
            final cost = p.costPrice != null && p.costPrice! > 0 ? p.costPrice! : p.price;

            if (variance.abs() > 0.001) {
              discrepancyCount++;
              netVarianceValuation += variance * cost;
              pendingAdjustments.add({
                'productId': p.id!,
                'productName': p.name,
                'category': p.category,
                'systemStock': system,
                'physicalStock': physical,
                'variance': variance,
                'varianceValue': variance * cost,
                'unit': p.unit,
                'notes': _auditNotes[p.id!] ?? 'Physical Stock Audit Reconciliation',
              });
            }
          }
        }

        return Column(
          children: [
            // Informational Instruction Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Enter physical shelf counts to detect stock shrinkage or surplus. Reconciling automatically updates store stock & logs audit trail.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.playlist_add_check, size: 16),
                    label: const Text('Match All to System', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        for (final p in products) {
                          _setPhysicalCount(p, p.calculatedStock);
                        }
                      });
                    },
                  ),
                  if (_physicalCounts.isNotEmpty)
                    TextButton(
                      child: const Text('Clear', style: TextStyle(fontSize: 11, color: Colors.red)),
                      onPressed: () {
                        setState(() {
                          _physicalCounts.clear();
                          _countControllers.clear();
                          _auditNotes.clear();
                        });
                      },
                    ),
                ],
              ),
            ),

            // Audit Search Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SinglishTextField(
                      controller: _auditSearchController,
                      onChanged: (val) => setState(() => _auditSearchQuery = val),
                      showSuggestionBanner: false,
                      decoration: InputDecoration(
                        hintText: 'Search audit item (name, barcode)...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _auditCategory,
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(
                          c == 'All' ? 'All Categories' : context.getLocalizedCategory(c),
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _auditCategory = val);
                    },
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _auditDiscrepancyFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Counts', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'discrepancy_only', child: Text('Discrepancies Only', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'matched_only', child: Text('Matched Only', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _auditDiscrepancyFilter = val);
                    },
                  ),
                ],
              ),
            ),

            // Audit Items Table / List
            Expanded(
              child: auditList.isEmpty
                  ? const Center(child: Text('No products match audit filters.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: auditList.length,
                      itemBuilder: (context, index) {
                        final p = auditList[index];
                        final systemStock = p.calculatedStock;
                        final physicalStock = _physicalCounts[p.id!] ?? systemStock;
                        final variance = physicalStock - systemStock;
                        final cost = p.costPrice != null && p.costPrice! > 0 ? p.costPrice! : p.price;
                        final varianceValuation = variance * cost;
                        final controller = _getControllerForProduct(p);
                        final localizedCat = context.getLocalizedCategory(p.category ?? 'General');

                        final isMatched = variance.abs() <= 0.001;
                        final isSurplus = variance > 0.001;

                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Product info
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '$localizedCat • Unit: ${p.unit} • Cost: ${Formatters.currency(cost)}',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                    ),
                                    if (_auditNotes.containsKey(p.id!))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'Note: ${_auditNotes[p.id!]}',
                                          style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // System stock
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text('SYSTEM', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${systemStock % 1 == 0 ? systemStock.toInt() : systemStock}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),

                              // Physical Count Input Controls
                              Expanded(
                                flex: 3,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        _setPhysicalCount(p, physicalStock - 1);
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 55,
                                      child: TextField(
                                        controller: controller,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onChanged: (val) {
                                          final parsed = double.tryParse(val);
                                          if (parsed != null) {
                                            setState(() {
                                              _physicalCounts[p.id!] = parsed;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        _setPhysicalCount(p, physicalStock + 1);
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Variance Display
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isMatched
                                            ? Colors.grey.withValues(alpha: 0.15)
                                            : (isSurplus ? AppTheme.primaryGreen : Colors.red).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isMatched
                                            ? '0 (Match)'
                                            : '${isSurplus ? '+' : ''}${variance % 1 == 0 ? variance.toInt() : variance.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isMatched
                                              ? Colors.grey
                                              : (isSurplus ? AppTheme.primaryGreen : Colors.red),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      Formatters.currency(varianceValuation.abs()),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isMatched
                                            ? Colors.grey
                                            : (isSurplus ? AppTheme.primaryGreen : Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Quick Note Button
                              IconButton(
                                icon: Icon(
                                  _auditNotes.containsKey(p.id!) ? Icons.edit_note_rounded : Icons.note_add_outlined,
                                  size: 18,
                                  color: _auditNotes.containsKey(p.id!) ? AppTheme.primaryBlue : Colors.grey,
                                ),
                                tooltip: 'Add Audit Note',
                                onPressed: () => _showAddNoteDialog(p),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Persistent Sticky Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audited: $totalAudited / ${products.length} Items  •  $discrepancyCount Discrepancies',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'Net Financial Impact: ${Formatters.currency(netVarianceValuation.abs())} ${netVarianceValuation >= 0 ? '(Surplus / වැඩිපුර)' : '(Loss / පාඩුවක්)'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: netVarianceValuation >= 0 ? AppTheme.primaryGreen : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: _isReconciling
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      discrepancyCount == 0
                          ? 'All Matched (හරි)'
                          : 'Reconcile Stock ($discrepancyCount)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: discrepancyCount > 0 ? AppTheme.primaryBlue : AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: pendingAdjustments.isEmpty || _isReconciling
                        ? null
                        : () => _confirmAndApplyReconciliation(pendingAdjustments),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading audit: $e')),
    );
  }

  void _showAddNoteDialog(Product p) {
    final noteController = TextEditingController(text: _auditNotes[p.id!] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Audit Note for "${p.name}"'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. Broken package, expired item discarded, miscounted earlier...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (noteController.text.trim().isEmpty) {
                  _auditNotes.remove(p.id!);
                } else {
                  _auditNotes[p.id!] = noteController.text.trim();
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _confirmAndApplyReconciliation(List<Map<String, dynamic>> adjustments) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.fact_check_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 10),
            Text('Confirm Stock Reconciliation'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to reconcile ${adjustments.length} product discrepancy records. Product stock will be updated to physical counts, and audit logs will be permanently recorded.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 6),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: adjustments.length,
                  itemBuilder: (c, i) {
                    final item = adjustments[i];
                    final variance = item['variance'] as double;
                    final isSurplus = variance > 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['productName'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${item['systemStock']} → ${item['physicalStock']} (${isSurplus ? '+' : ''}$variance)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSurplus ? AppTheme.primaryGreen : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.warningOrange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action modifies active inventory levels across POS terminals.',
                        style: TextStyle(fontSize: 11, color: AppTheme.warningOrange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeReconciliation(adjustments);
            },
            child: const Text('Apply & Reconcile'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeReconciliation(List<Map<String, dynamic>> adjustments) async {
    setState(() => _isReconciling = true);
    try {
      final selectedBranchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
      await DatabaseService.instance.reconcileStockAudit(
        branchId: selectedBranchId,
        adjustments: adjustments,
      );

      // Refresh providers
      ref.invalidate(productsProvider);
      ref.invalidate(inventoryAuditProvider);
      ref.invalidate(inventoryCategoryBreakdownProvider);
      ref.invalidate(deadStockAnalysisProvider);

      setState(() {
        _physicalCounts.clear();
        _countControllers.clear();
        _auditNotes.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryGreen,
            content: Text('Successfully reconciled ${adjustments.length} product stock records!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error reconciling stock: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReconciling = false);
    }
  }

  void _exportAuditReconciliation(List<Product> products) async {
    final List<Map<String, dynamic>> items = [];
    for (final p in products) {
      final system = p.calculatedStock;
      final physical = _physicalCounts[p.id!] ?? system;
      final variance = physical - system;
      final cost = p.costPrice != null && p.costPrice! > 0 ? p.costPrice! : p.price;

      items.add({
        'name': p.name,
        'barcode': p.baseBarcode ?? '',
        'category': context.getLocalizedCategory(p.category ?? 'General'),
        'systemStock': system,
        'physicalStock': physical,
        'variance': variance,
        'unit': p.unit,
        'costPrice': cost,
        'varianceValue': variance * cost,
        'status': variance.abs() <= 0.001 ? 'Matched' : (variance > 0 ? 'Surplus' : 'Shortage'),
        'notes': _auditNotes[p.id!] ?? '',
      });
    }

    await ExportService.instance.exportStockReconciliationReport(items);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Physical Audit Report exported to CSV!')),
      );
    }
  }

  // ===========================================================================
  // TAB 4: DEAD STOCK & EXPIRY RISK ANALYSIS
  // ===========================================================================
  Widget _buildDeadStockTab(bool isDark) {
    final deadStockAsync = ref.watch(deadStockAnalysisProvider);
    final expiringRiskAsync = ref.watch(expiringStockRiskProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sub-navigation view toggle
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'dead_stock',
                    label: Text('Dead Stock (Dormant)'),
                    icon: Icon(Icons.timer_off_outlined),
                  ),
                  ButtonSegment(
                    value: 'expiring',
                    label: Text('Expiring Batches (Risk)'),
                    icon: Icon(Icons.hourglass_bottom_rounded),
                  ),
                ],
                selected: {_riskView},
                onSelectionChanged: (set) => setState(() => _riskView = set.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_riskView == 'dead_stock') ...[
          // Dead Stock View
          deadStockAsync.when(
            data: (deadItems) {
              final totalLocked = deadItems.fold<double>(
                0.0,
                (sum, item) => sum + ((item['locked_capital'] as num?)?.toDouble() ?? 0.0),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Banner
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    color: Colors.amber.shade900,
                    child: Row(
                      children: [
                        const Icon(Icons.lock_clock_outlined, size: 36, color: Colors.white),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CAPITAL LOCKED IN DORMANT STOCK (අක්‍රිය තොග)',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Formatters.currency(totalLocked),
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${deadItems.length} products with no recorded sales in the last $_deadStockDays days',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SLOW-MOVING & DORMANT PRODUCTS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white60 : Colors.black54,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        'Sorted by Locked Capital',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (deadItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'Great job! No dormant stock detected.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                      ),
                    )
                  else
                    ...deadItems.map((item) {
                      final name = item['name'] as String;
                      final cat = item['category'] as String? ?? 'General';
                      final stock = (item['current_stock'] as num).toDouble();
                      final unit = item['unit'] as String? ?? 'pcs';
                      final locked = (item['locked_capital'] as num).toDouble();
                      final lastSoldAt = item['last_sold_at'] as String?;
                      final formattedLastSold = lastSoldAt != null
                          ? DateFormat('dd MMM yyyy').format(DateTime.parse(lastSoldAt))
                          : 'Never Sold';

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, color: Colors.amber, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${context.getLocalizedCategory(cat)} • Stock: $stock $unit • Last sold: $formattedLastSold',
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Formatters.currency(locked),
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Recommend Clearance',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ] else ...[
          // Expiring Batches View
          expiringRiskAsync.when(
            data: (expiringItems) {
              final totalAtRisk = expiringItems.fold<double>(
                0.0,
                (sum, item) => sum + ((item['at_risk_value'] as num?)?.toDouble() ?? 0.0),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Banner
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    color: Colors.red.shade900,
                    child: Row(
                      children: [
                        const Icon(Icons.event_busy_rounded, size: 36, color: Colors.white),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CAPITAL AT EXPIRY RISK (කල් ඉකුත්වීමේ අවදානම)',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Formatters.currency(totalAtRisk),
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${expiringItems.length} product batches expiring within 30 days or expired',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (expiringItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No expiring product batches found within the next 30 days.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                      ),
                    )
                  else
                    ...expiringItems.map((item) {
                      final name = item['product_name'] as String;
                      final batchNum = item['batch_number'] as String;
                      final stock = (item['stock'] as num).toDouble();
                      final unit = item['unit'] as String? ?? 'pcs';
                      final atRisk = (item['at_risk_value'] as num).toDouble();
                      final expiryStr = item['expiry_date'] as String;
                      final expiryDate = DateTime.tryParse(expiryStr) ?? DateTime.now();
                      final daysLeft = expiryDate.difference(DateTime.now()).inDays;
                      final isExpired = daysLeft < 0;

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isExpired ? Colors.red : AppTheme.warningOrange).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isExpired ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                                color: isExpired ? Colors.red : AppTheme.warningOrange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Batch: $batchNum • Stock: $stock $unit • Expiry: ${DateFormat('dd MMM yyyy').format(expiryDate)}',
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Formatters.currency(atRisk),
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isExpired ? Colors.red : AppTheme.warningOrange,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isExpired ? Colors.red : AppTheme.warningOrange).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isExpired ? 'EXPIRED (${daysLeft.abs()}d ago)' : '$daysLeft days left',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isExpired ? Colors.red : AppTheme.warningOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ],
    );
  }
}
