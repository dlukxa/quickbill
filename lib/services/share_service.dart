import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../providers/preference_provider.dart';
import '../utils/formatters.dart';
import 'pdf_service.dart';

class ShareService {
  static final ShareService instance = ShareService._();
  ShareService._();

  String _generateBillText(Sale sale, List<SaleItem> items, AppSettings settings) {
    final buffer = StringBuffer();
    buffer.writeln('--- ${settings.shopName} ---');
    if (settings.shopAddress.isNotEmpty) buffer.writeln(settings.shopAddress);
    if (settings.shopPhone.isNotEmpty) buffer.writeln('Tel: ${settings.shopPhone}');
    buffer.writeln('---------------------------');
    buffer.writeln('Bill No: ${sale.billNumber}');
    buffer.writeln('Date: ${Formatters.dateTime(sale.createdAt)}');
    buffer.writeln('---------------------------');
    
    for (var item in items) {
      buffer.writeln(item.productName);
      final discInfo = item.discount > 0 ? ' (Disc: ${Formatters.currency(item.discount)})' : '';
      buffer.writeln('${Formatters.quantity(item.quantity)} x ${Formatters.currency(item.unitPrice)}$discInfo = ${Formatters.currency(item.total)}');
    }
    
    buffer.writeln('---------------------------');
    if (sale.discount > 0) {
      buffer.writeln('Bill Discount: ${Formatters.currency(sale.discount)}');
    }
    buffer.writeln('TOTAL: ${Formatters.currency(sale.total)}');
    buffer.writeln('---------------------------');
    if (settings.receiptFooter.isNotEmpty) {
      buffer.writeln(settings.receiptFooter);
    }
    return buffer.toString();
  }

  Future<void> shareViaWhatsApp(Sale sale, List<SaleItem> items, AppSettings settings, {String? phone}) async {
    final text = _generateBillText(sale, items, settings);
    
    // Since wa.me and WhatsApp Web URLs do not support direct file attachments,
    // we must use the native OS share sheet and let the user select WhatsApp.
    try {
      final doc = await PdfService.instance.buildReceiptDocument(sale, items, settings: settings);
      final bytes = await doc.save();
      final xFile = XFile.fromData(
        bytes,
        name: 'Receipt_${sale.billNumber}.pdf',
        mimeType: 'application/pdf',
      );
      await Share.shareXFiles(
        [xFile],
        text: text,
        subject: 'Receipt ${sale.billNumber}',
      );
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
    }
  }

  Future<void> shareViaSMS(Sale sale, List<SaleItem> items, AppSettings settings, {String? phone}) async {
    final text = Uri.encodeComponent(_generateBillText(sale, items, settings));
    
    String customerPhone = phone ?? sale.customerPhone ?? '';
    customerPhone = customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // For SMS, some platforms prefer ; or & for body, but ? is standard for single body
    final url = 'sms:$customerPhone?body=$text';
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
