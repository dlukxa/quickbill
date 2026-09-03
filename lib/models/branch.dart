class Branch {
  final int? id;
  final String name;
  final String? address;
  final String? phone;
  final String? businessType;
  final String? operatingHours; // e.g. JSON string {"1": {"start": "09:00", "end": "17:00"}}
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Branch({
    this.id,
    required this.name,
    this.address,
    this.phone,
    this.businessType,
    this.operatingHours,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'business_type': businessType,
      'operating_hours': operatingHours,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      businessType: map['business_type'] as String?,
      operatingHours: map['operating_hours'] as String?,
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : DateTime.now(),
    );
  }

  Branch copyWith({
    int? id,
    String? name,
    String? address,
    String? phone,
    String? businessType,
    String? operatingHours,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return Branch(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      businessType: businessType ?? this.businessType,
      operatingHours: operatingHours ?? this.operatingHours,
      isActive: isActive ?? this.isActive,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
