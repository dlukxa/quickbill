import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_provider.dart';
import '../models/inventory_alert.dart';
import 'notification_service.dart';

class StockAlertService {
  static final StockAlertService instance = StockAlertService._();
  StockAlertService._();

  Future<void> checkAndNotify(Ref ref) async {
    final alertsAsync = ref.read(inventoryAlertsProvider);
    
    alertsAsync.whenData((alerts) {
      for (var alert in alerts) {
        // Only notify if it's a critical or warning alert
        NotificationService.instance.showNotification(
          id: alert.hashCode,
          title: alert.type == AlertType.expiring ? 'Product Expiring Soon!' : 'Low Stock Alert!',
          body: '${alert.title}: ${alert.subtitle}',
          payload: 'inventory_alert',
        );
      }
    });
  }
}
