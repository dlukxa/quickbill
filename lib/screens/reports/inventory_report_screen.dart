import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/preference_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/branch_provider.dart';
import '../../services/pdf_service.dart';
import '../../services/export_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import '../../utils/region_utils.dart';
import '../../utils/l10n_extensions.dart';
import '../../generated/l10n/app_localizations.dart';

class InventoryReportScreen extends ConsumerWidget {
  const InventoryReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryAuditProvider);
    final productsAsync = ref.watch(productsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventoryAudit),
        actions: [
          productsAsync.when(
            data: (products) => Row(
              children: [
                IconButton(
                  tooltip: l10n.exportCsv,
                  icon: const Icon(Icons.table_view_outlined),
                  onPressed: () {
                    final selectedBranchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
                    ExportService.instance.exportProducts(selectedBranchId);
                  },
                ),
                IconButton(
                  tooltip: l10n.exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () {
                    final settings = ref.read(settingsProvider);
                    PdfService.instance.generateStockReport(
                      products, 
                      settings: settings,
                      localizeCategory: (cat) => context.getLocalizedCategory(cat),
                    );
                  },
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Header Stats
          SliverToBoxAdapter(
            child: inventoryAsync.when(
              data: (inv) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  color: AppTheme.primaryBlue,
                  child: Column(
                    children: [
                      Text(l10n.totalInventoryValue, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(Formatters.currency(inv['retail_value']), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MiniStat(label: l10n.totalItems, value: '${inv['total_units'] ?? 0}'),
                          _MiniStat(label: l10n.categories, value: '${inv['product_count'] ?? 0}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // Items List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Text(l10n.productValuation.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
          ),

          productsAsync.when(
            data: (products) => SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final p = products[index];
                    final valuation = p.calculatedStock * p.price;
                    return AnimateIn(
                      delay: Duration(milliseconds: index * 10),
                      child: AppCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name, 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _InfoChip(
                                        icon: Icons.inventory_2_outlined,
                                        label: '${p.calculatedStock} ${p.unit}',
                                        color: AppTheme.warningOrange,
                                      ),
                                      _InfoChip(
                                        icon: Icons.sell_outlined,
                                        label: Formatters.currency(p.price),
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Formatters.currency(valuation), 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.value, 
                                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: products.length,
                ),
              ),
            ),
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
