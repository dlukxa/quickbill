import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/customer.dart';
import '../../models/customer_payment.dart';
import '../../models/sale.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import 'add_customer_screen.dart';
import '../../utils/formatters.dart';
import '../../utils/region_utils.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final int customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _paymentController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _paymentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).value ?? [];
    final customer = customers.firstWhere((c) => c.id == widget.customerId, 
        orElse: () => Customer(name: 'Unknown', createdAt: DateTime.now(), updatedAt: DateTime.now()));

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddCustomerScreen(customer: customer)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCustomerHeader(customer),
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryGreen,
            tabs: [
              Tab(text: AppLocalizations.of(context)!.purchases),
              Tab(text: AppLocalizations.of(context)!.payments),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPurchaseHistory(),
                _buildPaymentHistory(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: customer.totalDebt > 0 
          ? FloatingActionButton.extended(
              onPressed: () => _showRecordPaymentDialog(customer),
              backgroundColor: AppTheme.primaryGreen,
              icon: const Icon(Icons.add_card),
              label: Text(AppLocalizations.of(context)!.recordPayment),
            ) 
          : null,
    );
  }

  Widget _buildCustomerHeader(Customer customer) {
    final hasDebt = customer.totalDebt > 0;
    
    return AnimateIn(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasDebt ? AppTheme.errorRed.withValues(alpha: 0.05) : AppTheme.primaryGreen.withValues(alpha: 0.05),
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  child: Text(
                    customer.name.characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (customer.phone != null)
                        Text(customer.phone!, style: TextStyle(color: Colors.grey[600])),
                      if (customer.address != null)
                        Text(customer.address!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                if (customer.phone != null) ...[
                  IconButton(
                    icon: const Icon(Icons.phone, color: AppTheme.primaryBlue),
                    onPressed: () async {
                      final Uri url = Uri.parse('tel:${customer.phone}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat, color: Colors.green),
                    onPressed: () async {
                      final l10n = AppLocalizations.of(context)!;
                      final String message = customer.totalDebt > 0 
                        ? l10n.whatsappDebtReminder(customer.name, customer.totalDebt.toStringAsFixed(0))
                        : l10n.whatsappGenericGreeting(customer.name);
                      final String encodedMessage = Uri.encodeComponent(message);
                      final Uri url = Uri.parse('https://wa.me/${customer.phone}?text=$encodedMessage');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    AppLocalizations.of(context)!.totalUdari,
                    '${globalAppRegion.currencySymbol} ${customer.totalDebt.toStringAsFixed(0)}',
                    hasDebt ? AppTheme.errorRed : Colors.grey[400]!,
                  ),
                ),
                Container(height: 40, width: 1, color: Colors.grey[300]),
                Expanded(
                  child: _buildStatItem(
                    AppLocalizations.of(context)!.lastVisit,
                    AppLocalizations.of(context)!.daysAgo('2'), // This would ideally be calculated
                    Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildPurchaseHistory() {
    final salesFuture = ref.watch(customerActionsProvider).getCustomerSales(widget.customerId);

    return FutureBuilder<List<Sale>>(
      future: salesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyHistory(AppLocalizations.of(context)!.noPurchasesRecorded);
        }

        final sales = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sales.length,
          itemBuilder: (context, index) {
            final sale = sales[index];
            return AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(sale.billNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(sale.createdAt)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${globalAppRegion.currencySymbol} ${sale.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    _buildPaymentTag(sale.paymentMethod),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentHistory() {
    final paymentsFuture = ref.watch(customerActionsProvider).getPayments(widget.customerId);

    return FutureBuilder<List<CustomerPayment>>(
      future: paymentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyHistory(AppLocalizations.of(context)!.noPaymentsRecorded);
        }

        final payments = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            return AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.payment, color: AppTheme.primaryGreen),
                title: Text(AppLocalizations.of(context)!.receivedAmount(payment.amount.toStringAsFixed(0)), 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                subtitle: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(payment.paymentDate)),
                trailing: payment.note != null ? const Icon(Icons.note_alt_outlined, color: Colors.grey, size: 16) : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentTag(String method) {
    final isCredit = method == 'credit';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isCredit ? AppTheme.errorRed.withValues(alpha: 0.1) : AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isCredit ? AppTheme.errorRed : AppTheme.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildEmptyHistory(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(Customer customer) {
    _paymentController.text = '';
    _noteController.text = '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.recordRepayment),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.currentDebt(customer.totalDebt.toStringAsFixed(0)), 
                style: const TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _paymentController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.amountReceivedLabel,
                prefixText: '${globalAppRegion.currencySymbol} ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.noteOptionalLabel,
                hintText: AppLocalizations.of(context)!.partialPaymentHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_paymentController.text);
              if (amount == null || amount <= 0) return;
              
              final payment = CustomerPayment(
                customerId: widget.customerId,
                amount: amount,
                paymentDate: DateTime.now(),
                note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
              );
              
              await ref.read(customerActionsProvider).recordPayment(payment);
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {}); // Refresh future builders
              }
            },
            child: Text(AppLocalizations.of(context)!.savePayment),
          ),
        ],
      ),
    );
  }
}
