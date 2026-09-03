import 'package:intl/intl.dart';
import 'region_utils.dart';

class Formatters {
  // Currency formatter
  static String currency(num amount) {
    return '${globalAppRegion.currencySymbol} ${number(amount, decimalPlaces: 2)}';
  }
  
  // Simple currency without decimals
  static String currencySimple(num amount) {
    return '${globalAppRegion.currencySymbol} ${number(amount, decimalPlaces: 0)}';
  }
  
  // Date formatter
  static String date(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }
  
  // Time formatter
  static String time(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }
  
  // Date and time formatter
  static String dateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
  }
  
  // Short date (for UI)
  static String shortDate(DateTime dateTime) {
    return DateFormat('dd/MM/yy').format(dateTime);
  }
  
  // Day name
  static String dayName(DateTime dateTime) {
    return DateFormat('EEEE').format(dateTime);
  }
  
  // Full display format
  static String fullDate(DateTime dateTime) {
    return DateFormat('EEEE, MMM dd, yyyy').format(dateTime);
  }
  
  // Number formatter
  static String number(num number, {int decimalPlaces = 0}) {
    final pattern = decimalPlaces > 0 
        ? '#,##0.${'0' * decimalPlaces}' 
        : '#,##0';
    final formatter = NumberFormat(pattern, 'en_US');
    return formatter.format(number);
  }

  // Quantity formatter (smartly handles decimals)
  static String quantity(num quantity) {
    if (quantity == quantity.toInt()) {
      return number(quantity, decimalPlaces: 0);
    }
    return number(quantity, decimalPlaces: 2);
  }
  
  // Percentage formatter
  static String percentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }
  
  // Compact number (e.g., 1.5K, 2.3M)
  static String compactNumber(num number) {
    return NumberFormat.compact().format(number);
  }
}
