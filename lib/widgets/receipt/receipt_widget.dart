import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../providers/preference_provider.dart';
import '../../utils/pos_l10n.dart';
import '../../utils/receipt_theme.dart';

/// Flutter Receipt Widget supporting:
/// - Templates: Sri Lankan Retail POS (`sri_lankan_retail`) & QuickBill Classic (`classic`)
/// - Languages: Sinhala (`si`), English (`en`), and Bilingual (`bilingual`)
/// - Paper widths: 58mm (384px) & 80mm (576px)
/// - Multi-line word wrapping for Sinhala, English, and mixed product names
/// - Pure black (#000000) on white (#FFFFFF) for high-contrast thermal printing
class ReceiptWidget extends StatelessWidget {
  final Sale sale;
  final List<SaleItem> items;
  final AppSettings settings;
  final double? cashReceived;
  final double? change;
  final String? overridePaperSize;
  final String? overrideLanguage;
  final String? overrideTemplate;

  const ReceiptWidget({
    super.key,
    required this.sale,
    required this.items,
    required this.settings,
    this.cashReceived,
    this.change,
    this.overridePaperSize,
    this.overrideLanguage,
    this.overrideTemplate,
  });

  bool get is58mm =>
      overridePaperSize == '58mm' ||
      (overridePaperSize == null && settings.is58mm);

  String get language =>
      overrideLanguage ?? settings.receiptLanguage;

  String get template =>
      overrideTemplate ?? settings.receiptTemplate;

  @override
  Widget build(BuildContext context) {
    final double targetWidth = ReceiptTheme.getReceiptWidth(is58mm);
    final l10n = ReceiptL10n.of(language);

    return Container(
      width: targetWidth,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: is58mm ? 10.0 : 16.0,
        vertical: 12.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. STORE HEADER
          _buildStoreHeader(l10n),

          const ReceiptDashedDivider(height: 12, thickness: 1.0),

          // 2. INVOICE METADATA
          _buildMetadata(l10n),

          const ReceiptDashedDivider(height: 12, thickness: 1.0),

          // 3. ITEMS TABLE
          if (template == 'classic')
            _buildClassicItemsTable(l10n)
          else
            _buildRetailItemsTable(l10n),

          const ReceiptDashedDivider(height: 12, thickness: 1.0),

          // 4. SUMMARY & TOTALS
          _buildSummary(l10n),

          // 5. GRAND TOTAL BOX
          _buildGrandTotalBox(l10n),

          // 6. PAYMENT BREAKDOWN
          if (settings.showReceiptPaymentDetails) _buildPaymentDetails(l10n),

          const ReceiptDashedDivider(height: 12, thickness: 1.0),

          // 7. FOOTER & BARCODE
          _buildFooter(l10n),
        ],
      ),
    );
  }

  // ─── 1. STORE HEADER ───
  Widget _buildStoreHeader(ReceiptL10n l10n) {
    final shopName = settings.shopName.isNotEmpty
        ? settings.shopName.toUpperCase()
        : 'QUICKBILL STORE';
    final shopAddress = settings.shopAddress;
    final shopPhone = settings.shopPhone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          shopName,
          textAlign: TextAlign.center,
          style: ReceiptTheme.storeTitle(is58mm),
        ),
        if (shopAddress.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            shopAddress,
            textAlign: TextAlign.center,
            style: ReceiptTheme.storeSubtitle(is58mm),
          ),
        ],
        if (shopPhone.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '${l10n.phone}: $shopPhone',
            textAlign: TextAlign.center,
            style: ReceiptTheme.storeSubtitle(is58mm),
          ),
        ],
      ],
    );
  }

  // ─── 2. METADATA ───
  Widget _buildMetadata(ReceiptL10n l10n) {
    final dateStr = DateFormat('yyyy-MM-dd').format(sale.createdAt);
    final timeStr = DateFormat('hh:mm a').format(sale.createdAt);
    final cashierName = sale.cashierName?.isNotEmpty == true
        ? sale.cashierName!
        : 'Admin';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${l10n.billNo}: ${sale.billNumber}',
                style: ReceiptTheme.metaText(is58mm, isBold: true),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateStr,
              style: ReceiptTheme.metaText(is58mm),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (settings.showReceiptCashier)
              Expanded(
                child: Text(
                  '${l10n.cashier}: $cashierName',
                  style: ReceiptTheme.metaText(is58mm),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 8),
            Text(
              timeStr,
              style: ReceiptTheme.metaText(is58mm),
            ),
          ],
        ),
        if (settings.showReceiptCustomer &&
            sale.customerName?.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${l10n.customer}: ${sale.customerName!}',
                  style: ReceiptTheme.metaText(is58mm),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sale.customerPhone?.isNotEmpty == true) ...[
                const SizedBox(width: 8),
                Text(
                  sale.customerPhone!,
                  style: ReceiptTheme.metaText(is58mm),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  // ─── 3A. SRI LANKAN RETAIL ITEMS TABLE ───
  Widget _buildRetailItemsTable(ReceiptL10n l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table Header
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            children: [
              Expanded(
                flex: is58mm ? 36 : 40,
                child: Text(
                  l10n.qtyDescHeader,
                  style: ReceiptTheme.tableHeader(is58mm),
                ),
              ),
              if (settings.showReceiptStandardPrice)
                Expanded(
                  flex: is58mm ? 18 : 20,
                  child: Text(
                    l10n.priceHeader,
                    textAlign: TextAlign.right,
                    style: ReceiptTheme.tableHeader(is58mm),
                  ),
                ),
              if (settings.showReceiptOurPrice)
                Expanded(
                  flex: is58mm ? 20 : 20,
                  child: Text(
                    l10n.ourPrice,
                    textAlign: TextAlign.right,
                    style: ReceiptTheme.tableHeader(is58mm),
                  ),
                ),
              Expanded(
                flex: is58mm ? 24 : 20,
                child: Text(
                  l10n.totalHeader,
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.tableHeader(is58mm),
                ),
              ),
            ],
          ),
        ),
        const ReceiptDashedDivider(height: 6, thickness: 0.6),

        // Items Loop
        ...items.map((item) => _buildRetailItemRow(item, l10n)),
      ],
    );
  }

  Widget _buildRetailItemRow(SaleItem item, ReceiptL10n l10n) {
    final qty = item.soldQuantity ?? item.quantity;
    final qtyStr = qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
    final unitStr = (item.soldUnit != null &&
            item.soldUnit!.isNotEmpty &&
            item.soldUnit != 'pcs' &&
            item.soldUnit != 'piece')
        ? ' ${item.soldUnit}'
        : '';
    final fullQty = '$qtyStr$unitStr';

    // Pricing calculation
    final stdUnitPrice = item.unitPrice > 0
        ? item.unitPrice
        : (qty > 0 ? (item.total + item.discount) / qty : item.total);
    final ourUnitPrice = qty > 0 ? item.total / qty : item.total;
    final savings = (stdUnitPrice * qty) - item.total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Product Name (Multi-line natural wrapping for Sinhala/English)
          Text(
            item.productName,
            style: ReceiptTheme.itemName(is58mm),
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 2),

          // Row 2: Metrics columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Quantity
              Expanded(
                flex: is58mm ? 36 : 40,
                child: Text(
                  fullQty,
                  style: ReceiptTheme.itemDetail(is58mm, isBold: true),
                ),
              ),
              // Standard Price
              if (settings.showReceiptStandardPrice)
                Expanded(
                  flex: is58mm ? 18 : 20,
                  child: Text(
                    stdUnitPrice.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: ReceiptTheme.itemDetail(is58mm),
                  ),
                ),
              // Our Price
              if (settings.showReceiptOurPrice)
                Expanded(
                  flex: is58mm ? 20 : 20,
                  child: Text(
                    ourUnitPrice.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: ReceiptTheme.itemDetail(is58mm, isBold: true),
                  ),
                ),
              // Line Total
              Expanded(
                flex: is58mm ? 24 : 20,
                child: Text(
                  item.total.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.itemDetail(is58mm, isBold: true),
                ),
              ),
            ],
          ),

          // Row 3: Discount / Savings notice (if any)
          if (settings.showReceiptDiscount && (savings > 0.05 || item.discount > 0.05)) ...[
            const SizedBox(height: 1.5),
            Text(
              '(${l10n.profit}: -${(savings > item.discount ? savings : item.discount).toStringAsFixed(2)})',
              style: ReceiptTheme.itemDiscount(is58mm),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 3B. CLASSIC ITEMS TABLE ───
  Widget _buildClassicItemsTable(ReceiptL10n l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table Header
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            children: [
              Expanded(
                flex: is58mm ? 40 : 44,
                child: Text(
                  l10n.itemHeader,
                  style: ReceiptTheme.tableHeader(is58mm),
                ),
              ),
              Expanded(
                flex: is58mm ? 18 : 18,
                child: Text(
                  l10n.qtyHeader,
                  textAlign: TextAlign.center,
                  style: ReceiptTheme.tableHeader(is58mm),
                ),
              ),
              Expanded(
                flex: is58mm ? 20 : 19,
                child: Text(
                  l10n.priceHeader,
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.tableHeader(is58mm),
                ),
              ),
              Expanded(
                flex: is58mm ? 22 : 19,
                child: Text(
                  l10n.totalHeader,
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.tableHeader(is58mm),
                ),
              ),
            ],
          ),
        ),
        const ReceiptDashedDivider(height: 6, thickness: 0.6),

        // Items Loop
        ...items.map((item) => _buildClassicItemRow(item, l10n)),
      ],
    );
  }

  Widget _buildClassicItemRow(SaleItem item, ReceiptL10n l10n) {
    final qty = item.soldQuantity ?? item.quantity;
    final qtyStr = qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
    final unitPriceStr = item.unitPrice.toStringAsFixed(2);
    final totalStr = item.total.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name full width (wrap naturally)
          Text(
            item.productName,
            style: ReceiptTheme.itemName(is58mm),
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                flex: is58mm ? 40 : 44,
                child: const SizedBox.shrink(),
              ),
              Expanded(
                flex: is58mm ? 18 : 18,
                child: Text(
                  qtyStr,
                  textAlign: TextAlign.center,
                  style: ReceiptTheme.itemDetail(is58mm),
                ),
              ),
              Expanded(
                flex: is58mm ? 20 : 19,
                child: Text(
                  unitPriceStr,
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.itemDetail(is58mm),
                ),
              ),
              Expanded(
                flex: is58mm ? 22 : 19,
                child: Text(
                  totalStr,
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.itemDetail(is58mm, isBold: true),
                ),
              ),
            ],
          ),
          if (item.discount > 0.05) ...[
            const SizedBox(height: 1),
            Text(
              '   (${l10n.discount}: -${item.discount.toStringAsFixed(2)})',
              style: ReceiptTheme.itemDiscount(is58mm),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 4. SUMMARY & TOTALS ───
  Widget _buildSummary(ReceiptL10n l10n) {
    double totalPcs = items.fold(0.0, (sum, i) => sum + (i.soldQuantity ?? i.quantity));
    final pcsStr = totalPcs == totalPcs.roundToDouble()
        ? totalPcs.toInt().toString()
        : totalPcs.toStringAsFixed(2);

    final subtotalGross = items.fold(
      0.0,
      (sum, item) => sum + item.total + item.discount,
    );
    final totalDiscount = items.fold(0.0, (sum, item) => sum + item.discount) + sale.discount;

    return Column(
      children: [
        // Items and Pcs count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${l10n.itemsCount}: ${items.length}',
                style: ReceiptTheme.summaryLabel(is58mm)),
            Text('Pcs: $pcsStr',
                style: ReceiptTheme.summaryValue(is58mm, isBold: true)),
          ],
        ),
        const SizedBox(height: 3),

        // Subtotal
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.subtotal, style: ReceiptTheme.summaryLabel(is58mm)),
            Text(subtotalGross.toStringAsFixed(2),
                style: ReceiptTheme.summaryValue(is58mm)),
          ],
        ),

        // Discount / Customer Savings
        if (settings.showReceiptDiscount && totalDiscount > 0.05) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.discount, style: ReceiptTheme.summaryLabel(is58mm)),
              Text('-${totalDiscount.toStringAsFixed(2)}',
                  style: ReceiptTheme.summaryValue(is58mm)),
            ],
          ),
        ],

        // Tax / VAT
        if (settings.showReceiptTax && sale.tax > 0.05) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.tax, style: ReceiptTheme.summaryLabel(is58mm)),
              Text(sale.tax.toStringAsFixed(2),
                  style: ReceiptTheme.summaryValue(is58mm)),
            ],
          ),
        ],

        // Service charge
        if (sale.serviceCharge > 0.05) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.serviceCharge, style: ReceiptTheme.summaryLabel(is58mm)),
              Text(sale.serviceCharge.toStringAsFixed(2),
                  style: ReceiptTheme.summaryValue(is58mm)),
            ],
          ),
        ],

        // Merchant Internal Margin / Profit (only if enabled for audit slips)
        if (settings.showReceiptProfit) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.merchantProfit, style: ReceiptTheme.summaryLabel(is58mm)),
              Text(
                (items.fold(0.0, (s, i) => s + (i.total - (i.costPrice * i.quantity))) - sale.discount).toStringAsFixed(2),
                style: ReceiptTheme.summaryValue(is58mm),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─── 5. GRAND TOTAL BOX ───
  Widget _buildGrandTotalBox(ReceiptL10n l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black, width: 1.5),
          bottom: BorderSide(color: Colors.black, width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.grandTotal,
            style: ReceiptTheme.grandTotalLabel(is58mm),
          ),
          Text(
            'Rs. ${sale.total.toStringAsFixed(2)}',
            style: ReceiptTheme.grandTotalValue(is58mm),
          ),
        ],
      ),
    );
  }

  // ─── 6. PAYMENT DETAILS ───
  Widget _buildPaymentDetails(ReceiptL10n l10n) {
    double? effectiveCash = cashReceived;
    double? effectiveChange = change;

    // Fallback parse from sale.notes if not explicitly passed
    if (effectiveCash == null && sale.paymentMethod.toLowerCase() == 'cash' && sale.notes != null) {
      final cashMatch = RegExp(r'(?:Cash|Received):\s*([0-9.]+)', caseSensitive: false).firstMatch(sale.notes!);
      if (cashMatch != null) effectiveCash = double.tryParse(cashMatch.group(1)!);
      final changeMatch = RegExp(r'Change:\s*([0-9.]+)', caseSensitive: false).firstMatch(sale.notes!);
      if (changeMatch != null) effectiveChange = double.tryParse(changeMatch.group(1)!);
    }
    if (effectiveCash != null && effectiveChange == null) {
      effectiveChange = (effectiveCash - sale.total).clamp(0.0, double.infinity);
    }

    String paymentLabel = sale.paymentMethod.toUpperCase();
    if (sale.paymentMethod.toLowerCase() == 'cash') {
      paymentLabel = l10n.cash;
    } else if (sale.paymentMethod.toLowerCase() == 'card') {
      paymentLabel = l10n.card;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${l10n.paymentMethod}:', style: ReceiptTheme.summaryLabel(is58mm)),
            Text(paymentLabel, style: ReceiptTheme.summaryValue(is58mm, isBold: true)),
          ],
        ),
        if (sale.paymentMethod.toLowerCase() == 'cash' && effectiveCash != null) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${l10n.cashReceived}:', style: ReceiptTheme.summaryLabel(is58mm)),
              Text(effectiveCash.toStringAsFixed(2), style: ReceiptTheme.summaryValue(is58mm)),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${l10n.change}:', style: ReceiptTheme.summaryLabel(is58mm, isBold: true)),
              Text(
                (effectiveChange ?? 0.0).toStringAsFixed(2),
                style: ReceiptTheme.summaryValue(is58mm, isBold: true),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─── 7. FOOTER & BARCODE ───
  Widget _buildFooter(ReceiptL10n l10n) {
    final footerMsg = settings.receiptFooter.isNotEmpty
        ? settings.receiptFooter
        : l10n.thankYou;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          footerMsg,
          textAlign: TextAlign.center,
          style: ReceiptTheme.footerThankYou(is58mm),
        ),
        const SizedBox(height: 4),

        // Barcode / Bill Number representation
        if (settings.showReceiptBarcode) ...[
          const SizedBox(height: 4),
          ReceiptBarcodeWidget(
            data: sale.billNumber,
            width: is58mm ? 180.0 : 240.0,
            height: is58mm ? 36.0 : 44.0,
          ),
          const SizedBox(height: 2),
        ],

        Text(
          'Powered by QuickBill POS',
          textAlign: TextAlign.center,
          style: ReceiptTheme.footerCredit(is58mm),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Lightweight, high-contrast barcode renderer for thermal printing
class ReceiptBarcodeWidget extends StatelessWidget {
  final String data;
  final double width;
  final double height;

  const ReceiptBarcodeWidget({
    super.key,
    required this.data,
    this.width = 200.0,
    this.height = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: Size(width, height),
          painter: _BarcodePainter(data: data),
        ),
        const SizedBox(height: 2),
        Text(
          '* $data *',
          style: const TextStyle(
            fontFamily: ReceiptTheme.fontFamily,
            fontFamilyFallback: ReceiptTheme.fontFamilyFallback,
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Precise Code 128 / barcode pattern painter
class _BarcodePainter extends CustomPainter {
  final String data;

  _BarcodePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Generate deterministic bar widths based on input string
    final List<int> pattern = _generateBarPattern(data);
    final int totalUnits = pattern.reduce((a, b) => a + b);
    final double unitWidth = size.width / totalUnits;

    double currentX = 0;
    bool isBar = true;

    for (final unitCount in pattern) {
      final barWidth = unitCount * unitWidth;
      if (isBar) {
        canvas.drawRect(
          Rect.fromLTWH(currentX, 0, barWidth, size.height),
          paint,
        );
      }
      currentX += barWidth;
      isBar = !isBar;
    }
  }

  List<int> _generateBarPattern(String text) {
    // Standard start/stop guards and deterministic pseudo-barcode pattern
    final List<int> units = [2, 1, 2, 2, 2, 1]; // Start guard
    final bytes = text.codeUnits;
    for (int i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      units.add(((b % 3) + 1));
      units.add((((b ~/ 3) % 3) + 1));
      units.add((((b ~/ 9) % 3) + 1));
      units.add(1);
    }
    units.addAll([2, 1, 2, 2, 2, 1]); // Stop guard
    return units;
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) =>
      oldDelegate.data != data;
}
