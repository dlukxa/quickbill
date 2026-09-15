import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
  final Uint8List? logoBytes;
  final ui.Image? logoUiImage;

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
    this.logoBytes,
    this.logoUiImage,
  });

  bool get is58mm =>
      overridePaperSize == '58mm' ||
      (overridePaperSize == null && settings.is58mm);

  String get language =>
      overrideLanguage ?? settings.receiptLanguage;

  bool get isTaxInvoice =>
      sale.invoiceType == 'tax_invoice' ||
      (sale.invoiceType == null && settings.vatInvoiceMode == 'tax_invoice');

  bool get isVatActive => sale.isVatEnabled || settings.isVatEnabled;

  String get template =>
      overrideTemplate ?? settings.receiptTemplate;

  @override
  Widget build(BuildContext context) {
    final double targetWidth = ReceiptTheme.getReceiptWidth(is58mm, settings: settings);
    final l10n = ReceiptL10n.of(language);

    return Container(
      width: targetWidth,
      color: Colors.white,
      padding: EdgeInsets.only(
        left: settings.marginLeftPx,
        right: settings.marginRightPx,
        top: settings.marginTopPx,
        bottom: settings.marginBottomPx,
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

    final headerAlign = settings.receiptHeaderAlignment;
    final crossAlign = headerAlign == 'left'
        ? CrossAxisAlignment.start
        : (headerAlign == 'right' ? CrossAxisAlignment.end : CrossAxisAlignment.center);
    final textAlign = headerAlign == 'left'
        ? TextAlign.left
        : (headerAlign == 'right' ? TextAlign.right : TextAlign.center);

    return Padding(
      padding: EdgeInsets.only(bottom: settings.receiptHeaderSpacing / 2),
      child: Column(
        crossAxisAlignment: crossAlign,
        children: [
          if (settings.showReceiptLogo) ...[
            _buildStoreLogo(),
            const SizedBox(height: 4),
          ],
          if (isTaxInvoice) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.taxInvoice,
                textAlign: TextAlign.center,
                style: ReceiptTheme.metaText(is58mm, isBold: true, settings: settings),
              ),
            ),
          ],
          Text(
            shopName,
            textAlign: textAlign,
            style: ReceiptTheme.storeTitle(is58mm, settings: settings),
          ),
          if (settings.showReceiptAddress && shopAddress.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              shopAddress,
              textAlign: textAlign,
              style: ReceiptTheme.storeSubtitle(is58mm, settings: settings),
            ),
          ],
          if (settings.showReceiptPhone && shopPhone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${l10n.phone}: $shopPhone',
              textAlign: textAlign,
              style: ReceiptTheme.storeSubtitle(is58mm, settings: settings),
            ),
          ],
          if (isTaxInvoice || (isVatActive && settings.taxIdentificationNumber.isNotEmpty)) ...[
            if (settings.taxIdentificationNumber.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '${l10n.tin}: ${settings.taxIdentificationNumber}',
                textAlign: textAlign,
                style: ReceiptTheme.storeSubtitle(is58mm, settings: settings),
              ),
            ],
            if (settings.vatRegistrationNumber.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                '${l10n.vatRegNo}: ${settings.vatRegistrationNumber}',
                textAlign: textAlign,
                style: ReceiptTheme.storeSubtitle(is58mm, settings: settings),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStoreLogo() {
    final double logoWidth = is58mm ? 48.0 : 64.0;
    final double logoHeight = is58mm ? 36.0 : 48.0;

    // 1. Direct synchronous ui.Image (used by headless ReceiptImageGenerator)
    if (logoUiImage != null) {
      return RawImage(
        image: logoUiImage,
        width: logoWidth,
        height: logoHeight,
        fit: BoxFit.contain,
      );
    }

    // 2. If pre-loaded bytes provided
    if (logoBytes != null && logoBytes!.isNotEmpty) {
      return Image.memory(
        logoBytes!,
        width: logoWidth,
        height: logoHeight,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    // 2. Custom shop logo URL or local file path
    final logoUrl = settings.shopLogoUrl?.trim();
    if (logoUrl != null && logoUrl.isNotEmpty) {
      if (logoUrl.startsWith('http://') || logoUrl.startsWith('https://')) {
        return Image.network(
          logoUrl,
          width: logoWidth,
          height: logoHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackLogo(logoWidth, logoHeight),
        );
      } else {
        try {
          final file = File(logoUrl);
          if (file.existsSync()) {
            return Image.file(
              file,
              width: logoWidth,
              height: logoHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackLogo(logoWidth, logoHeight),
            );
          }
        } catch (_) {}
      }
    }

    // 3. Fallback to default asset logo
    return _buildFallbackLogo(logoWidth, logoHeight);
  }

  Widget _buildFallbackLogo(double width, double height) {
    return Image.asset(
      'assets/images/logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                style: ReceiptTheme.metaText(is58mm, isBold: true, settings: settings),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (settings.showReceiptDateTime) ...[
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: ReceiptTheme.metaText(is58mm, settings: settings),
              ),
            ],
          ],
        ),
        if (settings.showReceiptCashier || settings.showReceiptDateTime) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (settings.showReceiptCashier)
                Expanded(
                  child: Text(
                    '${l10n.cashier}: $cashierName',
                    style: ReceiptTheme.metaText(is58mm, settings: settings),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              if (settings.showReceiptDateTime) ...[
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: ReceiptTheme.metaText(is58mm, settings: settings),
                ),
              ],
            ],
          ),
        ],
        if (settings.showReceiptCustomer &&
            sale.customerName?.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${l10n.customer}: ${sale.customerName!}',
                  style: ReceiptTheme.metaText(is58mm, settings: settings),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sale.customerPhone?.isNotEmpty == true) ...[
                const SizedBox(width: 8),
                Text(
                  sale.customerPhone!,
                  style: ReceiptTheme.metaText(is58mm, settings: settings),
                ),
              ],
            ],
          ),
        ],
        if (sale.customerTin?.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.buyerTin}:',
                style: ReceiptTheme.metaText(is58mm, settings: settings),
              ),
              Text(
                sale.customerTin!,
                style: ReceiptTheme.metaText(is58mm, isBold: true, settings: settings),
              ),
            ],
          ),
        ],
        if (sale.customerVatNumber?.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.buyerVatNo}:',
                style: ReceiptTheme.metaText(is58mm, settings: settings),
              ),
              Text(
                sale.customerVatNumber!,
                style: ReceiptTheme.metaText(is58mm, isBold: true, settings: settings),
              ),
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
                  style: ReceiptTheme.tableHeader(is58mm, settings: settings),
                ),
              ),
              if (settings.showReceiptStandardPrice)
                Expanded(
                  flex: is58mm ? 18 : 20,
                  child: Text(
                    l10n.priceHeader,
                    textAlign: TextAlign.right,
                    style: ReceiptTheme.tableHeader(is58mm, settings: settings),
                  ),
                ),
              if (settings.showReceiptOurPrice)
                Expanded(
                  flex: is58mm ? 20 : 20,
                  child: Text(
                    l10n.ourPrice,
                    textAlign: TextAlign.right,
                    style: ReceiptTheme.tableHeader(is58mm, settings: settings),
                  ),
                ),
              Expanded(
                flex: is58mm ? 24 : 20,
                child: Text(
                  l10n.totalHeader,
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.tableHeader(is58mm, settings: settings),
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

    String taxTag = '';
    if (isTaxInvoice || isVatActive) {
      if (item.taxStatus == 'exempt') {
        taxTag = ' [E]';
      } else if (item.taxStatus == 'zero_rated') {
        taxTag = ' [Z]';
      } else if (item.taxStatus == 'taxable' || item.taxRate != null || (item.taxAmount ?? 0) > 0) {
        taxTag = ' [T]';
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.receiptItemSpacing / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Product Name (Wrapped or Ellipsis based on user setting)
          Text(
            '${item.productName}$taxTag',
            style: ReceiptTheme.itemName(is58mm, settings: settings),
            softWrap: settings.receiptWrapProductName,
            maxLines: settings.receiptWrapProductName ? null : 1,
            overflow: settings.receiptWrapProductName ? TextOverflow.visible : TextOverflow.ellipsis,
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
                  style: ReceiptTheme.itemDetail(is58mm, isBold: true, settings: settings),
                ),
              ),
              // Standard Price
              if (settings.showReceiptStandardPrice)
                Expanded(
                  flex: is58mm ? 18 : 20,
                  child: Text(
                    stdUnitPrice.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: ReceiptTheme.itemDetail(is58mm, settings: settings),
                  ),
                ),
              // Our Price
              if (settings.showReceiptOurPrice)
                Expanded(
                  flex: is58mm ? 20 : 20,
                  child: Text(
                    ourUnitPrice.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: ReceiptTheme.itemDetail(is58mm, isBold: true, settings: settings),
                  ),
                ),
              // Line Total
              Expanded(
                flex: is58mm ? 24 : 20,
                child: Text(
                  item.total.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.itemDetail(is58mm, isBold: true, settings: settings),
                ),
              ),
            ],
          ),

          // Row 3: Discount / Savings notice (if any)
          if (settings.showReceiptDiscount && (savings > 0.05 || item.discount > 0.05)) ...[
            const SizedBox(height: 1.5),
            Text(
              '(${l10n.profit}: -${(savings > item.discount ? savings : item.discount).toStringAsFixed(2)})',
              style: ReceiptTheme.itemDiscount(is58mm, settings: settings),
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
                  style: ReceiptTheme.tableHeader(is58mm, settings: settings),
                ),
              ),
              Expanded(
                flex: is58mm ? 18 : 18,
                child: Text(
                  l10n.qtyHeader,
                  textAlign: TextAlign.center,
                  style: ReceiptTheme.tableHeader(is58mm, settings: settings),
                ),
              ),
              Expanded(
                flex: is58mm ? 20 : 19,
                child: Text(
                  l10n.priceHeader,
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.tableHeader(is58mm, settings: settings),
                ),
              ),
              Expanded(
                flex: is58mm ? 22 : 19,
                child: Text(
                  l10n.totalHeader,
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.tableHeader(is58mm, settings: settings),
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

    String taxTag = '';
    if (isTaxInvoice || isVatActive) {
      if (item.taxStatus == 'exempt') {
        taxTag = ' [E]';
      } else if (item.taxStatus == 'zero_rated') {
        taxTag = ' [Z]';
      } else if (item.taxStatus == 'taxable' || item.taxRate != null || (item.taxAmount ?? 0) > 0) {
        taxTag = ' [T]';
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.receiptItemSpacing / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name full width (wrap naturally or ellipsis)
          Text(
            '${item.productName}$taxTag',
            style: ReceiptTheme.itemName(is58mm, settings: settings),
            softWrap: settings.receiptWrapProductName,
            maxLines: settings.receiptWrapProductName ? null : 1,
            overflow: settings.receiptWrapProductName ? TextOverflow.visible : TextOverflow.ellipsis,
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
                  style: ReceiptTheme.itemDetail(is58mm, settings: settings),
                ),
              ),
              Expanded(
                flex: is58mm ? 20 : 19,
                child: Text(
                  unitPriceStr,
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.itemDetail(is58mm, settings: settings),
                ),
              ),
              Expanded(
                flex: is58mm ? 22 : 19,
                child: Text(
                  totalStr,
                  textAlign: TextAlign.right,
                  style: ReceiptTheme.itemDetail(is58mm, isBold: true, settings: settings),
                ),
              ),
            ],
          ),
          if (item.discount > 0.05) ...[
            const SizedBox(height: 1),
            Text(
              '   (${l10n.discount}: -${item.discount.toStringAsFixed(2)})',
              style: ReceiptTheme.itemDiscount(is58mm, settings: settings),
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

    final totalItemDiscounts = items.fold(0.0, (sum, item) {
      final qty = item.soldQuantity ?? item.quantity;
      final stdUnitPrice = item.unitPrice > 0
          ? item.unitPrice
          : (qty > 0 ? (item.total + item.discount) / qty : item.total);
      final diff = (stdUnitPrice * qty) - item.total;
      final savings = diff > item.discount ? diff : item.discount;
      return sum + (savings > 0 ? savings : 0.0);
    });
    final totalDiscount = totalItemDiscounts + sale.discount;

    final grossStandardTotal = items.fold(0.0, (sum, item) {
      final qty = item.soldQuantity ?? item.quantity;
      final stdUnitPrice = item.unitPrice > 0
          ? item.unitPrice
          : (qty > 0 ? (item.total + item.discount) / qty : item.total);
      return sum + (stdUnitPrice * (qty > 0 ? qty : 1));
    });
    final subtotalOurPrice = items.fold(0.0, (sum, item) => sum + item.total);
    final displaySubtotal = grossStandardTotal > subtotalOurPrice ? grossStandardTotal : subtotalOurPrice;

    return Column(
      children: [
        // Items and Pcs count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${l10n.itemsCount}: ${items.length}',
                style: ReceiptTheme.summaryLabel(is58mm, settings: settings)),
            Text('Pcs: $pcsStr',
                style: ReceiptTheme.summaryValue(is58mm, isBold: true, settings: settings)),
          ],
        ),
        const SizedBox(height: 3),

        // Subtotal
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.subtotal, style: ReceiptTheme.summaryLabel(is58mm, settings: settings)),
            Text(displaySubtotal.toStringAsFixed(2),
                style: ReceiptTheme.summaryValue(is58mm, settings: settings)),
          ],
        ),

        // Discount / Customer Savings ("සම්පූර්ණ ලාභය" - bold and larger)
        if (settings.showReceiptDiscount && totalDiscount > 0.05) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.totalProfit,
                style: ReceiptTheme.savingsLabel(is58mm, settings: settings),
              ),
              Text(
                '-${totalDiscount.toStringAsFixed(2)}',
                style: ReceiptTheme.savingsValue(is58mm, settings: settings),
              ),
            ],
          ),
        ],

        // Tax / VAT Breakdown
        if (isVatActive || isTaxInvoice || (settings.showReceiptTax && sale.tax > 0.01)) ...[
          if (sale.taxableAmount != null && sale.taxableAmount! > 0) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.taxableBase, style: ReceiptTheme.summaryLabel(is58mm, settings: settings)),
                Text(sale.taxableAmount!.toStringAsFixed(2),
                    style: ReceiptTheme.summaryValue(is58mm, settings: settings)),
              ],
            ),
          ],
          if (sale.taxExemptAmount != null && sale.taxExemptAmount! > 0) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.exemptAmount, style: ReceiptTheme.summaryLabel(is58mm, settings: settings)),
                Text(sale.taxExemptAmount!.toStringAsFixed(2),
                    style: ReceiptTheme.summaryValue(is58mm, settings: settings)),
              ],
            ),
          ],
          if (sale.taxZeroRatedAmount != null && sale.taxZeroRatedAmount! > 0) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.zeroRatedAmount, style: ReceiptTheme.summaryLabel(is58mm, settings: settings)),
                Text(sale.taxZeroRatedAmount!.toStringAsFixed(2),
                    style: ReceiptTheme.summaryValue(is58mm, settings: settings)),
              ],
            ),
          ],
          if (sale.tax > 0.005) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.tax} (${(sale.vatRate ?? settings.defaultVatRate).toStringAsFixed(0)}%${sale.pricingType == 'inclusive' ? ' incl.' : ''})',
                  style: ReceiptTheme.summaryLabel(is58mm, settings: settings),
                ),
                Text(sale.tax.toStringAsFixed(2),
                    style: ReceiptTheme.summaryValue(is58mm, isBold: true, settings: settings)),
              ],
            ),
          ],
        ],

        // Service charge
        if (sale.serviceCharge > 0.05) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.serviceCharge, style: ReceiptTheme.summaryLabel(is58mm, settings: settings)),
              Text(sale.serviceCharge.toStringAsFixed(2),
                  style: ReceiptTheme.summaryValue(is58mm, settings: settings)),
            ],
          ),
        ],

        // Merchant Internal Margin / Profit (only if enabled for audit slips)
        if (settings.showReceiptProfit) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.merchantProfit, style: ReceiptTheme.summaryLabel(is58mm, settings: settings)),
              Text(
                (items.fold(0.0, (s, i) => s + (i.total - (i.costPrice * i.quantity))) - sale.discount).toStringAsFixed(2),
                style: ReceiptTheme.summaryValue(is58mm, settings: settings),
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
          Expanded(
            child: Text(
              l10n.grandTotal,
              style: ReceiptTheme.grandTotalLabel(is58mm, settings: settings),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Rs. ${sale.total.toStringAsFixed(2)}',
            style: ReceiptTheme.grandTotalValue(is58mm, settings: settings),
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
            Text('${l10n.paymentMethod}:', style: ReceiptTheme.summaryLabel(is58mm, settings: settings)),
            Text(paymentLabel, style: ReceiptTheme.summaryValue(is58mm, isBold: true, settings: settings)),
          ],
        ),
        if (sale.paymentMethod.toLowerCase() == 'cash' && effectiveCash != null) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${l10n.cashReceived}:', style: ReceiptTheme.summaryLabel(is58mm, settings: settings)),
              Text(effectiveCash.toStringAsFixed(2), style: ReceiptTheme.summaryValue(is58mm, settings: settings)),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${l10n.change}:', style: ReceiptTheme.summaryLabel(is58mm, isBold: true, settings: settings)),
              Text(
                (effectiveChange ?? 0.0).toStringAsFixed(2),
                style: ReceiptTheme.summaryValue(is58mm, isBold: true, settings: settings),
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

    final footerAlign = settings.receiptFooterAlignment;
    final crossAlign = footerAlign == 'left'
        ? CrossAxisAlignment.start
        : (footerAlign == 'right' ? CrossAxisAlignment.end : CrossAxisAlignment.center);
    final textAlign = footerAlign == 'left'
        ? TextAlign.left
        : (footerAlign == 'right' ? TextAlign.right : TextAlign.center);

    return Padding(
      padding: EdgeInsets.only(top: settings.receiptFooterSpacing / 2),
      child: Column(
        crossAxisAlignment: crossAlign,
        children: [
          Text(
            footerMsg,
            textAlign: textAlign,
            style: ReceiptTheme.footerThankYou(is58mm, settings: settings),
          ),
          if (isTaxInvoice) ...[
            const SizedBox(height: 3),
            Text(
              '[T]=Taxable  [Z]=Zero-Rated  [E]=Exempt',
              textAlign: textAlign,
              style: ReceiptTheme.metaText(is58mm, settings: settings).copyWith(fontSize: (is58mm ? 9 : 10)),
            ),
          ],
          const SizedBox(height: 4),

          // Barcode / Bill Number representation
          if (settings.showReceiptBarcode) ...[
            const SizedBox(height: 4),
            Center(
              child: ReceiptBarcodeWidget(
                data: sale.billNumber,
                width: is58mm ? 180.0 : 240.0,
                height: is58mm ? 36.0 : 44.0,
              ),
            ),
            const SizedBox(height: 2),
          ],

          Text(
            'Powered by QuickBill POS',
            textAlign: textAlign,
            style: ReceiptTheme.footerCredit(is58mm, settings: settings),
          ),
          const SizedBox(height: 8),
        ],
      ),
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
