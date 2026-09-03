import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/supplier.dart';
import '../../providers/supplier_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animate_in.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/category_constants.dart';
import '../../utils/category_icon_util.dart';
import '../../utils/l10n_extensions.dart';

class AddSupplierScreen extends ConsumerStatefulWidget {
  final Supplier? supplier;

  const AddSupplierScreen({super.key, this.supplier});

  @override
  ConsumerState<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends ConsumerState<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  TextEditingController _providedItemsController = TextEditingController();
  String? _selectedCategory;
  final _categorySearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _phoneController = TextEditingController(text: widget.supplier?.phone ?? '');
    _addressController = TextEditingController(text: widget.supplier?.address ?? '');
    _providedItemsController.text = widget.supplier?.providedItems ?? '';
    
    final cat = widget.supplier?.category;
    if (cat != null && cat.isNotEmpty) {
      _selectedCategory = cat;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _providedItemsController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    
    final supplier = Supplier(
      id: widget.supplier?.id,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      providedItems: _providedItemsController.text.trim().isEmpty ? null : _providedItemsController.text.trim(),
      category: _selectedCategory,
      totalPending: widget.supplier?.totalPending ?? 0.0,
      createdAt: widget.supplier?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.supplier != null) {
        await ref.read(supplierActionsProvider).updateSupplier(supplier);
        messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.supplierUpdatedSuccessfully)));
      } else {
        await ref.read(supplierActionsProvider).addSupplier(supplier);
        messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.supplierAddedSuccessfully)));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.errorSavingSupplier}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier != null ? AppLocalizations.of(context)!.editSupplier : AppLocalizations.of(context)!.addSupplier),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimateIn(
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: AppLocalizations.of(context)!.supplierNameLabel,
                        icon: Icons.business,
                        validator: (v) => v!.isEmpty ? AppLocalizations.of(context)!.pleaseEnterName : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: AppLocalizations.of(context)!.phoneNumber,
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _addressController,
                        label: AppLocalizations.of(context)!.address,
                        icon: Icons.location_on,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _providedItemsController,
                        label: AppLocalizations.of(context)!.providedItems,
                        icon: Icons.inventory_2,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Category Selection — Search and Subcategories
              AnimateIn(
                delay: const Duration(milliseconds: 100),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.category,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.subText,
                            ),
                          ),
                          if (_selectedCategory != null)
                            Builder(
                              builder: (context) {
                                String selectedPrefix = 'Selected';
                                final locale = Localizations.localeOf(context).languageCode;
                                if (locale == 'si') {
                                  selectedPrefix = 'තෝරාගෙන ඇත';
                                } else if (locale == 'ta') {
                                  selectedPrefix = 'தேர்ந்தெடுக்கப்பட்டது';
                                } else if (locale == 'hi') {
                                  selectedPrefix = 'चयनित';
                                } else if (locale == 'bn') {
                                  selectedPrefix = 'নির্বাচিত';
                                } else if (locale == 'dv') {
                                  selectedPrefix = 'ހޮވާފައިވަނީ';
                                }
                                return Text(
                                  '$selectedPrefix: ${context.getLocalizedCategory(_selectedCategory!)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Search box for categories
                      TextFormField(
                        controller: _categorySearchController,
                        decoration: InputDecoration(
                          hintText: 'Search categories...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _categorySearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _categorySearchController.clear();
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),

                      if (_categorySearchController.text.trim().isNotEmpty) ...[
                        // Display filtered search results
                        Text(
                          'Search Results',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.subText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final query = _categorySearchController.text.trim().toLowerCase();
                            final matchingMain = CategoryConstants.mainCategories
                                .where((cat) => cat.toLowerCase().contains(query) ||
                                                context.getLocalizedCategory(cat).toLowerCase().contains(query))
                                .toList();
                            final matchingSub = CategoryConstants.allSubcategories
                                .where((sub) => sub.toLowerCase().contains(query) ||
                                                context.getLocalizedCategory(sub).toLowerCase().contains(query))
                                .toList();

                            if (matchingMain.isEmpty && matchingSub.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    'No categories found.',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: context.subText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...matchingMain.map((main) {
                                  final isSelected = _selectedCategory == main;
                                  final color = CategoryIconUtil.getColorForMainCategory(main);
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory = main;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? color.withValues(alpha: 0.15)
                                            : context.cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? color : context.borderColor.withValues(alpha: 0.4),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CategoryIconUtil.getIconForMainCategory(main),
                                            size: 16,
                                            color: isSelected ? color : context.subText,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            context.getLocalizedCategory(main),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              color: isSelected ? color : context.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                ...matchingSub.map((sub) {
                                  final isSelected = _selectedCategory == sub;
                                  final color = CategoryIconUtil.getColorForCategory(sub);
                                  final parentMain = CategoryConstants.getMainCategory(sub);
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory = sub;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? color.withValues(alpha: 0.15)
                                            : context.cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? color : context.borderColor.withValues(alpha: 0.4),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CategoryIconUtil.getIconForCategory(sub),
                                            size: 16,
                                            color: isSelected ? color : context.subText,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${context.getLocalizedCategory(sub)} (${context.getLocalizedCategory(parentMain)})',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              color: isSelected ? color : context.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ] else ...[
                        // Default Categories Grid
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: CategoryConstants.mainCategories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            final color = CategoryIconUtil.getColorForMainCategory(cat);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withValues(alpha: 0.15)
                                      : context.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? color : context.borderColor.withValues(alpha: 0.4),
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CategoryIconUtil.getIconForMainCategory(cat),
                                      size: 24,
                                      color: isSelected ? color : context.subText,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      context.getLocalizedCategory(cat),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? color : context.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              AnimateIn(
                delay: const Duration(milliseconds: 200),
                child: GradientButton(
                  onPressed: _saveSupplier,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.save, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(widget.supplier != null ? AppLocalizations.of(context)!.updateSupplier : AppLocalizations.of(context)!.saveSupplier),
                    ],
                  ),
                ),
              ),
              if (widget.supplier != null) ...[
                const SizedBox(height: 16),
                AnimateIn(
                  delay: const Duration(milliseconds: 300),
                  child: TextButton.icon(
                    onPressed: () => _confirmDelete(),
                    icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                    label: Text(AppLocalizations.of(context)!.deleteSupplier, style: const TextStyle(color: AppTheme.errorRed)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteSupplierTitle),
        content: Text(AppLocalizations.of(context)!.deleteSupplierConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
            onPressed: () async {
              await ref.read(supplierActionsProvider).deleteSupplier(widget.supplier!.id!);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            }, 
            child: Text(AppLocalizations.of(context)!.delete, style: const TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }
}
