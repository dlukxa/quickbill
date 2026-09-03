import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee.dart';
import '../services/database_service.dart';
import 'branch_provider.dart';
import 'report_provider.dart';

// Current Session Management
final currentEmployeeProvider = StateNotifierProvider<CurrentEmployeeNotifier, AsyncValue<Employee?>>((ref) {
  return CurrentEmployeeNotifier(ref);
});

class CurrentEmployeeNotifier extends StateNotifier<AsyncValue<Employee?>> {
  final Ref ref;
  CurrentEmployeeNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadSession();
  }

  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getInt('current_employee_id');
      
      if (employeeId != null) {
        final employee = await DatabaseService.instance.getEmployeeById(employeeId);
        if (employee != null && employee.status == EmployeeStatus.active) {
          if (mounted) state = AsyncValue.data(employee);
        } else {
          // Invalid or inactive user, clear session
          await logout();
        }
      } else {
        if (mounted) state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> selectEmployee(Employee employee) async {
    if (mounted) state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_employee_id', employee.id!);
      try {
        await DatabaseService.instance.clockInEmployee(employee.id!);
      } catch (e) {
        debugPrint('⚠️ Warning: Failed to clock in employee (ignoring to allow login): $e');
      }
      
      // Update persistent staff device status based on whether the logged in employee is staff
      final isStaff = employee.role != EmployeeRole.owner;
      await ref.read(isStaffDeviceProvider.notifier).setStaffDevice(isStaff);
      
      // Lock staff to their assigned branch
      if (isStaff) {
        await ref.read(branchProvider.notifier).selectBranchById(employee.branchId);
      }
      
      if (mounted) state = AsyncValue.data(employee);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<bool> login(String pin) async {
    if (mounted) state = const AsyncValue.loading();
    try {
      final hashedPin = Employee.hashPin(pin);
      final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
      final employee = await DatabaseService.instance.getEmployeeByPin(hashedPin, branchId);
      
      if (employee != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('current_employee_id', employee.id!);
        try {
          await DatabaseService.instance.clockInEmployee(employee.id!);
        } catch (e) {
          debugPrint('⚠️ Warning: Failed to clock in employee (ignoring to allow login): $e');
        }
        
        final isStaff = employee.role != EmployeeRole.owner;
        await ref.read(isStaffDeviceProvider.notifier).setStaffDevice(isStaff);
        
        // Lock staff to their assigned branch
        if (isStaff) {
          await ref.read(branchProvider.notifier).selectBranchById(employee.branchId);
        }
        
        if (mounted) state = AsyncValue.data(employee);
        return true;
      } else {
        if (mounted) state = const AsyncValue.data(null); // Keep as null if failed
        return false;
      }
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> logout() async {
    final currentState = state.value;
    if (currentState != null && currentState.id != null) {
      await DatabaseService.instance.clockOutEmployee(currentState.id!);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_employee_id');
    ref.invalidate(dismissedAlertsProvider);
    if (mounted) state = const AsyncValue.data(null);
  }
}

// Employee Management (For Owner)
final employeeListProvider = StateNotifierProvider<EmployeeListNotifier, AsyncValue<List<Employee>>>((ref) {
  final branchId = ref.watch(currentBranchIdProvider);
  return EmployeeListNotifier(ref, branchId);
});

class EmployeeListNotifier extends StateNotifier<AsyncValue<List<Employee>>> {
  final Ref ref;
  final int branchId;
  EmployeeListNotifier(this.ref, this.branchId) : super(const AsyncValue.loading()) {
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    try {
      // Ensure owner exists immediately before querying.
      // With WAL mode enabled, sqflite will automatically queue this write 
      // if a background sync transaction is currently running.
      await DatabaseService.instance.ensureOwnerExists(branchId);
      
      List<Employee> employees = await DatabaseService.instance.getAllEmployees(branchId);
      
      if (!mounted) return;
      state = AsyncValue.data(employees);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<Employee>> loadEmployeesAndReturn() async {
    final employees = await DatabaseService.instance.getAllEmployees(branchId);
    if (mounted) state = AsyncValue.data(employees);
    return employees;
  }

  Future<void> addEmployee(Employee employee) async {
    await DatabaseService.instance.insertEmployee(employee);
    await loadEmployees();
  }

  Future<void> updateEmployee(Employee employee) async {
    await DatabaseService.instance.updateEmployee(employee);
    // If the updated employee is the one currently logged in, refresh their session
    final currentEmployee = ref.read(currentEmployeeProvider).value;
    if (currentEmployee?.id == employee.id) {
       ref.read(currentEmployeeProvider.notifier).loadSession();
     }
    await loadEmployees();
  }

  Future<void> deleteEmployee(int id) async {
    await DatabaseService.instance.deleteEmployee(id);
    await loadEmployees();
  }
}

// Device Ownership Management (Staff vs Owner Device)
final isStaffDeviceProvider = StateNotifierProvider.autoDispose<IsStaffDeviceNotifier, bool>((ref) {
  return IsStaffDeviceNotifier();
});

class IsStaffDeviceNotifier extends StateNotifier<bool> {
  IsStaffDeviceNotifier() : super(false) {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = prefs.getBool('is_staff_device') ?? false;
  }

  Future<void> setStaffDevice(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_staff_device', value);
    if (!mounted) return;
    state = value;
  }
}
