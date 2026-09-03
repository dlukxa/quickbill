import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import 'branch_provider.dart';

final expenseListProvider = StateNotifierProvider<ExpenseListNotifier, AsyncValue<List<Expense>>>((ref) {
  final branchId = ref.watch(currentBranchIdProvider);
  return ExpenseListNotifier(ref, branchId);
});

class ExpenseListNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final Ref ref;
  final int branchId;
  ExpenseListNotifier(this.ref, this.branchId) : super(const AsyncValue.loading()) {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    if (mounted) state = const AsyncValue.loading();
    try {
      final expenses = await DatabaseService.instance.getAllExpenses(branchId);
      if (mounted) state = AsyncValue.data(expenses);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> addExpense(Expense expense) async {
    try {
      final expenseWithBranch = expense.copyWith(branchId: branchId);
      await DatabaseService.instance.insertExpense(expenseWithBranch);
      await loadExpenses();
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateExpense(Expense expense) async {
    try {
      await DatabaseService.instance.updateExpense(expense);
      await loadExpenses();
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteExpense(int id) async {
    try {
      await DatabaseService.instance.deleteExpense(id);
      await loadExpenses();
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<double> getTotalExpensesForDateRange(DateTime start, DateTime end) async {
    final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
    final expenses = await DatabaseService.instance.getExpensesByDateRange(start, end, branchId);
    return expenses.fold<double>(0.0, (prev, e) => prev + e.amount);
  }
}
