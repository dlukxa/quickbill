import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/branch.dart';
import '../../providers/branch_provider.dart';
import '../../config/theme.dart';
import '../../widgets/app_card.dart';

class BranchManagementScreen extends ConsumerWidget {
  const BranchManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchState = ref.watch(branchProvider);
    final branches = branchState.branches;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Management'),
      ),
      body: branchState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : branches.isEmpty
              ? _buildEmptyState(context, ref)
              : _buildBranchList(context, ref, branches),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBranchDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_tree_outlined, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'No Branches Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your business locations to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showBranchDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add First Branch'),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchList(BuildContext context, WidgetRef ref, List<Branch> branches) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: branches.length,
      itemBuilder: (context, index) {
        final branch = branches[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryBlue,
                child: Icon(Icons.store, color: Colors.white),
              ),
              title: Text(
                branch.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (branch.address != null && branch.address!.isNotEmpty)
                    Text(branch.address!),
                  if (branch.phone != null && branch.phone!.isNotEmpty)
                    Text(branch.phone!),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppTheme.primaryBlue),
                    onPressed: () => _showBranchDialog(context, ref, branch: branch),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.errorRed),
                    onPressed: () => _showDeleteConfirmation(context, ref, branch),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBranchDialog(BuildContext context, WidgetRef ref, {Branch? branch}) {
    final isEditing = branch != null;
    final nameController = TextEditingController(text: branch?.name);
    final addressController = TextEditingController(text: branch?.address);
    final phoneController = TextEditingController(text: branch?.phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Branch' : 'Add Branch'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Branch Name',
                  hintText: 'e.g. Main Street Branch',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              final newBranch = Branch(
                id: branch?.id,
                name: nameController.text,
                address: addressController.text,
                phone: phoneController.text,
                createdAt: branch?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );

              if (isEditing) {
                await ref.read(branchProvider.notifier).updateBranch(newBranch);
              } else {
                await ref.read(branchProvider.notifier).addBranch(newBranch);
              }

              if (context.mounted) Navigator.pop(context);
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Branch branch) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Branch?'),
        content: Text(
          'Are you sure you want to delete "${branch.name}"? '
          'This will NOT delete the sales/stock associated with this branch, '
          'but you will no longer be able to select it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              await ref.read(branchProvider.notifier).deleteBranch(branch.id!);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
