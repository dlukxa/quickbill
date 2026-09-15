import 'sale_item.dart';

class Sale {
  final int? id;
  final String billNumber;
  final double total;
  final double discount;
  final double tax;
  final double serviceCharge; // NEW
  final double taxableAmount;
  final double taxExemptAmount;
  final double taxZeroRatedAmount;
  final bool isVatEnabled;
  final double vatRate;
  final String pricingType; // 'inclusive' or 'exclusive'
  final String invoiceType; // 'normal' or 'tax_invoice'
  final String? customerTin;
  final String? customerVatNumber;
  final int itemsCount;
  final String paymentMethod;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? notes;
  final DateTime createdAt;
  final bool synced;
  final bool deleted;
  final int? employeeId;
  final String? cashierName;
  final int branchId;
  final int? appointmentId;
  final int? customOrderId;
  final List<SaleItem> items;

  Sale({
    this.id,
    required this.billNumber,
    required this.total,
    this.discount = 0,
    this.tax = 0,
    this.serviceCharge = 0,
    this.taxableAmount = 0.0,
    this.taxExemptAmount = 0.0,
    this.taxZeroRatedAmount = 0.0,
    this.isVatEnabled = false,
    this.vatRate = 0.0,
    this.pricingType = 'inclusive',
    this.invoiceType = 'normal',
    this.customerTin,
    this.customerVatNumber,
    required this.itemsCount,
    this.paymentMethod = 'cash',
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.notes,
    DateTime? createdAt,
    this.synced = false,
    this.deleted = false,
    this.employeeId,
    this.cashierName,
    this.branchId = 1,
    this.appointmentId,
    this.customOrderId,
    this.items = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  // Calculate subtotal (before discount, tax, and service charge)
  double get subtotal => total + discount - tax - serviceCharge;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_number': billNumber,
      'total': total,
      'discount': discount,
      'tax': tax,
      'service_charge': serviceCharge,
      'taxable_amount': taxableAmount,
      'tax_exempt_amount': taxExemptAmount,
      'tax_zero_rated_amount': taxZeroRatedAmount,
      'is_vat_enabled': isVatEnabled ? 1 : 0,
      'vat_rate': vatRate,
      'pricing_type': pricingType,
      'invoice_type': invoiceType,
      'customer_tin': customerTin,
      'customer_vat_number': customerVatNumber,
      'items_count': itemsCount,
      'payment_method': paymentMethod,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'notes': notes,
      'employee_id': employeeId,
      'cashier_name': cashierName,
      'branch_id': branchId,
      'appointment_id': appointmentId,
      'custom_order_id': customOrderId,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as int?,
      billNumber: map['bill_number'] as String? ?? 'UNKNOWN',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      serviceCharge: (map['service_charge'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (map['taxable_amount'] as num?)?.toDouble() ?? 0.0,
      taxExemptAmount: (map['tax_exempt_amount'] as num?)?.toDouble() ?? 0.0,
      taxZeroRatedAmount: (map['tax_zero_rated_amount'] as num?)?.toDouble() ?? 0.0,
      isVatEnabled: (map['is_vat_enabled'] as int? ?? 0) == 1,
      vatRate: (map['vat_rate'] as num?)?.toDouble() ?? 0.0,
      pricingType: map['pricing_type'] as String? ?? 'inclusive',
      invoiceType: map['invoice_type'] as String? ?? 'normal',
      customerTin: map['customer_tin'] as String?,
      customerVatNumber: map['customer_vat_number'] as String?,
      itemsCount: map['items_count'] as int? ?? 0,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      synced: (map['synced'] as int? ?? 0) == 1,
      deleted: (map['deleted'] as int? ?? 0) == 1,
      employeeId: map['employee_id'] as int?,
      cashierName: map['cashier_name'] as String?,
      branchId: map['branch_id'] as int? ?? 1,
      appointmentId: map['appointment_id'] as int?,
      customOrderId: map['custom_order_id'] as int?,
      items: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...toMap(),
      'cashier_name': cashierName,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  Sale copyWith({
    int? id,
    String? billNumber,
    double? total,
    double? discount,
    double? tax,
    double? serviceCharge,
    double? taxableAmount,
    double? taxExemptAmount,
    double? taxZeroRatedAmount,
    bool? isVatEnabled,
    double? vatRate,
    String? pricingType,
    String? invoiceType,
    String? customerTin,
    String? customerVatNumber,
    int? itemsCount,
    String? paymentMethod,
    int? customerId,
    String? customerName,
    String? customerPhone,
    String? notes,
    bool? synced,
    bool? deleted,
    int? employeeId,
    String? cashierName,
    int? branchId,
    int? appointmentId,
    int? customOrderId,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      total: total ?? this.total,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      taxExemptAmount: taxExemptAmount ?? this.taxExemptAmount,
      taxZeroRatedAmount: taxZeroRatedAmount ?? this.taxZeroRatedAmount,
      isVatEnabled: isVatEnabled ?? this.isVatEnabled,
      vatRate: vatRate ?? this.vatRate,
      pricingType: pricingType ?? this.pricingType,
      invoiceType: invoiceType ?? this.invoiceType,
      customerTin: customerTin ?? this.customerTin,
      customerVatNumber: customerVatNumber ?? this.customerVatNumber,
      itemsCount: itemsCount ?? this.itemsCount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
      employeeId: employeeId ?? this.employeeId,
      cashierName: cashierName ?? this.cashierName,
      branchId: branchId ?? this.branchId,
      appointmentId: appointmentId ?? this.appointmentId,
      customOrderId: customOrderId ?? this.customOrderId,
      items: items ?? this.items,
    );
  }
}
