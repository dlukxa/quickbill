import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/expense.dart';
import '../../providers/branch_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/preference_provider.dart';
import '../../providers/sale_provider.dart';
import '../../utils/pos_l10n.dart';
import '../../utils/region_utils.dart';
import '../../widgets/sinhala_transliteration_input.dart';

/// Professional desktop expense tracking & operating cost analytics view
class DesktopExpensesView extends ConsumerStatefulWidget {
  const DesktopExpensesView({super.key});

  @override
  ConsumerState<DesktopExpensesView> createState() => _DesktopExpensesViewState();
}

class _DesktopExpensesViewState extends ConsumerState<DesktopExpensesView> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  final _categories = [
    'All',
    'Rent',
    'Electricity',
    'Water',
    'Salary',
    'Transport',
    'Repairs',
    'Marketing',
    'Inventory Purchase',
    'General',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final settings = ref.watch(settingsProvider);
    final posL10n = PosL10n.of(settings.languageCode);

    final expenseListAsync = ref.watch(expenseListProvider);
    final todayStatsAsync = ref.watch(todayStatsProvider);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildHeader(cardBg, borderColor, isDark, posL10n),
          _buildMetricsBar(cardBg, borderColor, isDark, expenseListAsync.value ?? [], todayStatsAsync.value?['total_sales'] ?? 0.0, posL10n),
          _buildFilterBar(cardBg, borderColor, isDark, posL10n),
          Expanded(
            child: expenseListAsync.when(
              data: (expenses) {
                var list = expenses;

                // Category filter
                if (_selectedCategory != 'All') {
                  list = list.where((e) => e.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
                }

                // Search query
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  list = list.where((e) =>
                    e.category.toLowerCase().contains(q) ||
                    (e.note?.toLowerCase().contains(q) ?? false)
                  ).toList();
                }

                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 16),
                        Text(
                          'No expenses found',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return _buildExpensesTable(list, cardBg, borderColor, isDark);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color cardBg, Color borderColor, bool isDark, PosL10n posL10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_rounded, color: Colors.amber.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  posL10n.expensesAndOperatingCosts,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  posL10n.expensesSubtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddExpenseDialog(context),
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: Text(
              posL10n.recordExpense,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar(Color cardBg, Color borderColor, bool isDark, List<Expense> expenses, double todaySales, PosL10n posL10n) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    final todayExpenses = expenses.where((e) => !e.date.isBefore(todayStart)).fold<double>(0.0, (sum, e) => sum + e.amount);
    final monthExpenses = expenses.where((e) => !e.date.isBefore(monthStart)).fold<double>(0.0, (sum, e) => sum + e.amount);
    final netToday = todaySales - todayExpenses;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          _buildMetricCard(posL10n.todayExpenses, todayExpenses, Colors.orange, Icons.trending_down_rounded, cardBg, borderColor, isDark),
          const SizedBox(width: 16),
          _buildMetricCard(posL10n.thisMonthExpenses, monthExpenses, Colors.red, Icons.calendar_today_rounded, cardBg, borderColor, isDark),
          const SizedBox(width: 16),
          _buildMetricCard(posL10n.netProfit, netToday, netToday >= 0 ? AppTheme.primaryGreen : AppTheme.errorRed, Icons.savings_rounded, cardBg, borderColor, isDark),
          const SizedBox(width: 16),
          _buildMetricCard(posL10n.todaysRevenue, todaySales, AppTheme.primaryBlue, Icons.point_of_sale_rounded, cardBg, borderColor, isDark),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, double amount, Color color, IconData icon, Color cardBg, Color borderColor, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                Text(
                  '${globalAppRegion.currencySymbol} ${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(Color cardBg, Color borderColor, bool isDark, PosL10n posL10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: SinglishTextField(
                    controller: _searchCtrl,
                    showSuggestionBanner: false,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    onConverted: () => setState(() => _searchQuery = _searchCtrl.text),
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: posL10n.searchExpensesHint,
                      hintStyle: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : Colors.black38),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.amber.shade700 : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTable(List<Expense> expenses, Color cardBg, Color borderColor, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: borderColor),
          ),
          color: cardBg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Category Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(expense.category).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: _getCategoryColor(expense.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),

                // Category & Date
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.category,
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(expense.date),
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // Note / Memo
                Expanded(
                  flex: 4,
                  child: Text(
                    expense.note?.isNotEmpty == true ? expense.note! : 'No memo provided',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: expense.note?.isNotEmpty == true ? (isDark ? Colors.white70 : Colors.black87) : Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Amount
                SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Amount Disbursed',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                      Text(
                        '- ${globalAppRegion.currencySymbol} ${expense.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Delete Action
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  tooltip: 'Delete Expense',
                  onPressed: () => _confirmDeleteExpense(context, expense.id!),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'rent': return Colors.purple;
      case 'electricity': return Colors.amber.shade700;
      case 'water': return Colors.cyan;
      case 'salary': return Colors.blue;
      case 'transport': return Colors.teal;
      case 'repairs': return Colors.orange;
      case 'marketing': return Colors.pink;
      case 'inventory purchase': return Colors.indigo;
      default: return Colors.blueGrey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'rent': return Icons.home_work_rounded;
      case 'electricity': return Icons.bolt_rounded;
      case 'water': return Icons.water_drop_rounded;
      case 'salary': return Icons.badge_rounded;
      case 'transport': return Icons.local_shipping_rounded;
      case 'repairs': return Icons.build_rounded;
      case 'marketing': return Icons.campaign_rounded;
      case 'inventory purchase': return Icons.shopping_bag_rounded;
      default: return Icons.receipt_long_rounded;
    }
  }

  void _showAddExpenseDialog(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String category = 'General';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text('Log Operating Expense', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Expense Category', border: OutlineInputBorder()),
                  items: _categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) setSt(() => category = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Amount (${globalAppRegion.currencySymbol})',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                SinglishTextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Description / Payee Note',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) return;

                final currentEmp = ref.read(currentEmployeeProvider).value;
                final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;

                final expense = Expense(
                  branchId: branchId,
                  category: category,
                  amount: amount,
                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                  date: DateTime.now(),
                  employeeId: currentEmp?.id,
                );

                await ref.read(expenseListProvider.notifier).addExpense(expense);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
              child: const Text('Save Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense Record'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(expenseListProvider.notifier).deleteExpense(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
