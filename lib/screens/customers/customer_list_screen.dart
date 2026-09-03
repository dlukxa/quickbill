import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../generated/l10n/app_localizations_en.dart';
import '../../config/theme.dart';
import '../../providers/customer_provider.dart';
import '../../providers/customer_insights_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/region_utils.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import '../../services/sync_service.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  final bool isSelectionMode;

  const CustomerListScreen({super.key, this.isSelectionMode = false});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCustomers());
  }

  Future<void> _syncCustomers() async {
    if (_isSyncing || !mounted) return;
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncServiceProvider).syncEssentialData();
      if (!mounted) return;
      ref.invalidate(customersProvider);
      ref.invalidate(customerInsightsProvider);
    } catch (e) {
      debugPrint('Error syncing customers: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(customerInsightsProvider);
    final filteredInsights = ref.watch(filteredCustomerInsightsProvider);
    final currentFilter = ref.watch(customerSegmentFilterProvider);

    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.customers,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'Sync Customers',
            onPressed: _syncCustomers,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
              ),
              child: TextField(
                onChanged: (val) => ref.read(customerSearchProvider.notifier).state = val,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: context.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: l10n?.searchCustomerHint ?? 'Search customers...',
                  hintStyle: TextStyle(color: context.subText, fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: context.subText, size: 20),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Segment Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip(ref, null, l10n?.all ?? 'All', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip(ref, CustomerSegment.champion, '🏆 ${l10n?.segmentChampion ?? "Champions"}', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip(ref, CustomerSegment.loyalist, '💎 ${l10n?.segmentLoyalist ?? "Loyalists"}', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip(ref, CustomerSegment.bigSpender, '💰 ${l10n?.segmentBigSpender ?? "Big Spenders"}', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip(ref, CustomerSegment.atRisk, '⚠️ ${l10n?.segmentAtRisk ?? "At Risk"}', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip(ref, CustomerSegment.recent, '🌱 ${l10n?.segmentNew ?? "New"}', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip(ref, CustomerSegment.lost, '💤 ${l10n?.segmentLost ?? "Lost"}', currentFilter),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Customer List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _syncCustomers,
              child: insightsAsync.when(
                data: (allInsights) {
                  if (allInsights.isEmpty) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: _buildEmptyState(context),
                      ),
                    );
                  }

                  if (filteredInsights.isEmpty) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(child: Text(l10n.noCustomersFound)),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredInsights.length,
                    itemBuilder: (context, index) {
                      final insight = filteredInsights[index];
                      return AnimateIn(
                        delay: Duration(milliseconds: index * 50),
                        child: _buildCustomerCard(context, ref, insight),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
        ),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text(
          l10n?.newCustomer ?? 'New Customer',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, CustomerSegment? segment, String label, CustomerSegment? currentFilter) {
    final isSelected = currentFilter == segment;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(customerSegmentFilterProvider.notifier).state = isSelected ? null : segment;
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryGreen : ref.context.cardColor,
              gradient: isSelected ? AppTheme.primaryGradient : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.transparent : ref.context.borderColor.withValues(alpha: 0.5),
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check_circle, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Text(
                  label, 
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, 
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : ref.context.subText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, WidgetRef ref, CustomerInsight insight) {
    final customer = insight.customer;
    final hasDebt = customer.totalDebt > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () {
          if (widget.isSelectionMode) {
            ref.read(selectedCustomerProvider.notifier).state = customer;
            Navigator.pop(context);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer.id!)),
            );
          }
        },
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: hasDebt ? AppTheme.warningOrange.withValues(alpha: 0.2) : AppTheme.primaryGreen.withValues(alpha: 0.1),
            child: Text(
              customer.name.characters.first.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: hasDebt ? AppTheme.warningOrange : AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          title: Text(
            customer.name,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: customer.phone != null 
              ? Text(customer.phone!, style: GoogleFonts.plusJakartaSans(color: context.subText, fontSize: 13)) 
              : null,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasDebt)
                Text(
                  '${globalAppRegion.currencySymbol} ${customer.totalDebt.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              if (hasDebt)
                Text(
                  AppLocalizations.of(context)?.debtLabel ?? 'DEBT',
                  style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (!hasDebt) ...[
                // Insight Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: insight.segment.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: insight.segment.color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _getSegmentLabel(context, insight.segment),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: insight.segment.color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline, 
            size: 80, 
            color: context.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 20),
          Text(
            l10n?.noCustomersYet ?? 'No customers yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: context.subText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.addCustomerHint ?? 'Add customers to track billing history',
            style: GoogleFonts.plusJakartaSans(color: context.subText.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  String _getSegmentLabel(BuildContext context, CustomerSegment segment) {
    final l10n = AppLocalizations.of(context);
    switch (segment) {
      case CustomerSegment.champion: return '🏆 ${l10n?.segmentChampion ?? "Champions"}';
      case CustomerSegment.loyalist: return '💎 ${l10n?.segmentLoyalist ?? "Loyalists"}';
      case CustomerSegment.bigSpender: return '💰 ${l10n?.segmentBigSpender ?? "Big Spenders"}';
      case CustomerSegment.atRisk: return '⚠️ ${l10n?.segmentAtRisk ?? "At Risk"}';
      case CustomerSegment.lost: return '💤 ${l10n?.segmentLost ?? "Lost"}';
      case CustomerSegment.recent: return '🌱 ${l10n?.segmentNew ?? "New"}';
      case CustomerSegment.regular: return l10n?.segmentRegular ?? 'Regular';
    }
  }
}
