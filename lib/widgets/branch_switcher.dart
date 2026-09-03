import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/branch_provider.dart';
import '../config/theme.dart';
import '../generated/l10n/app_localizations.dart';
import '../providers/employee_provider.dart';
import '../models/employee.dart';

class BranchSwitcher extends ConsumerWidget {
  const BranchSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchState = ref.watch(branchProvider);
    final selectedBranch = branchState.selectedBranch;
    final branches = branchState.branches;
    final currentEmployee = ref.watch(currentEmployeeProvider).value;
    final isStaff = currentEmployee != null && currentEmployee.role != EmployeeRole.owner;

    if (branches.isEmpty) return const SizedBox.shrink();

    final buttonContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.store,
            size: 16,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(width: 8),
          Text(
            selectedBranch?.name ?? AppLocalizations.of(context)!.selectBranch,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
          if (!isStaff) ...[
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: AppTheme.primaryBlue,
            ),
          ],
        ],
      ),
    );

    if (isStaff) {
      return buttonContent;
    }

    return PopupMenuButton<int>(
      initialValue: selectedBranch?.id,
      onSelected: (int branchId) {
        final branch = branches.firstWhere((b) => b.id == branchId);
        ref.read(branchProvider.notifier).selectBranch(branch);
      },
      itemBuilder: (BuildContext context) {
        return branches.map((branch) {
          final isSelected = selectedBranch?.id == branch.id;
          return PopupMenuItem<int>(
            value: branch.id,
            child: Row(
              children: [
                Icon(
                  Icons.store,
                  size: 20,
                  color: isSelected ? AppTheme.primaryBlue : context.subText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    branch.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryBlue : context.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppTheme.primaryBlue,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: buttonContent,
    );
  }
}
