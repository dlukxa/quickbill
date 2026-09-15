import 'dart:math' as math;

/// Breakdown for an individual line item in cart / invoice.
class TaxItemBreakdown {
  final int? productId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double itemDiscount;
  final double billDiscountShare;
  final double netAmount;
  final String taxStatus; // 'taxable', 'zero_rated', 'exempt'
  final double taxRate; // e.g. 18.0, 0.0
  final double taxableAmount; // Net value subject to tax
  final double exemptAmount; // Value exempt from tax
  final double zeroRatedAmount; // Value zero-rated
  final double taxAmount; // VAT amount for this line
  final double lineTotal; // Final payable for this line

  const TaxItemBreakdown({
    this.productId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.itemDiscount,
    required this.billDiscountShare,
    required this.netAmount,
    required this.taxStatus,
    required this.taxRate,
    required this.taxableAmount,
    required this.exemptAmount,
    required this.zeroRatedAmount,
    required this.taxAmount,
    required this.lineTotal,
  });
}

/// Overall invoice tax and total breakdown.
class TaxBreakdown {
  final double grossSubtotal; // Undiscounted shelf total
  final double itemDiscountTotal; // Sum of item discounts
  final double billDiscount; // Bill-level discount
  final double totalDiscount; // item discounts + bill discount
  final double taxableAmount; // Total net taxable base
  final double exemptAmount; // Total exempt supply value
  final double zeroRatedAmount; // Total zero-rated supply value
  final double totalVat; // Total output VAT collected
  final double grandTotal; // Final amount payable
  final double defaultRate; // Base default VAT rate (e.g. 18.0)
  final bool isVatEnabled;
  final String pricingType; // 'inclusive' or 'exclusive'
  final List<TaxItemBreakdown> items;

  const TaxBreakdown({
    required this.grossSubtotal,
    required this.itemDiscountTotal,
    required this.billDiscount,
    required this.totalDiscount,
    required this.taxableAmount,
    required this.exemptAmount,
    required this.zeroRatedAmount,
    required this.totalVat,
    required this.grandTotal,
    required this.defaultRate,
    required this.isVatEnabled,
    required this.pricingType,
    required this.items,
  });

  /// Subtotal before tax for display.
  /// For VAT-Inclusive: equals (taxableAmount + exemptAmount + zeroRatedAmount) or grossSubtotal - totalDiscount.
  /// For VAT-Exclusive: equals (taxableAmount + exemptAmount + zeroRatedAmount).
  double get netSubtotal => (taxableAmount + exemptAmount + zeroRatedAmount * 100).round() / 100;
  double get subtotal => grossSubtotal;

  /// Returns a map of taxRate -> total tax amount collected for that rate.
  Map<double, double> get vatByRate {
    final map = <double, double>{};
    for (final item in items) {
      if (item.taxAmount > 0) {
        final current = map[item.taxRate] ?? 0.0;
        map[item.taxRate] = TaxCalculator.round2(current + item.taxAmount);
      }
    }
    return map;
  }
}

/// Input model for TaxCalculator.
class TaxInputItem {
  final int? productId;
  final String name;
  final double quantity;
  final double unitPrice;
  final double itemDiscount;
  final String? taxStatus; // 'taxable', 'zero_rated', 'exempt', null = exempt (VAT opt-in model)
  final double? customTaxRate;

  const TaxInputItem({
    this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.itemDiscount = 0.0,
    this.taxStatus, // null means not opted-in to VAT (treated as exempt)
    this.customTaxRate,
  });
}

/// Pure calculation engine for VAT and Invoice totals.
class TaxCalculator {
  /// Rounds value to 2 decimal places to guarantee financial precision.
  static double round2(double val) {
    return (val * 100).round() / 100.0;
  }

  /// Calculates complete VAT breakdown for a list of items.
  static TaxBreakdown calculate({
    required List<TaxInputItem> items,
    required bool isVatEnabled,
    required double defaultVatRate,
    required String pricingType, // 'inclusive' or 'exclusive'
    double billDiscount = 0.0,
  }) {
    if (items.isEmpty) {
      return TaxBreakdown(
        grossSubtotal: 0.0,
        itemDiscountTotal: 0.0,
        billDiscount: 0.0,
        totalDiscount: 0.0,
        taxableAmount: 0.0,
        exemptAmount: 0.0,
        zeroRatedAmount: 0.0,
        totalVat: 0.0,
        grandTotal: 0.0,
        defaultRate: defaultVatRate,
        isVatEnabled: isVatEnabled,
        pricingType: pricingType,
        items: const [],
      );
    }

    double totalGross = 0.0;
    double totalItemDiscount = 0.0;

    // First pass: compute gross and item discounts
    final List<double> itemGrossList = [];
    for (final item in items) {
      final gross = round2(item.unitPrice * item.quantity);
      final disc = math.min(gross, round2(item.itemDiscount));
      itemGrossList.add(math.max(0.0, gross - disc));
      totalGross += gross;
      totalItemDiscount += disc;
    }

    final effectiveSubtotalAfterItemDisc = totalGross - totalItemDiscount;
    final effectiveBillDiscount = math.min(
      math.max(0.0, billDiscount),
      effectiveSubtotalAfterItemDisc,
    );

    final List<TaxItemBreakdown> lineBreakdowns = [];
    double sumTaxable = 0.0;
    double sumExempt = 0.0;
    double sumZeroRated = 0.0;
    double sumVat = 0.0;
    double sumLineTotal = 0.0;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final rawGross = round2(item.unitPrice * item.quantity);
      final itemDisc = math.min(rawGross, round2(item.itemDiscount));
      final afterItemDisc = itemGrossList[i];

      // Apportion bill discount proportionally
      double billDiscShare = 0.0;
      if (effectiveSubtotalAfterItemDisc > 0 && effectiveBillDiscount > 0) {
        billDiscShare = round2((afterItemDisc / effectiveSubtotalAfterItemDisc) * effectiveBillDiscount);
      }
      final netAmount = math.max(0.0, round2(afterItemDisc - billDiscShare));

      if (!isVatEnabled) {
        // VAT Disabled: Standard non-VAT retail pricing
        final lineTotal = netAmount;
        lineBreakdowns.add(TaxItemBreakdown(
          productId: item.productId,
          itemName: item.name,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          itemDiscount: itemDisc,
          billDiscountShare: billDiscShare,
          netAmount: netAmount,
          taxStatus: item.taxStatus ?? 'exempt',
          taxRate: 0.0,
          taxableAmount: 0.0,
          exemptAmount: 0.0,
          zeroRatedAmount: 0.0,
          taxAmount: 0.0,
          lineTotal: lineTotal,
        ));
        sumLineTotal += lineTotal;
        continue;
      }

      // VAT Enabled: check item tax status (null = not opted in = treated as exempt)
      final status = (item.taxStatus ?? 'exempt').toLowerCase().trim();

      if (status == 'exempt') {
        // Exempt: No VAT charged, excluded from taxable base
        final lineTotal = netAmount;
        lineBreakdowns.add(TaxItemBreakdown(
          productId: item.productId,
          itemName: item.name,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          itemDiscount: itemDisc,
          billDiscountShare: billDiscShare,
          netAmount: netAmount,
          taxStatus: 'exempt',
          taxRate: 0.0,
          taxableAmount: 0.0,
          exemptAmount: netAmount,
          zeroRatedAmount: 0.0,
          taxAmount: 0.0,
          lineTotal: lineTotal,
        ));
        sumExempt += netAmount;
        sumLineTotal += lineTotal;
      } else if (status == 'zero_rated') {
        // Zero-Rated: 0% tax, reported separately as zero-rated supplies
        final lineTotal = netAmount;
        lineBreakdowns.add(TaxItemBreakdown(
          productId: item.productId,
          itemName: item.name,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          itemDiscount: itemDisc,
          billDiscountShare: billDiscShare,
          netAmount: netAmount,
          taxStatus: 'zero_rated',
          taxRate: 0.0,
          taxableAmount: 0.0,
          exemptAmount: 0.0,
          zeroRatedAmount: netAmount,
          taxAmount: 0.0,
          lineTotal: lineTotal,
        ));
        sumZeroRated += netAmount;
        sumLineTotal += lineTotal;
      } else {
        // Taxable (Standard or Custom Rate)
        final effectiveRate = item.customTaxRate ?? defaultVatRate;

        if (pricingType == 'exclusive') {
          // VAT-Exclusive: price is base value, VAT added on top
          final taxable = netAmount;
          final vat = round2(taxable * (effectiveRate / 100.0));
          final lineTotal = round2(taxable + vat);

          lineBreakdowns.add(TaxItemBreakdown(
            productId: item.productId,
            itemName: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            itemDiscount: itemDisc,
            billDiscountShare: billDiscShare,
            netAmount: netAmount,
            taxStatus: 'taxable',
            taxRate: effectiveRate,
            taxableAmount: taxable,
            exemptAmount: 0.0,
            zeroRatedAmount: 0.0,
            taxAmount: vat,
            lineTotal: lineTotal,
          ));
          sumTaxable += taxable;
          sumVat += vat;
          sumLineTotal += lineTotal;
        } else {
          // VAT-Inclusive: price already includes VAT (Standard Sri Lanka retail)
          // Base = netAmount / (1 + rate / 100)
          // VAT = netAmount - Base
          final rateFactor = 1.0 + (effectiveRate / 100.0);
          final taxable = round2(netAmount / rateFactor);
          final vat = round2(netAmount - taxable);
          final lineTotal = netAmount;

          lineBreakdowns.add(TaxItemBreakdown(
            productId: item.productId,
            itemName: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            itemDiscount: itemDisc,
            billDiscountShare: billDiscShare,
            netAmount: netAmount,
            taxStatus: 'taxable',
            taxRate: effectiveRate,
            taxableAmount: taxable,
            exemptAmount: 0.0,
            zeroRatedAmount: 0.0,
            taxAmount: vat,
            lineTotal: lineTotal,
          ));
          sumTaxable += taxable;
          sumVat += vat;
          sumLineTotal += lineTotal;
        }
      }
    }

    final finalGrandTotal = round2(sumLineTotal);

    return TaxBreakdown(
      grossSubtotal: round2(totalGross),
      itemDiscountTotal: round2(totalItemDiscount),
      billDiscount: round2(effectiveBillDiscount),
      totalDiscount: round2(totalItemDiscount + effectiveBillDiscount),
      taxableAmount: round2(sumTaxable),
      exemptAmount: round2(sumExempt),
      zeroRatedAmount: round2(sumZeroRated),
      totalVat: round2(sumVat),
      grandTotal: finalGrandTotal,
      defaultRate: defaultVatRate,
      isVatEnabled: isVatEnabled,
      pricingType: pricingType,
      items: lineBreakdowns,
    );
  }
}
