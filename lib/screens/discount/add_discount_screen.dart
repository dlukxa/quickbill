import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/discount.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/discount_provider.dart';
import '../../providers/branch_provider.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/app_card.dart';
import '../../utils/region_utils.dart';
import '../../utils/l10n_extensions.dart';

class AddDiscountScreen extends ConsumerStatefulWidget {
  const AddDiscountScreen({super.key});

  @override
  ConsumerState<AddDiscountScreen> createState() => _AddDiscountScreenState();
}

class _AddDiscountScreenState extends ConsumerState<AddDiscountScreen> {
  final _formKey = GlobalKey<FormState>();
  Product? _selectedProduct;
  final _valueController = TextEditingController();
  String _discountType = 'percentage';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isClearance = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.selectProduct)),
      );
      return;
    }

    final branchId = ref.read(currentBranchIdProvider);
    final discount = Discount(
      productId: _selectedProduct!.id,
      discountValue: double.parse(_valueController.text),
      discountType: _discountType,
      startDate: _startDate,
      endDate: _endDate,
      isClearance: _isClearance,
      branchId: branchId,
    );

    ref.read(discountsProvider.notifier).addDiscount(discount);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addDiscount),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Selection
              Text(l10n.selectProduct, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showProductSearch,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedProduct?.name ?? l10n.searchHint,
                          style: TextStyle(
                            color: _selectedProduct == null ? Colors.grey : Colors.black,
                          ),
                        ),
                      ),
                      if (_selectedProduct != null)
                        Text(
                          Formatters.currency(_selectedProduct!.price),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Discount Type
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(l10n.percentage),
                      value: 'percentage',
                      groupValue: _discountType,
                      onChanged: (v) => setState(() => _discountType = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(l10n.fixedAmount),
                      value: 'fixed',
                      groupValue: _discountType,
                      onChanged: (v) => setState(() => _discountType = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Discount Value
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: l10n.discountValue,
                  prefixText: _discountType == 'fixed' ? '${globalAppRegion.currencySymbol} ' : null,
                  suffixText: _discountType == 'percentage' ? '%' : null,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Date Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.scheduledDiscounts, style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text('${Formatters.date(_startDate)} - ${Formatters.date(_endDate)}'),
                    onPressed: _isClearance ? null : _selectDateRange,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Clearance Option
              SwitchListTile(
                title: Text(l10n.clearance),
                subtitle: Text(l10n.soldOutDiscountHint),
                value: _isClearance,
                onChanged: (v) => setState(() => _isClearance = v),
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.primaryBlue,
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _ProductSearchSheet(
          onProductSelected: (product) {
            setState(() => _selectedProduct = product);
            Navigator.pop(context);
          },
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _ProductSearchSheet extends ConsumerStatefulWidget {
  final Function(Product) onProductSelected;
  final ScrollController scrollController;

  const _ProductSearchSheet({
    required this.onProductSelected,
    required this.scrollController,
  });

  @override
  ConsumerState<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends ConsumerState<_ProductSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final branchId = ref.watch(currentBranchIdProvider);
    final productsAsync = ref.watch(searchProductsProvider(_query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: productsAsync.when(
            data: (products) => ListView.builder(
              controller: widget.scrollController,
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text(product.category != null ? context.getLocalizedCategory(product.category!) : ''),
                  trailing: Text(Formatters.currency(product.price)),
                  onTap: () => widget.onProductSelected(product),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}
