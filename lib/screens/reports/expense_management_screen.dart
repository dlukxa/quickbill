import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../providers/expense_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/sale_provider.dart';
import '../../models/expense.dart';
import '../../utils/formatters.dart';
import '../../utils/region_utils.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';

String getLocalizedExpenseCategory(BuildContext context, String category) {
  final l10n = AppLocalizations.of(context)!;
  switch (category.toLowerCase()) {
    case 'rent': return l10n.expRent;
    case 'electricity': return l10n.expElectricity;
    case 'water': return l10n.expWater;
    case 'salary': return l10n.expSalary;
    case 'transport': return l10n.expTransport;
    case 'repairs': return l10n.expRepairs;
    case 'marketing': return l10n.expMarketing;
    case 'inventory purchase': return l10n.expInventoryPurchase;
    case 'general': return l10n.expGeneral;
    default: return category;
  }
}

class ExpenseManagementScreen extends ConsumerWidget {
  const ExpenseManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseListAsync = ref.watch(expenseListProvider);
    final todayStatsAsync = ref.watch(todayStatsProvider);
    final l10n = AppLocalizations.of(context)!;
 
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenseManagement),
      ),
      body: Column(
        children: [
          // Profit/Loss Summary Card
          _ProfitLossSummary(
            totalSales: todayStatsAsync.value?['total_sales'] ?? 0.0,
            expenseListAsync: expenseListAsync,
          ),
          
          Expanded(
            child: expenseListAsync.when(
              data: (expenses) => expenses.isEmpty
                  ? Center(child: Text(l10n.noExpensesRecorded))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        return AnimateIn(
                          delay: Duration(milliseconds: 50 * index),
                          child: _ExpenseItem(expense: expense),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context, ref),
        label: Text(l10n.logExpense),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedCategory = 'General';
    final categories = ['Rent', 'Electricity', 'Water', 'Salary', 'Transport', 'Repairs', 'Marketing', 'Inventory Purchase', 'General'];
 
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logNewExpense),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(labelText: l10n.category),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(getLocalizedExpenseCategory(context, c)))).toList(),
                  onChanged: (val) => selectedCategory = val!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: l10n.amount,
                    prefixText: '${globalAppRegion.currencySymbol} ',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || val.isEmpty ? l10n.required : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: l10n.noteOptional,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final expense = Expense(
                  category: selectedCategory,
                  amount: double.parse(amountController.text),
                  note: noteController.text,
                  date: DateTime.now(),
                );
                await ref.read(expenseListProvider.notifier).addExpense(expense);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(l10n.saveExpense),
          ),
        ],
      ),
    );
  }
}

class _ProfitLossSummary extends StatelessWidget {
  final double totalSales;
  final AsyncValue<List<Expense>> expenseListAsync;

  const _ProfitLossSummary({
    required this.totalSales,
    required this.expenseListAsync,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalExpenses = expenseListAsync.value?.fold<double>(0.0, (sum, e) => sum + e.amount) ?? 0.0;
    final netProfit = totalSales - totalExpenses;
 
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          _SummaryItem(
            label: l10n.todaySales,
            value: totalSales,
            color: AppTheme.primaryGreen,
          ),
          const VerticalDivider(),
          _SummaryItem(
            label: l10n.expenses,
            value: totalExpenses,
            color: AppTheme.errorRed,
          ),
          const VerticalDivider(),
          _SummaryItem(
            label: l10n.netProfit,
            value: netProfit,
            color: netProfit >= 0 ? AppTheme.primaryBlue : AppTheme.errorRed,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool bold;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(
            Formatters.currency(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseItem extends ConsumerWidget {
  final Expense expense;
  const _ExpenseItem({required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.errorRed.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.outbound, color: AppTheme.errorRed),
        ),
        title: Text(getLocalizedExpenseCategory(context, expense.category), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${Formatters.date(expense.date)}\n${expense.note ?? ""}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.currency(expense.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.errorRed,
                fontSize: 16,
              ),
            ),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.deleteExpenseQuery),
                    content: Text(l10n.deleteExpenseConfirm),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
                      TextButton(
                        onPressed: () {
                          ref.read(expenseListProvider.notifier).deleteExpense(expense.id!);
                          Navigator.pop(context);
                        },
                        child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
