class CustomerPayment {
  final int? id;
  final int customerId;
  final double amount;
  final DateTime paymentDate;
  final String? note;
  final int synced;

  CustomerPayment({
    this.id,
    required this.customerId,
    required this.amount,
    required this.paymentDate,
    this.note,
    this.synced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'note': note,
      'synced': synced,
    };
  }

  factory CustomerPayment.fromMap(Map<String, dynamic> map) {
    return CustomerPayment(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int? ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: DateTime.parse(map['payment_date'] as String? ?? DateTime.now().toIso8601String()),
      note: map['note'] as String?,
      synced: map['synced'] as int? ?? 0,
    );
  }

  CustomerPayment copyWith({
    int? id,
    int? customerId,
    double? amount,
    DateTime? paymentDate,
    String? note,
    int? synced,
  }) {
    return CustomerPayment(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      note: note ?? this.note,
      synced: synced ?? this.synced,
    );
  }
}
