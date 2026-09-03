import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/cart_item.dart';
import '../../widgets/shake_widget.dart';
import '../../providers/sale_provider.dart';
import '../../utils/formatters.dart';
import '../../services/pdf_service.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../models/customer.dart';
import '../../providers/preference_provider.dart';
import '../../services/printing_service.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../services/share_service.dart';
import '../../utils/region_utils.dart';
import '../../providers/multi_bill_provider.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final List<CartItem> cartItems;
  final double total;
  final double discount;
  final double tax;
  final double serviceCharge;

  const PaymentScreen({
    super.key,
    required this.cartItems,
    required this.total,
    this.discount = 0.0,
    this.tax = 0.0,
    this.serviceCharge = 0.0,
    this.customer,
  });

  final Customer? customer;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  final ShakeController _shakeController = ShakeController();
  double _paidAmount = 0;
  String _paymentMethod = 'cash';
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _paidAmount = widget.total;
    _amountController.text = widget.total.toStringAsFixed(0);
  }

  double get change => _paidAmount - widget.total;

  void _setAmount(double amount) {
    setState(() {
      _paidAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _completeSale() async {
    final bool isCredit = _paymentMethod == 'credit';
    if (!isCredit && _paidAmount < widget.total) {
      _shakeController.shake();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.paymentLessError), backgroundColor: AppTheme.errorRed),
      );
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final saleActions = ref.read(saleActionsProvider);
      final createdSale = await saleActions.createSale(
        cartItems: widget.cartItems,
        total: widget.total,
        discount: widget.discount,
        tax: widget.tax,
        serviceCharge: widget.serviceCharge,
        paymentMethod: _paymentMethod,
        customerId: widget.customer?.id,
        customerName: widget.customer?.name,
        customerPhone: widget.customer?.phone,
      );
      ref.read(multiBillProvider.notifier).onSaleCompleted();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _SuccessDialog(
            sale: createdSale,
            total: widget.total,
            change: change,
            discount: widget.discount,
            paymentMethod: _paymentMethod,
            cartItems: widget.cartItems,
            customer: widget.customer,
            l10n: l10n,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool isCredit = _paymentMethod == 'credit';

    // Theme-adaptive colors
    final cardColor  = context.cardColor;
    final textColor  = context.onSurface;
    final subColor   = context.subText;
    final border     = context.borderColor;

    bool isTablet = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.completeSale,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: isTablet 
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT: Payment Info & Methods
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTotalDueCard(cardColor, textColor, subColor, border),
                        const SizedBox(height: 32),
                        _buildPaymentMethodSection(subColor, cardColor, border),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // RIGHT: Transaction Actions
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isCredit) ...[
                                _buildAmountInputSection(subColor, textColor),
                                const SizedBox(height: 24),
                                _buildChangeCard(l10n),
                              ] else if (widget.customer != null) 
                                _buildCreditWarning(l10n),
                            ],
                          ),
                        ),
                      ),
                      _buildCompleteButton(l10n, border),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTotalDueCard(cardColor, textColor, subColor, border),
                        const SizedBox(height: 20),
                        _buildPaymentMethodSection(subColor, cardColor, border),
                        if (!isCredit) ...[
                          const SizedBox(height: 20),
                          _buildAmountInputSection(subColor, textColor),
                          const SizedBox(height: 20),
                          if (_paidAmount > 0) _buildChangeCard(l10n),
                        ],
                        if (widget.customer != null && isCredit)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildCreditWarning(l10n),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                _buildCompleteButton(l10n, border),
              ],
            ),
      ),
    );
  }

  Widget _buildTotalDueCard(cardColor, textColor, subColor, border) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'TOTAL DUE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12, 
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryGreen, 
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            Formatters.currency(widget.total),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 44, 
              fontWeight: FontWeight.w800, 
              color: textColor, 
              height: 1,
            ),
          ),
          if (widget.discount > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Discount applied: ${Formatters.currency(widget.discount)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (widget.customer != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, size: 14, color: subColor),
                const SizedBox(width: 4),
                Text(widget.customer!.name, style: TextStyle(color: subColor, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(subColor, cardColor, border) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PAYMENT METHOD',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subColor, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _PaymentMethodCard(label: 'Cash', icon: Icons.payments_outlined,
                isSelected: _paymentMethod == 'cash', cardColor: cardColor, border: border,
                onTap: () => setState(() => _paymentMethod = 'cash'))),
            const SizedBox(width: 10),
            Expanded(child: _PaymentMethodCard(label: 'Card', icon: Icons.credit_card_outlined,
                isSelected: _paymentMethod == 'card', cardColor: cardColor, border: border,
                onTap: () => setState(() => _paymentMethod = 'card'))),
            const SizedBox(width: 10),
            Expanded(child: _PaymentMethodCard(label: 'Credit', icon: Icons.account_balance_wallet_outlined,
                isSelected: _paymentMethod == 'credit', cardColor: cardColor, border: border,
                onTap: () => setState(() => _paymentMethod = 'credit'))),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountInputSection(subColor, textColor) {
    final cardColor  = context.cardColor;
    final border     = context.borderColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AMOUNT PAID',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subColor, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        ShakeWidget(
          controller: _shakeController,
          child: TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: '${globalAppRegion.currencySymbol} ',
              hintText: '0',
            ),
            onChanged: (val) => setState(() => _paidAmount = double.tryParse(val) ?? 0),
          ),
        ),
        const SizedBox(height: 14),
        Text('QUICK AMOUNTS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subColor, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickAmountChip(label: 'Exact', cardColor: cardColor, border: border,
                isSelected: _paidAmount == widget.total,
                onTap: () => _setAmount(widget.total)),
            for (final amt in [500.0, 1000.0, 2000.0, 5000.0])
              _QuickAmountChip(label: Formatters.currencySimple(amt), cardColor: cardColor, border: border,
                  isSelected: _paidAmount == amt,
                  onTap: () => _setAmount(amt)),
          ],
        ),
      ],
    );
  }

  Widget _buildChangeCard(l10n) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: change >= 0
            ? AppTheme.primaryGreen.withValues(alpha: 0.15)
            : AppTheme.errorRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: change >= 0
              ? AppTheme.primaryGreen.withValues(alpha: 0.4)
              : AppTheme.errorRed.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Text(
            change >= 0
                ? l10n.changeToGive.toUpperCase()
                : l10n.insufficientPayment.toUpperCase(),
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4,
              color: change >= 0 ? AppTheme.primaryGreen : AppTheme.errorRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.currency(change.abs()),
            style: TextStyle(
              fontSize: 38, fontWeight: FontWeight.w800, height: 1,
              color: change >= 0 ? AppTheme.primaryGreen : AppTheme.errorRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditWarning(l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: AppTheme.errorRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(l10n.customerDebtNote,
                style: const TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton(l10n, border) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: context.scaffoldColor,
        border: Border(top: BorderSide(color: border)),
      ),
      child: GestureDetector(
        onTap: _isProcessing ? null : _completeSale,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: _isProcessing
                ? const LinearGradient(colors: [Color(0xFF374151), Color(0xFF374151)])
                : AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _isProcessing ? [] : [
              BoxShadow(
                color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: _isProcessing
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.completeSale,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color cardColor;
  final Color border;
  final VoidCallback onTap;

  const _PaymentMethodCard({required this.label, required this.icon, required this.isSelected,
      required this.cardColor, required this.border, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.12) : cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : border, 
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryGreen : context.subText, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: isSelected ? AppTheme.primaryGreen : context.subText)),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color cardColor;
  final Color border;
  final VoidCallback onTap;

  const _QuickAmountChip({required this.label, required this.isSelected,
      required this.cardColor, required this.border, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryGreen : border),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : context.subText)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessDialog extends ConsumerStatefulWidget {
  final Sale sale;
  final double total;
  final double change;
  final double discount;
  final String paymentMethod;
  final List<CartItem> cartItems;
  final Customer? customer;
  final AppLocalizations l10n;

  const _SuccessDialog({
    required this.sale,
    required this.total,
    required this.change,
    required this.discount,
    required this.paymentMethod,
    required this.cartItems,
    required this.customer,
    required this.l10n,
  });

  @override
  ConsumerState<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends ConsumerState<_SuccessDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      if (settings.autoPrintReceipt) {
        PrintingService.instance.printReceiptUnified(widget.sale, _buildSaleItems(), settings);
      }
    });
  }

  List<SaleItem> _buildSaleItems() => widget.cartItems.map((c) => SaleItem(
        saleId: widget.sale.id ?? 0, 
        productId: c.itemType == 'product' && !c.isQuickItem ? c.product!.id! : 0, 
        itemType: c.itemType,
        serviceId: c.serviceId,
        productName: c.itemName,
        quantity: c.quantity, 
        unitPrice: c.itemPrice, 
        total: c.total,
        costPrice: (c.itemType == 'product' && !c.isQuickItem) ? (c.product!.costPrice ?? 0.0) : 0.0,
        batchId: c.batchId, 
        batchNumber: c.batchNumber, 
        discount: c.discount,
      )).toList();

  @override
  Widget build(BuildContext context) {
    final settings = ref.read(settingsProvider);
    return AlertDialog(
      title: Text(widget.l10n.saleComplete),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 16),
          Text('${widget.l10n.total}: ${Formatters.currency(widget.total)}',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.onSurface)),
          if (widget.change > 0) ...[
            const SizedBox(height: 6),
            Text('${widget.l10n.change}: ${Formatters.currency(widget.change)}',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
          ],
        ],
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () async {
                await PrintingService.instance.printReceiptUnified(widget.sale, _buildSaleItems(), settings);
              },
              icon: const Icon(Icons.print, size: 18),
              label: Text(settings.is58mm ? 'Print Receipt (58mm)' : 'Print Receipt (80mm)'),
            ),
            ElevatedButton(
              onPressed: () async => PdfService.instance.generateProfessionalInvoice(widget.sale, _buildSaleItems(), settings: settings),
              child: Text(widget.l10n.printInvoiceA4),
            ),
            if (widget.sale.customerPhone != null && widget.sale.customerPhone!.isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: () => ShareService.instance.shareViaWhatsApp(widget.sale, _buildSaleItems(), settings),
                icon: const Icon(Icons.chat, size: 18),
                label: Text(widget.l10n.shareViaWhatsApp),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => ShareService.instance.shareViaSMS(widget.sale, _buildSaleItems(), settings),
                icon: const Icon(Icons.message, size: 18),
                label: Text(widget.l10n.shareViaSMS),
              ),
            ],
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text(widget.l10n.done),
            ),
          ],
        ),
      ],
    );
  }
}
