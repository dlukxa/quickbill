import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/employee.dart';
import '../../providers/employee_provider.dart';
import '../../providers/branch_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animate_in.dart';

class AddEmployeeScreen extends ConsumerStatefulWidget {
  final Employee? employee;
  const AddEmployeeScreen({super.key, this.employee});

  @override
  ConsumerState<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends ConsumerState<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _discountController;
  late String _role;
  late int _branchId;
  late bool _canGiveDiscount;
  late bool _canDeleteBill;
  late bool _canViewReports;
  late bool _canManageInventory;
  late bool _canManageEmployees;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _nameController = TextEditingController(text: emp?.name ?? '');
    _discountController = TextEditingController(
      text: (emp?.rawPermissions.maxDiscountPercent ?? 5.0).toString(),
    );
    _role = emp?.rawRole.name ?? 'staff';
    _branchId = emp?.branchId ?? ref.read(branchProvider).selectedBranch?.id ?? 1;
    
    _canGiveDiscount = emp?.rawPermissions.canGiveDiscount ?? true;
    _canDeleteBill = emp?.rawPermissions.canDeleteBill ?? false;
    _canViewReports = emp?.rawPermissions.canViewReports ?? false;
    _canManageInventory = emp?.rawPermissions.canManageInventory ?? false;
    _canManageEmployees = emp?.rawPermissions.canManageEmployees ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final newPermissions = EmployeePermissions(
        canGiveDiscount: _canGiveDiscount,
        canDeleteBill: _canDeleteBill,
        canViewReports: _canViewReports,
        canManageInventory: _canManageInventory,
        canManageEmployees: _canManageEmployees,
        maxDiscountPercent: double.tryParse(_discountController.text) ?? 5.0,
      );

      if (widget.employee == null) {
        final newEmployee = Employee(
          name: _nameController.text.trim(),
          pin: Employee.hashPin('0000'), // Default PIN, in a real app would prompt
          branchId: _branchId,
          role: EmployeeRole.values.firstWhere((e) => e.name == _role, orElse: () => EmployeeRole.staff),
          permissions: newPermissions,
          status: EmployeeStatus.active,
        );
        await ref.read(employeeListProvider.notifier).addEmployee(newEmployee);
      } else {
        final updatedEmployee = widget.employee!.copyWith(
          name: _nameController.text.trim(),
          branchId: _branchId,
          role: EmployeeRole.values.firstWhere((e) => e.name == _role, orElse: () => EmployeeRole.staff),
          permissions: newPermissions,
          updatedAt: DateTime.now(),
        );
        await ref.read(employeeListProvider.notifier).updateEmployee(updatedEmployee);
      }
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.employee == null ? 'Employee added successfully' : 'Employee updated successfully'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employee != null;
    final branchState = ref.watch(branchProvider);
    final branches = branchState.branches;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Employee' : 'Add New Employee',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimateIn(
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basic Information',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.plusJakartaSans(),
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Enter employee full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a name' : null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _role,
                        style: GoogleFonts.plusJakartaSans(color: context.onSurface),
                        decoration: const InputDecoration(
                          labelText: 'Position / Role',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'owner', child: Text('Owner (Full Access)')),
                          DropdownMenuItem(value: 'staff', child: Text('Staff (Sales & POS)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _role = val);
                        },
                      ),
                      if (branches.length > 1) ...[
                        const SizedBox(height: 20),
                        DropdownButtonFormField<int>(
                          value: _branchId,
                          style: GoogleFonts.plusJakartaSans(color: context.onSurface),
                          decoration: const InputDecoration(
                            labelText: 'Assigned Branch',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                          items: branches.map((b) => DropdownMenuItem<int>(
                            value: b.id,
                            child: Text(b.name),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _branchId = val);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_role == 'staff')
                AnimateIn(
                  delay: const Duration(milliseconds: 100),
                  child: AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.security, color: AppTheme.primaryGreen, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Permissions',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        _buildPermissionSwitch(
                          title: 'Give Discounts',
                          subtitle: 'Can apply custom discounts to cart items',
                          value: _canGiveDiscount,
                          onChanged: (val) => setState(() => _canGiveDiscount = val),
                        ),
                        if (_canGiveDiscount)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                            child: TextFormField(
                              controller: _discountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.plusJakartaSans(),
                              decoration: const InputDecoration(
                                labelText: 'Maximum Allowed Discount %',
                                suffixText: '%',
                                isDense: true,
                              ),
                            ),
                          ),
                        _buildPermissionSwitch(
                          title: 'View Reports',
                          subtitle: 'Access to sales and performance metrics',
                          value: _canViewReports,
                          onChanged: (val) => setState(() => _canViewReports = val),
                        ),
                        _buildPermissionSwitch(
                          title: 'Manage Inventory',
                          subtitle: 'Can add products and update stock levels',
                          value: _canManageInventory,
                          onChanged: (val) => setState(() => _canManageInventory = val),
                        ),
                        _buildPermissionSwitch(
                          title: 'Returns & Deletions',
                          subtitle: 'Can delete bills and process refunds',
                          value: _canDeleteBill,
                          onChanged: (val) => setState(() => _canDeleteBill = val),
                        ),
                        _buildPermissionSwitch(
                          title: 'Manage Staff',
                          subtitle: 'Can create and edit other employee accounts',
                          value: _canManageEmployees,
                          onChanged: (val) => setState(() => _canManageEmployees = val),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 32),
              GradientButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : Text(
                        isEdit ? 'Save Changes' : 'Create Employee Profile',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: context.subText)),
      value: value,
      activeColor: AppTheme.primaryGreen,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
