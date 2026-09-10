import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../providers/preference_provider.dart';
import '../../providers/sale_provider.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../services/printing_service.dart';
import '../../utils/formatters.dart';
import '../returns/process_return_screen.dart';

class DesktopSalesView extends ConsumerStatefulWidget {
  const DesktopSalesView({super.key});

  @override
  ConsumerState<DesktopSalesView> createState() => _DesktopSalesViewState();
}

class _DesktopSalesViewState extends ConsumerState<DesktopSalesView> {
  String _datePreset = 'month'; // 'today', 'yesterday', 'week', 'month', 'all'
  String _paymentFilter = 'all'; // 'all', 'cash', 'card', 'credit'
  String _searchQuery = '';
  final _searchController = TextEditingController();

  Sale? _selectedSale;
  List<SaleItem> _selectedItems = [];
  bool _isLoadingItems = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectSale(Sale sale) async {
    setState(() {
      _selectedSale = sale;
      _isLoadingItems = true;
    });

    try {
      List<SaleItem> items = sale.items;
      if (items.isEmpty && sale.id != null) {
        items = await DatabaseService.instance.getSaleItems(sale.id!);
      }
      if (mounted) {
        setState(() {
          _selectedItems = items;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;
    final salesAsync = ref.watch(salesProvider);

    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Container(
      color: bg,
      child: salesAsync.when(
        data: (allSales) {
          final now = DateTime.now();

          // Filter by Date Preset
          List<Sale> filtered = allSales.where((s) {
            final d = s.createdAt;
            switch (_datePreset) {
              case 'today':
                return d.year == now.year && d.month == now.month && d.day == now.day;
              case 'yesterday':
                final y = now.subtract(const Duration(days: 1));
                return d.year == y.year && d.month == y.month && d.day == y.day;
              case 'week':
                final weekStart = now.subtract(Duration(days: now.weekday - 1));
                return d.isAfter(DateTime(weekStart.year, weekStart.month, weekStart.day));
              case 'month':
                return d.year == now.year && d.month == now.month;
              case 'all':
              default:
                return true;
            }
          }).toList();

          // Filter by Payment Method
          if (_paymentFilter != 'all') {
            filtered = filtered.where((s) => s.paymentMethod.toLowerCase() == _paymentFilter).toList();
          }

          // Filter by Search Query (Bill Number, Customer, Cashier)
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.trim().toLowerCase();
            filtered = filtered.where((s) {
              return s.billNumber.toLowerCase().contains(q) ||
                  (s.customerName?.toLowerCase().contains(q) ?? false) ||
                  (s.cashierName?.toLowerCase().contains(q) ?? false);
            }).toList();
          }

          // Auto-select first sale if current selection is invalid
          if (_selectedSale == null && filtered.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _selectSale(filtered.first);
            });
          }

          final totalRevenue = filtered.fold(0.0, (sum, s) => sum + s.total);
          final totalCount = filtered.length;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales History & Invoice Explorer',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Inspect past transactions, reprint thermal receipts, print A4 invoices, and issue returns',
                          style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '$totalCount Bills: ',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                          ),
                          Text(
                            Formatters.currency(totalRevenue),
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Filter Controls ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      // Search
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search bill #, customer, or cashier...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Date Preset
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _datePreset,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Time Period',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'today', child: Text('Today')),
                            DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
                            DropdownMenuItem(value: 'week', child: Text('This Week')),
                            DropdownMenuItem(value: 'month', child: Text('This Month')),
                            DropdownMenuItem(value: 'all', child: Text('All Time')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _datePreset = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Payment Method Filter
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(value: 'cash', label: Text('Cash')),
                          ButtonSegment(value: 'card', label: Text('Card')),
                          ButtonSegment(value: 'credit', label: Text('Credit')),
                        ],
                        selected: {_paymentFilter},
                        onSelectionChanged: (set) => setState(() => _paymentFilter = set.first),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Split View: Left Invoices List / Right Selected Details ──
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT: Invoices Table (flex 7)
                      Expanded(
                        flex: 7,
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.receipt_long_outlined, size: 48, color: textSecondary),
                                      const SizedBox(height: 10),
                                      Text('No invoices found for this selection', style: TextStyle(color: textSecondary)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => Divider(height: 1, color: border.withValues(alpha: 0.5)),
                                  itemBuilder: (context, idx) {
                                    final sale = filtered[idx];
                                    final isSelected = _selectedSale?.id == sale.id;

                                    return InkWell(
                                      onTap: () => _selectSale(sale),
                                      child: Container(
                                        color: isSelected
                                            ? (isDark ? AppTheme.primaryGreen.withValues(alpha: 0.15) : const Color(0xFFE8F5E9))
                                            : null,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            // Bill Number & Time
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    sale.billNumber,
                                                    style: GoogleFonts.inter(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13.5,
                                                      color: isSelected ? AppTheme.primaryGreen : textPrimary,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat('dd/MM/yyyy • HH:mm').format(sale.createdAt),
                                                    style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Customer & Cashier
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    sale.customerName?.isNotEmpty == true ? sale.customerName! : 'Walk-in',
                                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    'By: ${sale.cashierName ?? "Admin"}',
                                                    style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Payment Method Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _getPaymentBadgeColor(sale.paymentMethod).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                sale.paymentMethod.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _getPaymentBadgeColor(sale.paymentMethod),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),

                                            // Amount
                                            Text(
                                              Formatters.currency(sale.total),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: textPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(Icons.chevron_right_rounded, size: 18, color: textSecondary),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // RIGHT: Selected Invoice Detail & Actions (flex 5)
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: _selectedSale == null
                              ? Center(
                                  child: Text('Select an invoice to inspect details', style: TextStyle(color: textSecondary)),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Detail Header
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Bill #${_selectedSale!.billNumber}',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                                            ),
                                            Text(
                                              DateFormat('EEEE, dd MMM yyyy • HH:mm').format(_selectedSale!.createdAt),
                                              style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          Formatters.currency(_selectedSale!.total),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const Divider(),

                                    // Customer & Cashier info
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text('Customer: ${_selectedSale!.customerName ?? "Walk-in"}', style: TextStyle(fontSize: 12, color: textSecondary)),
                                        ),
                                        Expanded(
                                          child: Text('Cashier: ${_selectedSale!.cashierName ?? "Admin"}', style: TextStyle(fontSize: 12, color: textSecondary), textAlign: TextAlign.right),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Itemized Table
                                    Text('ITEMS PURCHASED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: _isLoadingItems
                                          ? const Center(child: CircularProgressIndicator())
                                          : _selectedItems.isEmpty
                                              ? Center(child: Text('No item details recorded', style: TextStyle(color: textSecondary)))
                                              : ListView.separated(
                                                  itemCount: _selectedItems.length,
                                                  separatorBuilder: (_, __) => Divider(height: 1, color: border.withValues(alpha: 0.4)),
                                                  itemBuilder: (context, i) {
                                                    final item = _selectedItems[i];
                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(item.productName, style: GoogleFonts.notoSansSinhala(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
                                                                Text(
                                                                  '${item.soldQuantity ?? item.quantity} x ${Formatters.number(item.unitPrice, decimalPlaces: 2)}',
                                                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Text(
                                                            Formatters.currency(item.total),
                                                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                    ),

                                    const Divider(),
                                    const SizedBox(height: 8),

                                    // Financial Summary
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Subtotal:', style: TextStyle(fontSize: 12, color: textSecondary)),
                                        Text(Formatters.currency(_selectedSale!.subtotal), style: TextStyle(fontSize: 12, color: textPrimary)),
                                      ],
                                    ),
                                    if (_selectedSale!.discount > 0) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Discount:', style: TextStyle(fontSize: 12, color: AppTheme.errorRed)),
                                          Text('-${Formatters.currency(_selectedSale!.discount)}', style: TextStyle(fontSize: 12, color: AppTheme.errorRed)),
                                        ],
                                      ),
                                    ],
                                    if (_selectedSale!.tax > 0) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Tax (VAT):', style: TextStyle(fontSize: 12, color: textSecondary)),
                                          Text(Formatters.currency(_selectedSale!.tax), style: TextStyle(fontSize: 12, color: textPrimary)),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 14),

                                    // Action Buttons: Thermal Print, A4 Invoice, Return
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryGreen,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: const Icon(Icons.print_rounded, size: 16),
                                          label: Text(settings.is58mm ? 'Print (58mm)' : 'Print (80mm)'),
                                          onPressed: () async {
                                            try {
                                              await PrintingService.instance.printReceiptUnified(
                                                _selectedSale!,
                                                _selectedItems,
                                                settings,
                                              );
                                            } catch (e) {
                                              debugPrint('Print error: $e');
                                            }
                                          },
                                        ),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                          label: const Text('Invoice (A4)'),
                                          onPressed: () async {
                                            try {
                                              await PdfService.instance.generateProfessionalInvoice(
                                                _selectedSale!,
                                                _selectedItems,
                                                settings: settings,
                                              );
                                            } catch (e) {
                                              debugPrint('A4 Invoice error: $e');
                                            }
                                          },
                                        ),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.errorRed,
                                            side: const BorderSide(color: AppTheme.errorRed),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: const Icon(Icons.assignment_return_rounded, size: 16),
                                          label: const Text('Return / Refund'),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ProcessReturnScreen(sale: _selectedSale!),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading sales: $e')),
      ),
    );
  }

  Color _getPaymentBadgeColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return AppTheme.primaryGreen;
      case 'card':
        return AppTheme.primaryBlue;
      case 'credit':
        return Colors.orange.shade800;
      default:
        return AppTheme.primaryPurple;
    }
  }
}
