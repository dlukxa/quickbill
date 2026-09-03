enum AlertType { lowStock, expiring }

class InventoryAlert {
  final String id;
  final AlertType type;
  final String title;
  final String subtitle;
  final int productId;
  final int? batchId;
  final DateTime? date;

  InventoryAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.productId,
    this.batchId,
    this.date,
  });
}

