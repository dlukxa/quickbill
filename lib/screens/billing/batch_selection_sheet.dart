import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../providers/product_provider.dart';
import '../../utils/formatters.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../generated/l10n/app_localizations_en.dart';

class BatchSelectionSheet extends ConsumerStatefulWidget {
  final Product product;

  const BatchSelectionSheet({super.key, required this.product});

  static Future<ProductBatch?> show(BuildContext context, Product product) {
    return showModalBottomSheet<ProductBatch>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BatchSelectionSheet(product: product),
    );
  }

  @override
  ConsumerState<BatchSelectionSheet> createState() => _BatchSelectionSheetState();
}

class _BatchSelectionSheetState extends ConsumerState<BatchSelectionSheet> {
  late Future<List<ProductBatch>> _batchesFuture;

  @override
  void initState() {
    super.initState();
    _batchesFuture = ref.read(databaseServiceProvider).getAvailableBatches(widget.product.id!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final isDark = context.isDark;

    final sheetBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = context.onSurface;
    final subColor = context.subText;
    final cardBg = isDark ? const Color(0xFF2D2D3F) : Colors.grey[50]!;
    final border = context.borderColor;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Batch',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.product.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF35354A) : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 18, color: isDark ? Colors.white70 : Colors.grey[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Batches List
          FutureBuilder<List<ProductBatch>>(
            future: _batchesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                );
              }
              
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      'Error loading batches: ${snapshot.error}',
                      style: const TextStyle(color: AppTheme.errorRed),
                    ),
                  ),
                );
              }

              final batches = snapshot.data ?? [];
              
              if (batches.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: subColor.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No active batches available with stock.',
                          style: GoogleFonts.plusJakartaSans(
                            color: subColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: batches.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final batch = batches[index];
                    final isExpired = batch.isExpired;
                    final expiresSoon = batch.expiresSoon;
                    
                    Color statusColor = AppTheme.primaryGreen;
                    String statusText = 'Active';
                    if (isExpired) {
                      statusColor = AppTheme.errorRed;
                      statusText = 'Expired';
                    } else if (expiresSoon) {
                      statusColor = Colors.orange;
                      statusText = 'Expires Soon';
                    }

                    return InkWell(
                      onTap: isExpired
                          ? () {
                              HapticFeedback.heavyImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cannot select an expired batch!'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                            }
                          : () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context, batch);
                            },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isExpired 
                                ? AppTheme.errorRed.withValues(alpha: 0.3) 
                                : border,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Icon container
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isExpired 
                                    ? AppTheme.errorRed 
                                    : expiresSoon 
                                        ? Colors.orange 
                                        : AppTheme.primaryGreen).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isExpired 
                                    ? Icons.error_outline_rounded 
                                    : Icons.layers_rounded,
                                color: isExpired 
                                    ? AppTheme.errorRed 
                                    : expiresSoon 
                                        ? Colors.orange 
                                        : AppTheme.primaryGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Batch: ${batch.batchNumber}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: isExpired ? AppTheme.errorRed : textColor,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    batch.expiryDate != null
                                        ? 'Expiry: ${Formatters.date(batch.expiryDate!)}'
                                        : 'No Expiry Date',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isExpired ? AppTheme.errorRed.withValues(alpha: 0.7) : subColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Stock quantity
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${Formatters.quantity(batch.stock)} ${widget.product.unit}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'In Stock',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
