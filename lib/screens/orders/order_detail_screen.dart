import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/custom_order.dart';
import '../../models/custom_order_item.dart';
import '../../providers/custom_order_provider.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../utils/formatters.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final CustomOrder order;
  final String customerName;

  const OrderDetailScreen({super.key, required this.order, required this.customerName});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  List<CustomOrderItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await ref.read(customOrderActionsProvider).getOrderItems(widget.order.id!);
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _updateStatus(String newStatus) async {
    await ref.read(customOrderActionsProvider).updateStatus(widget.order.id!, newStatus);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    String localizedStatus = widget.order.status;
    if (widget.order.status == 'placed') localizedStatus = localizations.placed;
    if (widget.order.status == 'inProgress') localizedStatus = localizations.inProgressStatus;
    if (widget.order.status == 'ready') localizedStatus = localizations.readyStatus;
    if (widget.order.status == 'delivered') localizedStatus = localizations.deliveredStatus;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.orderNumber(widget.order.id.toString())),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(localizations.customer, style: const TextStyle(color: Colors.grey)),
                      Text(widget.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(localizations.dueDate, style: const TextStyle(color: Colors.grey)),
                      Text(DateFormat('MMM d, yyyy').format(widget.order.dueDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status', style: TextStyle(color: Colors.grey)),
                      Chip(
                        label: Text(localizedStatus.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: _getStatusColor(widget.order.status),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(localizations.orderItems, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: _items.map((item) => ListTile(
                title: Text(item.description),
                subtitle: Text('${localizations.quantity.split(' ')[0]}: ${item.quantity}'),
                trailing: Text(Formatters.currency(item.quantity * item.unitPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
              )).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: AppTheme.primaryGreen.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(localizations.total),
                      Text(Formatters.currency(widget.order.totalAmount), style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(localizations.depositPaid, style: const TextStyle(color: Colors.green)),
                      Text('-\$${widget.order.depositAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 16)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(localizations.balanceDue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(Formatters.currency(widget.order.totalAmount - widget.order.depositAmount), 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.order.notes != null && widget.order.notes!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(localizations.notesMeasurements, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.order.notes!),
              ),
            ),
          ],
          
          const SizedBox(height: 32),
          if (widget.order.status == 'placed')
            ElevatedButton(
              onPressed: () => _updateStatus('inProgress'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(localizations.markInProgress, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          if (widget.order.status == 'inProgress')
            ElevatedButton(
              onPressed: () => _updateStatus('ready'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(localizations.markReady, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'placed': return Colors.grey.shade700;
      case 'inProgress': return Colors.blue;
      case 'ready': return Colors.orange;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
}
