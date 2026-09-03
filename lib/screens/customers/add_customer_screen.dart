import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../generated/l10n/app_localizations_en.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animate_in.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  final Customer? customer; // For editing

  const AddCustomerScreen({super.key, this.customer});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    _addressController = TextEditingController(text: widget.customer?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final customer = Customer(
        id: widget.customer?.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        totalDebt: widget.customer?.totalDebt ?? 0,
        createdAt: widget.customer?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final messenger = ScaffoldMessenger.of(context);
      final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();

      if (widget.customer != null) {
        await ref.read(customerActionsProvider).updateCustomer(customer);
        messenger.showSnackBar(SnackBar(content: Text(l10n.customerUpdatedSuccessfully)));
      } else {
        await ref.read(customerActionsProvider).addCustomer(customer);
        messenger.showSnackBar(SnackBar(content: Text(l10n.customerAddedSuccessfully)));
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer != null 
          ? l10n.editCustomer 
          : l10n.addNewCustomer),
      ),
      body: SingleChildScrollView(
        child: AnimateIn(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: l10n.fullNameLabel,
                            prefixIcon: const Icon(Icons.person),
                          ),
                          validator: (value) => 
                              value == null || value.isEmpty ? l10n.required : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: l10n.phoneNumberLabel,
                            prefixIcon: const Icon(Icons.phone),
                            hintText: l10n.phoneHint,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: l10n.addressLabel,
                            prefixIcon: const Icon(Icons.location_on),
                            hintText: l10n.optionalHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  GradientButton(
                    onPressed: _isSubmitting ? null : _saveCustomer,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : Text(widget.customer != null 
                            ? l10n.updateCustomer 
                            : l10n.addCustomer),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
