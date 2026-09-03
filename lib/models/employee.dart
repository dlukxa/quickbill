import 'dart:convert';
import 'package:crypto/crypto.dart';

enum EmployeeRole {
  owner,
  staff,
}

enum EmployeeStatus {
  active,
  inactive,
}

class EmployeePermissions {
  final bool canGiveDiscount;
  final bool canDeleteBill;
  final bool canViewReports;
  final bool canManageInventory;
  final bool canManageEmployees;
  final double maxDiscountPercent;

  const EmployeePermissions({
    this.canGiveDiscount = false,
    this.canDeleteBill = false,
    this.canViewReports = false,
    this.canManageInventory = false,
    this.canManageEmployees = false,
    this.maxDiscountPercent = 0,
  });

  factory EmployeePermissions.defaultStaff() {
    return const EmployeePermissions(
      canGiveDiscount: true,
      maxDiscountPercent: 5.0,
    );
  }

  factory EmployeePermissions.owner() {
    return const EmployeePermissions(
      canGiveDiscount: true,
      canDeleteBill: true,
      canViewReports: true,
      canManageInventory: true,
      canManageEmployees: true,
      maxDiscountPercent: 100.0,
    );
  }

  String toJson() {
    return jsonEncode({
      'canGiveDiscount': canGiveDiscount,
      'canDeleteBill': canDeleteBill,
      'canViewReports': canViewReports,
      'canManageInventory': canManageInventory,
      'canManageEmployees': canManageEmployees,
      'maxDiscountPercent': maxDiscountPercent,
    });
  }

  factory EmployeePermissions.fromJson(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return EmployeePermissions(
        canGiveDiscount: map['canGiveDiscount'] ?? false,
        canDeleteBill: map['canDeleteBill'] ?? false,
        canViewReports: map['canViewReports'] ?? false,
        canManageInventory: map['canManageInventory'] ?? false,
        canManageEmployees: map['canManageEmployees'] ?? false,
        maxDiscountPercent: (map['maxDiscountPercent'] ?? 0).toDouble(),
      );
    } catch (e) {
      return EmployeePermissions.defaultStaff();
    }
  }
}

class Employee {
  final int? id;
  final int branchId;
  final String name;
  final String pin; // Hashed
  final EmployeeRole rawRole;
  final EmployeePermissions rawPermissions;
  final EmployeeStatus status;
  final String? staffId;
  final String? lastDeviceId;
  final bool mustChangePassword;
  final List<int>? skillServiceIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Employee({
    this.id,
    this.branchId = 1,
    required this.name,
    required this.pin,
    EmployeeRole? role,
    EmployeePermissions? permissions,
    this.status = EmployeeStatus.active,
    this.staffId,
    this.lastDeviceId,
    this.mustChangePassword = false,
    this.skillServiceIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : rawRole = role ?? EmployeeRole.staff,
        rawPermissions = permissions ??
            ((role ?? EmployeeRole.staff) == EmployeeRole.owner
                ? EmployeePermissions.owner()
                : EmployeePermissions.defaultStaff()),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  EmployeeRole get role => rawRole;
  EmployeePermissions get permissions => rawPermissions;

  // Helper to check permissions
  bool get isAdmin => rawRole == EmployeeRole.owner;
  bool get canGiveDiscount => rawRole == EmployeeRole.owner || rawPermissions.canGiveDiscount;
  bool get canDeleteBill => rawRole == EmployeeRole.owner || rawPermissions.canDeleteBill;
  bool get canViewReports => rawRole == EmployeeRole.owner || rawPermissions.canViewReports;
  bool get canManageInventory => rawRole == EmployeeRole.owner || rawPermissions.canManageInventory;
  bool get canManageEmployees => rawRole == EmployeeRole.owner || rawPermissions.canManageEmployees;

  // Static helper to hash PIN
  static String hashPin(String pin) {
    const salt = 'QuickBillSalt2026';
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Verify PIN
  bool verifyPin(String inputPin) {
    return hashPin(inputPin) == pin;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
      'pin': pin,
      'role': rawRole.name,
      'permissions': rawPermissions.toJson(),
      'status': status.name,
      'staff_id': staffId,
      'last_device_id': lastDeviceId,
      'must_change_password': mustChangePassword ? 1 : 0,
      'skill_service_ids': skillServiceIds != null ? jsonEncode(skillServiceIds) : null,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    // Handle legacy 'is_active' mapping to status
    EmployeeStatus resolvedStatus = EmployeeStatus.active;
    if (map.containsKey('is_active')) {
      final isActiveValue = map['is_active'];
      if (isActiveValue is bool) {
        resolvedStatus = isActiveValue ? EmployeeStatus.active : EmployeeStatus.inactive;
      } else if (isActiveValue is int) {
        resolvedStatus = isActiveValue == 1 ? EmployeeStatus.active : EmployeeStatus.inactive;
      }
    } else if (map.containsKey('status')) {
      resolvedStatus = EmployeeStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => EmployeeStatus.active,
      );
    }

    final dbRole = EmployeeRole.values.firstWhere(
      (e) => e.name == map['role'],
      orElse: () => EmployeeRole.staff,
    );
    final dbPermissions = map['permissions'] != null
        ? EmployeePermissions.fromJson(map['permissions'] as String)
        : null;

    return Employee(
      id: map['id'] as int?,
      branchId: map['branch_id'] as int? ?? 1,
      name: map['name'] as String,
      pin: map['pin'] as String,
      role: dbRole,
      permissions: dbPermissions,
      status: resolvedStatus,
      staffId: map['staff_id'] as String?,
      lastDeviceId: map['last_device_id'] as String?,
      mustChangePassword: (map['must_change_password'] ?? 0) == 1,
      skillServiceIds: map['skill_service_ids'] != null 
          ? List<int>.from(jsonDecode(map['skill_service_ids'])) 
          : null,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : DateTime.now(),
    );
  }
  
  Employee copyWith({
    int? id,
    int? branchId,
    String? name,
    String? pin,
    EmployeeRole? role,
    EmployeePermissions? permissions,
    EmployeeStatus? status,
    String? staffId,
    bool? mustChangePassword,
    String? lastDeviceId,
    List<int>? skillServiceIds,
    DateTime? updatedAt,
  }) {
    return Employee(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      name: name ?? this.name,
      pin: pin ?? this.pin,
      role: role ?? rawRole,
      permissions: permissions ?? rawPermissions,
      status: status ?? this.status,
      staffId: staffId ?? this.staffId,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      skillServiceIds: skillServiceIds ?? this.skillServiceIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
