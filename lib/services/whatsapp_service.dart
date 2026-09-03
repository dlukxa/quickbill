import 'package:url_launcher/url_launcher.dart';
import '../models/sale_item.dart';
import '../utils/formatters.dart';

class WhatsAppService {
  static Future<void> sendReceipt({
    required String phone,
    required String shopName,
    required String billNumber,
    required double total,
    required List<SaleItem> items,
  }) async {
    // Format the items list
    String itemsText = items.map((item) {
      return "${item.productName} x ${item.quantity.toStringAsFixed(0)} = ${Formatters.currency(item.total)}";
    }).join("\n");

    // Clean phone number (remove +, spaces, etc.)
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Format the message
    final message = "*$shopName - Digital Receipt*\n"
        "--------------------------\n"
        "Bill No: $billNumber\n"
        "Date: ${Formatters.date(DateTime.now())}\n"
        "--------------------------\n"
        "$itemsText\n"
        "--------------------------\n"
        "*Total: ${Formatters.currency(total)}*\n\n"
        "Thank you for shopping with us!";

    final encodedMessage = Uri.encodeComponent(message);
    final url = "https://wa.me/$cleanPhone?text=$encodedMessage";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch WhatsApp';
    }
  }
}
