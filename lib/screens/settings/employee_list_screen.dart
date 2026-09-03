import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/employee.dart';
import '../../providers/employee_provider.dart';
import '../../widgets/app_card.dart';
import '../auth/staff_login_handshake_dialog.dart';
import 'add_employee_screen.dart';

class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Employees'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEmployeeScreen()),
            ),
          ),
        ],
      ),
      body: employeesAsync.when(
        data: (employees) {
          if (employees.isEmpty) {
            return const Center(child: Text('No employees found'));
          }
          return ListView.builder(
            itemCount: employees.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final employee = employees[index];
              return AppCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: employee.rawRole == EmployeeRole.owner ? AppTheme.primaryBlue : AppTheme.primaryPurple,
                    child: Icon(
                      employee.rawRole == EmployeeRole.owner ? Icons.admin_panel_settings : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(employee.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Role: ${employee.rawRole.name.toUpperCase()}'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.vpn_key_outlined, size: 16),
                        label: const Text('Login Code', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          minimumSize: const Size(0, 32),
                          foregroundColor: AppTheme.primaryPurple,
                          side: const BorderSide(color: AppTheme.primaryPurple),
                        ),
                        onPressed: () => _showLoginQrDialog(context, ref, employee),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AddEmployeeScreen(employee: employee)),
                        ),
                      ),
                      if (employee.id != 1) // Prevent deleting primary owner
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _confirmDelete(context, ref, employee),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }



  void _confirmDelete(BuildContext context, WidgetRef ref, Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee?'),
        content: Text('Are you sure you want to remove ${employee.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(employeeListProvider.notifier).deleteEmployee(employee.id!);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showLoginQrDialog(BuildContext context, WidgetRef ref, Employee employee) {
    StaffLoginHandshakeDialog.show(context, employee);
  }
}
