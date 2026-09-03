import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/custom_order.dart';
import '../../models/custom_order_item.dart';
import '../../models/customer.dart';
import '../../providers/custom_order_provider.dart';
import '../../providers/customer_provider.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../utils/region_utils.dart';
import '../../utils/formatters.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  Customer? _selectedCustomer;
  DateTime? _dueDate;
  
  final _depositController = TextEditingController();
  final _notesController = TextEditingController();
  
  List<CustomOrderItem> _items = [];

  void _addItem() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        final descCtrl = TextEditingController();
        final qtyCtrl = TextEditingController(text: '1');
        final priceCtrl = TextEditingController();
        
        return AlertDialog(
          title: Text(localizations.addItem),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: localizations.description),
              ),
              TextField(
                controller: qtyCtrl,
                decoration: InputDecoration(labelText: localizations.quantity),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: priceCtrl,
                decoration: InputDecoration(labelText: localizations.unitPrice),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final desc = descCtrl.text.trim();
                final qty = double.tryParse(qtyCtrl.text) ?? 1.0;
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                
                if (desc.isNotEmpty && price > 0) {
                  setState(() {
                    _items.add(CustomOrderItem(
                      orderId: 0, // Placeholder, updated in provider
                      description: desc,
                      quantity: qty,
                      unitPrice: price,
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(localizations.add),
            ),
          ],
        );
      }
    );
  }

  void _saveOrder() async {
    final localizations = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate() && _selectedCustomer != null && _dueDate != null && _items.isNotEmpty) {
      double total = _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));
      double deposit = double.tryParse(_depositController.text) ?? 0.0;
      
      final order = CustomOrder(
        customerId: _selectedCustomer!.id,
        dueDate: _dueDate!,
        depositAmount: deposit,
        depositPaid: deposit > 0 ? 1 : 0, // Simplified: Assume deposit is paid upfront for now
        totalAmount: total,
        status: 'placed',
        notes: _notesController.text,
      );
      
      await ref.read(customOrderActionsProvider).createOrder(order, _items);
      if (mounted) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.pleaseFillRequired)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    double total = _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.newOrder, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(localizations.customerDetails, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            customersAsync.when(
              data: (customers) => DropdownButtonFormField<Customer>(
                decoration: InputDecoration(labelText: localizations.selectCustomer, border: const OutlineInputBorder()),
                value: _selectedCustomer,
                items: customers.map((c) => DropdownMenuItem(value: c, child: Text('${c.name} (${c.phone ?? ''})'))).toList(),
                onChanged: (val) => setState(() => _selectedCustomer = val),
                validator: (val) => val == null ? localizations.required : null,
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),
            
            Text(localizations.orderItems, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(localizations.noItemsAdded),
              )
            else
              ..._items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return ListTile(
                  title: Text(item.description),
                  subtitle: Text('${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Formatters.currency(item.quantity * item.unitPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _items.removeAt(idx))),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: Text(localizations.addItem),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                foregroundColor: AppTheme.primaryGreen,
                elevation: 0,
              ),
            ),
            
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${localizations.total}:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(Formatters.currency(total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Text(localizations.schedulePayment, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(localizations.dueDate),
              subtitle: Text(_dueDate != null ? DateFormat('MMM d, yyyy').format(_dueDate!) : localizations.selectDate),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _depositController,
              decoration: InputDecoration(labelText: '${localizations.depositAmount} (${localizations.optionalHint})', prefixText: '${globalAppRegion.currencySymbol} ', border: const OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(labelText: localizations.notesMeasurements, border: const OutlineInputBorder(), alignLabelWithHint: true),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(localizations.placeCustomOrder, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
