import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/cart_provider.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../generated/l10n/app_localizations_en.dart';
import '../../widgets/gradient_button.dart';
import '../../utils/region_utils.dart';
import '../../widgets/sinhala_transliteration_input.dart';
import '../../services/sinhala_transliteration_service.dart';

class QuickItemSheet extends ConsumerStatefulWidget {
  const QuickItemSheet({super.key});

  @override
  ConsumerState<QuickItemSheet> createState() => _QuickItemSheetState();
}

class _QuickItemSheetState extends ConsumerState<QuickItemSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, l10n),
          const SizedBox(height: 32),
          _buildTextField(
            controller: _nameController,
            focusNode: _focusNode,
            label: l10n?.itemName ?? 'Item Name',
            hint: 'e.g., General Item',
            icon: Icons.label_outline_rounded,
            textCapitalization: TextCapitalization.words,
            isItemName: true,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _priceController,
                  label: l10n?.price ?? 'Price',
                  hint: '0.00',
                  icon: Icons.currency_rupee_rounded,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '${globalAppRegion.currencySymbol} ',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildTextField(
                  controller: _quantityController,
                  label: l10n?.quantityLabel ?? 'Quantity',
                  hint: '1',
                  icon: Icons.tag_rounded,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          GradientButton(
            height: 64,
            onPressed: _handleAddToCart,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  (l10n?.addToCart ?? 'Add to Cart').toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations? l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 6),
                  Text(
                    'QUICK ENTRY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryGreen,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.quickItem.split(' (')[0] ?? 'Quick Item',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, size: 20, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? prefixText,
    bool isItemName = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: isItemName && SinhalaTransliterationService.isSinhala(controller.text)
              ? GoogleFonts.notoSansSinhala(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                )
              : GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.primaryPurple, size: 22),
            prefixText: prefixText,
            suffixIcon: isItemName
                ? SinhalaConvertSuffix(
                    controller: controller,
                    onConverted: () => setState(() {}),
                  )
                : null,
            prefixStyle: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
            ),
          ),
        ),
        if (isItemName)
          SinhalaSuggestionBanner(
            controller: controller,
            focusNode: focusNode,
            onApplied: () => setState(() {}),
          ),
      ],
    );
  }

  void _handleAddToCart() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text);
    final quantity = double.tryParse(_quantityController.text) ?? 1.0;
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterItemName)),
      );
      return;
    }

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterValidPrice)),
      );
      return;
    }

    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterValidQuantity)),
      );
      return;
    }

    ref.read(cartProvider.notifier).addQuickItem(
          name: name,
          price: price,
          quantity: quantity,
        );

    Navigator.pop(context);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.addedToCart(name)),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
