import 'dart:convert';

class Appointment {
  final int? id;
  final int branchId;
  final int? customerId;
  final int? employeeId;
  final List<int> serviceIds;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String status; // 'booked', 'confirmed', 'inProgress', 'completed', 'cancelled', 'noShow'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  final bool deleted;

  Appointment({
    this.id,
    this.branchId = 1,
    this.customerId,
    this.employeeId,
    required this.serviceIds,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.status = 'booked',
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
    this.deleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'branch_id': branchId,
      'customer_id': customerId,
      'employee_id': employeeId,
      'service_ids': jsonEncode(serviceIds),
      'scheduled_start': scheduledStart.toIso8601String(),
      'scheduled_end': scheduledEnd.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    List<int> sIds = [];
    if (map['service_ids'] != null) {
      sIds = List<int>.from(jsonDecode(map['service_ids']));
    }

    return Appointment(
      id: map['id'],
      branchId: map['branch_id'] ?? 1,
      customerId: map['customer_id'],
      employeeId: map['employee_id'],
      serviceIds: sIds,
      scheduledStart: DateTime.parse(map['scheduled_start']),
      scheduledEnd: DateTime.parse(map['scheduled_end']),
      status: map['status'] ?? 'booked',
      notes: map['notes'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
      synced: (map['synced'] ?? 0) == 1,
      deleted: (map['deleted'] ?? 0) == 1,
    );
  }

  Appointment copyWith({
    int? id,
    int? branchId,
    int? customerId,
    int? employeeId,
    List<int>? serviceIds,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? status,
    String? notes,
    bool? synced,
    bool? deleted,
  }) {
    return Appointment(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      customerId: customerId ?? this.customerId,
      employeeId: employeeId ?? this.employeeId,
      serviceIds: serviceIds ?? this.serviceIds,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
    );
  }
}
