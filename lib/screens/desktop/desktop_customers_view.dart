import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/customer.dart';
import '../../models/customer_payment.dart';
import '../../models/sale.dart';
import '../../providers/customer_provider.dart';
import '../../providers/customer_insights_provider.dart';
import '../../providers/preference_provider.dart';
import '../../services/sync_service.dart';
import '../../utils/pos_l10n.dart';
import '../../utils/region_utils.dart';
import '../../widgets/sinhala_transliteration_input.dart';
import '../customers/add_customer_screen.dart';

/// Professional desktop customers view featuring:
/// - Customer segmentation chips (Champions, Loyalists, Big Spenders, At Risk, Debtors)
/// - High-density responsive data table
/// - Side inspector panel for active customer with purchase and credit history
/// - Direct debt settlement & payment recording
class DesktopCustomersView extends ConsumerStatefulWidget {
  const DesktopCustomersView({super.key});

  @override
  ConsumerState<DesktopCustomersView> createState() => _DesktopCustomersViewState();
}

class _DesktopCustomersViewState extends ConsumerState<DesktopCustomersView> {
  Customer? _selectedCustomer;
  bool _onlyDebtors = false;
  bool _isSyncing = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    final settings = ref.watch(settingsProvider);
    final posL10n = PosL10n.of(settings.languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final insightsAsync = ref.watch(customerInsightsProvider);
    final currentFilter = ref.watch(customerSegmentFilterProvider);

    return Scaffold(
      backgroundColor: bg,
      body: Row(
        children: [
          // Left Main Table View
          Expanded(
            flex: _selectedCustomer != null ? 6 : 10,
            child: Column(
              children: [
                _buildHeader(cardBg, borderColor, isDark, posL10n),
                _buildFilterBar(cardBg, borderColor, isDark, currentFilter, posL10n),
                Expanded(
                  child: insightsAsync.when(
                    data: (insights) {
                      var list = ref.watch(filteredCustomerInsightsProvider);
                      if (_onlyDebtors) {
                        list = list.where((i) => i.customer.totalDebt > 0).toList();
                      }

                      if (list.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                              const SizedBox(height: 16),
                              Text(
                                posL10n.noProductsFound,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return _buildCustomersTable(list, cardBg, borderColor, isDark);
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),

          // Right Customer Detail Panel
          if (_selectedCustomer != null)
            Container(
              width: 440,
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(left: BorderSide(color: borderColor)),
              ),
              child: _CustomerSideInspector(
                customer: _selectedCustomer!,
                onClose: () => setState(() => _selectedCustomer = null),
                onUpdated: () => ref.invalidate(customersProvider),
                isDark: isDark,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color cardBg, Color borderColor, bool isDark, PosL10n posL10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: AppTheme.primaryGreen, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                posL10n.customersAndCredit,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                posL10n.customersSubtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            tooltip: 'Sync Customers',
            onPressed: _syncCustomers,
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _openAddCustomerDialog(context),
            icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
            label: Text(
              posL10n.newCustomer,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(Color cardBg, Color borderColor, bool isDark, CustomerSegment? currentFilter, PosL10n posL10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Search field
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: SinglishTextField(
                    controller: _searchCtrl,
                    showSuggestionBanner: false,
                    onChanged: (val) => ref.read(customerSearchProvider.notifier).state = val,
                    onConverted: () => ref.read(customerSearchProvider.notifier).state = _searchCtrl.text,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: posL10n.searchCustomersHint,
                      hintStyle: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : Colors.black38),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Outstanding Debt Only Toggle
              FilterChip(
                selected: _onlyDebtors,
                label: Text(
                  posL10n.debtors,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: _onlyDebtors ? FontWeight.bold : FontWeight.w500,
                    color: _onlyDebtors ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                selectedColor: AppTheme.errorRed,
                onSelected: (val) => setState(() => _onlyDebtors = val),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Segments row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSegmentChip(posL10n.allCustomers, null, currentFilter == null),
                const SizedBox(width: 8),
                _buildSegmentChip('🏆 ${posL10n.champions}', CustomerSegment.champion, currentFilter == CustomerSegment.champion),
                const SizedBox(width: 8),
                _buildSegmentChip('💎 ${posL10n.loyalists}', CustomerSegment.loyalist, currentFilter == CustomerSegment.loyalist),
                const SizedBox(width: 8),
                _buildSegmentChip('💰 ${posL10n.bigSpenders}', CustomerSegment.bigSpender, currentFilter == CustomerSegment.bigSpender),
                const SizedBox(width: 8),
                _buildSegmentChip('⚠️ ${posL10n.atRisk}', CustomerSegment.atRisk, currentFilter == CustomerSegment.atRisk),
                const SizedBox(width: 8),
                _buildSegmentChip('🌱 New', CustomerSegment.recent, currentFilter == CustomerSegment.recent),
                const SizedBox(width: 8),
                _buildSegmentChip('💤 Lost', CustomerSegment.lost, currentFilter == CustomerSegment.lost),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentChip(String label, CustomerSegment? segment, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        ref.read(customerSegmentFilterProvider.notifier).state = isSelected ? null : segment;
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomersTable(List<CustomerInsight> list, Color cardBg, Color borderColor, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final insight = list[index];
        final customer = insight.customer;
        final isSelected = _selectedCustomer?.id == customer.id;
        final hasDebt = customer.totalDebt > 0;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? AppTheme.primaryGreen : borderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A3A) : const Color(0xFFF0FDF4))
              : cardBg,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _selectedCustomer = customer),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    child: Text(
                      customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Name and address
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (customer.address != null && customer.address!.isNotEmpty)
                          Text(
                            customer.address!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Phone
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Icon(Icons.phone_rounded, size: 14, color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 6),
                        Text(
                          customer.phone ?? 'No phone',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Segment badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: insight.segment.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      insight.segment.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: insight.segment.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Total Orders & Spent
                  SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${insight.purchaseCount} orders',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        Text(
                          '${globalAppRegion.currencySymbol} ${insight.totalSpent.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Debt status
                  SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Credit Debt',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        Text(
                          hasDebt
                              ? '${globalAppRegion.currencySymbol} ${customer.totalDebt.toStringAsFixed(2)}'
                              : 'Settled',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: hasDebt ? AppTheme.errorRed : AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Arrow / Action
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAddCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 500,
          child: const AddCustomerScreen(),
        ),
      ),
    ).then((_) {
      ref.invalidate(customersProvider);
      ref.invalidate(customerInsightsProvider);
    });
  }
}

/// Slide-out or split inspector for a selected customer on desktop
class _CustomerSideInspector extends ConsumerStatefulWidget {
  final Customer customer;
  final VoidCallback onClose;
  final VoidCallback onUpdated;
  final bool isDark;

  const _CustomerSideInspector({
    required this.customer,
    required this.onClose,
    required this.onUpdated,
    required this.isDark,
  });

  @override
  ConsumerState<_CustomerSideInspector> createState() => _CustomerSideInspectorState();
}

class _CustomerSideInspectorState extends ConsumerState<_CustomerSideInspector> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final hasDebt = customer.totalDebt > 0;

    return Column(
      children: [
        // Top Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                'Customer Profile',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit Customer',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: SizedBox(
                        width: 500,
                        child: AddCustomerScreen(customer: customer),
                      ),
                    ),
                  ).then((_) {
                    widget.onUpdated();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Profile summary card
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    child: Text(
                      customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (customer.phone != null)
                          Text(
                            customer.phone!,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Debt balance container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: hasDebt
                      ? AppTheme.errorRed.withValues(alpha: 0.1)
                      : AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasDebt
                        ? AppTheme.errorRed.withValues(alpha: 0.3)
                        : AppTheme.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Outstanding Balance',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: hasDebt ? AppTheme.errorRed : AppTheme.primaryGreen,
                          ),
                        ),
                        Text(
                          '${globalAppRegion.currencySymbol} ${customer.totalDebt.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: hasDebt ? AppTheme.errorRed : AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (hasDebt)
                      ElevatedButton.icon(
                        onPressed: () => _showRecordPaymentDialog(context, customer),
                        icon: const Icon(Icons.payment_rounded, size: 16, color: Colors.white),
                        label: Text(
                          'Settle Debt',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons: Phone / WhatsApp
              if (customer.phone != null && customer.phone!.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse('tel:${customer.phone}')),
                        icon: const Icon(Icons.call_rounded, size: 16),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          var cleanPhone = customer.phone!.replaceAll(RegExp(r'[^0-9]'), '');
                          if (!cleanPhone.startsWith('94') && cleanPhone.startsWith('0')) {
                            cleanPhone = '94${cleanPhone.substring(1)}';
                          }
                          launchUrl(Uri.parse('https://wa.me/$cleanPhone'));
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.green),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Tabs: Invoices / Payment History
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryGreen,
          tabs: const [
            Tab(text: 'Purchase History'),
            Tab(text: 'Debt Payments'),
          ],
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPurchaseHistory(customer.id!),
              _buildPaymentHistory(customer.id!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseHistory(int customerId) {
    final salesFuture = ref.watch(customerActionsProvider).getCustomerSales(customerId);

    return FutureBuilder<List<Sale>>(
      future: salesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No purchase records found'));
        }

        final sales = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: sales.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final sale = sales[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              title: Text(sale.billNumber, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(sale.createdAt), style: const TextStyle(fontSize: 11)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${globalAppRegion.currencySymbol} ${sale.total.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: sale.paymentMethod == 'credit' ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sale.paymentMethod.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: sale.paymentMethod == 'credit' ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentHistory(int customerId) {
    final paymentsFuture = ref.watch(customerActionsProvider).getPayments(customerId);

    return FutureBuilder<List<CustomerPayment>>(
      future: paymentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No payment records found'));
        }

        final payments = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: payments.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final payment = payments[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              leading: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 20),
              title: Text(
                'Received ${globalAppRegion.currencySymbol} ${payment.amount.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGreen),
              ),
              subtitle: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(payment.paymentDate), style: const TextStyle(fontSize: 11)),
              trailing: payment.note != null ? Text(payment.note!, style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
            );
          },
        );
      },
    );
  }

  void _showRecordPaymentDialog(BuildContext context, Customer customer) {
    final amountController = TextEditingController(text: customer.totalDebt.toStringAsFixed(0));
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Debt Payment', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer: ${customer.name}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Outstanding: ${globalAppRegion.currencySymbol} ${customer.totalDebt.toStringAsFixed(2)}',
                style: const TextStyle(color: AppTheme.errorRed),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Payment Amount (${globalAppRegion.currencySymbol})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SinglishTextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional, e.g. Cash, Bank Transfer)',
                  border: OutlineInputBorder(),
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
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) return;

              final payment = CustomerPayment(
                customerId: customer.id!,
                amount: amount,
                paymentDate: DateTime.now(),
                note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
              );

              await ref.read(customerActionsProvider).recordPayment(payment);
              if (ctx.mounted) Navigator.pop(ctx);
              widget.onUpdated();
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Confirm Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
