import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../models/sales_return.dart';
import '../../models/sales_return_item.dart';
import '../../providers/product_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/return_provider.dart';
import '../../providers/sale_provider.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_button.dart';

class ProcessReturnScreen extends ConsumerStatefulWidget {
  final Sale sale;
  const ProcessReturnScreen({super.key, required this.sale});

  @override
  ConsumerState<ProcessReturnScreen> createState() => _ProcessReturnScreenState();
}

class _ProcessReturnScreenState extends ConsumerState<ProcessReturnScreen> {
  final Map<int, double> _restockableQuantities = {}; // itemId -> restockableQty
  final Map<int, double> _damagedQuantities = {}; // itemId -> damagedQty
  List<SaleItem> _items = [];
  bool _loading = true;
  String _refundType = 'cash'; // or 'credit'
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseService.instance.getSaleItems(widget.sale.id!);
    setState(() {
      _items = items;
      for (var item in items) {
        _restockableQuantities[item.id!] = 0.0;
        _damagedQuantities[item.id!] = 0.0;
      }
      _loading = false;
    });
  }

  double get _totalRefund {
    double total = 0;
    for (var item in _items) {
      final restock = _restockableQuantities[item.id] ?? 0.0;
      final damaged = _damagedQuantities[item.id] ?? 0.0;
      total += item.unitPrice * (restock + damaged);
    }
    return total;
  }

  Future<void> _processReturn() async {
    final returnItemsList = <SalesReturnItem>[];
    
    for (var item in _items) {
      final restock = _restockableQuantities[item.id] ?? 0.0;
      final damaged = _damagedQuantities[item.id] ?? 0.0;
      
      if (restock > 0) {
        returnItemsList.add(SalesReturnItem(
          returnId: 0,
          productId: item.productId,
          batchId: item.batchId,
          quantity: restock,
          refundAmount: item.unitPrice * restock,
          condition: 'restockable',
        ));
      }
      if (damaged > 0) {
        returnItemsList.add(SalesReturnItem(
          returnId: 0,
          productId: item.productId,
          batchId: item.batchId,
          quantity: damaged,
          refundAmount: item.unitPrice * damaged,
          condition: 'damaged',
        ));
      }
    }

    if (returnItemsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select items to return')),
      );
      return;
    }

    setState(() => _processing = true);

    try {
      final returnData = SalesReturn(
        saleId: widget.sale.id!,
        branchId: widget.sale.branchId,
        returnDate: DateTime.now(),
        refundAmount: _totalRefund,
        refundType: _refundType,
        reason: 'Manually processed return',
        employeeId: widget.sale.employeeId,
      );

      await ref.read(returnServiceProvider).processReturn(
        returnData: returnData,
        items: returnItemsList,
      );

      // Refresh reports and history
      ref.invalidate(refundsProvider);
      ref.invalidate(recentSalesProvider);
      ref.invalidate(salesChartProvider); // In case returns affect revenue
      ref.invalidate(todayStatsProvider); // CRITICAL for dashboard
      ref.invalidate(productsProvider); // Stock changed
      ref.invalidate(lowStockProductsProvider);
      ref.invalidate(inventoryAlertsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return processed successfully')),
        );
        Navigator.pop(context); // Close process screen
        Navigator.pop(context); // Close List screen? or just this one. 
        // Logic: Return to sales list or dash?
        // Let's pop to list.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Process Return')),
      body: Column(
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Invoice: ${widget.sale.billNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Date: ${Formatters.date(widget.sale.createdAt)}'),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final item = _items[index];
                final restockQty = _restockableQuantities[item.id] ?? 0.0;
                final damagedQty = _damagedQuantities[item.id] ?? 0.0;
                
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Sold: ${Formatters.quantity(item.quantity)} x ${Formatters.currency(item.unitPrice)}'),
                        if (item.batchNumber != null)
                          Text('Batch: ${item.batchNumber}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const Divider(height: 24),
                        _buildCounterRow(
                          title: 'Return to Stock',
                          color: AppTheme.primaryGreen,
                          currentVal: restockQty,
                          absoluteMax: item.quantity - damagedQty,
                          onChanged: (val) => setState(() => _restockableQuantities[item.id!] = val),
                        ),
                        const SizedBox(height: 12),
                        _buildCounterRow(
                          title: 'Damaged / Waste',
                          color: AppTheme.errorRed,
                          currentVal: damagedQty,
                          absoluteMax: item.quantity - restockQty,
                          onChanged: (val) => setState(() => _damagedQuantities[item.id!] = val),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Bottom Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Refund Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ToggleButtons(
                      isSelected: [_refundType == 'cash', _refundType == 'credit'],
                      onPressed: (index) {
                        setState(() => _refundType = index == 0 ? 'cash' : 'credit');
                      },
                      constraints: const BoxConstraints(minHeight: 32, minWidth: 80),
                      borderRadius: BorderRadius.circular(8),
                      children: const [
                        Text('Cash'),
                        Text('Credit'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Refund:', style: TextStyle(fontSize: 18)),
                    Text(
                      Formatters.currency(_totalRefund),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GradientButton(
                  onPressed: _totalRefund > 0 ? _processReturn : null,
                  child: _processing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm Return', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(double currentVal, double absoluteMax, Function(double) onChanged) {
    final controller = TextEditingController(text: currentVal.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Quantity'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            hintText: 'Max $absoluteMax',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 0 && val <= absoluteMax) {
                onChanged(val);
                Navigator.pop(context);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterRow({
    required String title,
    required Color color,
    required double currentVal,
    required double absoluteMax,
    required Function(double) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  if (currentVal > 0) {
                    onChanged(currentVal - (currentVal >= 1 ? 1 : currentVal));
                  }
                },
              ),
              InkWell(
                onTap: () => _showQuantityDialog(currentVal, absoluteMax, onChanged),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    Formatters.quantity(currentVal),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  if (currentVal < absoluteMax) {
                    onChanged((currentVal + 1).clamp(0.0, absoluteMax));
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
