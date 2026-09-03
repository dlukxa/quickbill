import 'package:flutter/material.dart';
import '../../models/scan_result.dart';
import '../../config/theme.dart';

class ScanResultToast extends StatelessWidget {
  final ScanResult result;

  const ScanResultToast({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    IconData icon;

    switch (result.status) {
      case ScanStatus.added:
        bgColor = AppTheme.primaryGreen;
        icon = Icons.check_circle;
        break;
      case ScanStatus.addedWithWarning:
        bgColor = AppTheme.warningOrange;
        icon = Icons.warning_amber;
        break;
      case ScanStatus.notFound:
        bgColor = AppTheme.primaryBlue;
        icon = Icons.search_off;
        break;
      case ScanStatus.expired:
      case ScanStatus.outOfStock:
        bgColor = AppTheme.errorRed;
        icon = Icons.error_outline;
        break;
      default:
        bgColor = Colors.grey;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              result.message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
