import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/custom_order_provider.dart';
import '../../providers/customer_provider.dart';
import 'create_order_screen.dart';
import 'order_detail_screen.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../utils/formatters.dart';

class OrdersBoardScreen extends ConsumerWidget {
  const OrdersBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(localizations.customOrders, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.primaryGreen,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: localizations.placed),
              Tab(text: localizations.inProgressStatus),
              Tab(text: localizations.readyStatus),
              Tab(text: localizations.deliveredStatus),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            OrderListTab(status: 'placed'),
            OrderListTab(status: 'inProgress'),
            OrderListTab(status: 'ready'),
            OrderListTab(status: 'delivered'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen()));
          },
          backgroundColor: AppTheme.primaryGreen,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(localizations.newOrder, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class OrderListTab extends ConsumerWidget {
  final String status;

  const OrderListTab({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(customOrdersProvider);
    final customersAsync = ref.watch(customersProvider);
    final localizations = AppLocalizations.of(context)!;

    return ordersAsync.when(
      data: (orders) {
        final filteredOrders = orders.where((o) => o.status == status).toList();
        
        if (filteredOrders.isEmpty) {
          String statusText = status;
          if (status == 'placed') statusText = localizations.placed;
          if (status == 'inProgress') statusText = localizations.inProgressStatus;
          if (status == 'ready') statusText = localizations.readyStatus;
          if (status == 'delivered') statusText = localizations.deliveredStatus;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(localizations.noOrdersStatus(statusText), style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final order = filteredOrders[index];
            final customer = customersAsync.valueOrNull?.firstWhere(
              (c) => c.id == order.customerId,
              orElse: () => throw Exception('Not found')
            );
            
            final customerName = customer?.name ?? 'Unknown Customer';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(localizations.orderNumber(order.id.toString()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(Formatters.currency(order.totalAmount), 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('${localizations.customer}: $customerName'),
                    Text('${localizations.dueDate}: ${DateFormat('MMM d, yyyy').format(order.dueDate)}'),
                    if (order.depositPaid == 1)
                      Text('${localizations.depositPaid}: ${Formatters.currency(order.depositAmount)}', 
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(order: order, customerName: customerName),
                  ));
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
