class StaffAvailability {
  final int? id;
  final int employeeId;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final String? startTime; // e.g., "09:00"
  final String? endTime; // e.g., "17:00"
  final bool isOffDay;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  final bool deleted;

  StaffAvailability({
    this.id,
    required this.employeeId,
    required this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.isOffDay = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
    this.deleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'is_off_day': isOffDay ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory StaffAvailability.fromMap(Map<String, dynamic> map) {
    return StaffAvailability(
      id: map['id'],
      employeeId: map['employee_id'],
      dayOfWeek: map['day_of_week'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      isOffDay: (map['is_off_day'] ?? 0) == 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
      synced: (map['synced'] ?? 0) == 1,
      deleted: (map['deleted'] ?? 0) == 1,
    );
  }

  StaffAvailability copyWith({
    int? id,
    int? employeeId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    bool? isOffDay,
    bool? synced,
    bool? deleted,
  }) {
    return StaffAvailability(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isOffDay: isOffDay ?? this.isOffDay,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
    );
  }
}
