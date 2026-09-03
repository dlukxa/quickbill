import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/service.dart';
import '../../providers/service_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_button.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../utils/region_utils.dart';

class AddServiceScreen extends ConsumerStatefulWidget {
  final Service? service;
  const AddServiceScreen({super.key, this.service});

  @override
  ConsumerState<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends ConsumerState<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  bool _requiresBooking = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.service != null) {
      _nameController.text = widget.service!.name;
      _categoryController.text = widget.service!.category ?? '';
      _priceController.text = widget.service!.price.toString();
      _durationController.text = widget.service!.durationMinutes.toString();
      _requiresBooking = widget.service!.requiresBooking;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    final localizations = AppLocalizations.of(context)!;
    
    try {
      final service = Service(
        id: widget.service?.id,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        durationMinutes: int.tryParse(_durationController.text.trim()) ?? 30,
        requiresBooking: _requiresBooking,
        createdAt: widget.service?.createdAt,
      );

      if (widget.service != null) {
        await ref.read(serviceNotifierProvider.notifier).updateService(service);
      } else {
        await ref.read(serviceNotifierProvider.notifier).addService(service);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.service != null ? localizations.serviceUpdated : localizations.serviceAdded),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.service != null ? localizations.editService : localizations.addService),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.basicInformation,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '${localizations.serviceName} *',
                      hintText: localizations.serviceNameHint,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? localizations.required : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _categoryController,
                    decoration: InputDecoration(
                      labelText: localizations.category,
                      hintText: localizations.categoryHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '${localizations.price} *',
                      prefixText: '${globalAppRegion.currencySymbol} ',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return localizations.required;
                      if (double.tryParse(v) == null) return localizations.invalidAmount;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: localizations.durationMinutes,
                      hintText: 'e.g. 30',
                      suffixText: 'min',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // optional
                      if (int.tryParse(v) == null) return localizations.mustBeWholeNumber;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(localizations.requiresBooking),
                    subtitle: Text(localizations.requiresBookingSubtitle),
                    value: _requiresBooking,
                    onChanged: (val) => setState(() => _requiresBooking = val),
                    activeColor: AppTheme.primaryGreen,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(widget.service != null ? localizations.saveChanges : localizations.addService, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
