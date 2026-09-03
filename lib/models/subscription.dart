enum SubscriptionStatus {
  trial,
  active,
  cancelled,
  expired,
  inGracePeriod,
  paused,
}

enum PlanTier {
  starter,
  business,
  multiBranch,
  premium,
}

class Subscription {
  static const String defaultProductId = 'quickbill_premium_monthly';
  static const String defaultBasePlanId = 'monthly-base-plan';

  final String productId;
  final String basePlanId;
  final PlanTier planTier;
  final SubscriptionStatus status;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final DateTime? trialStartDate; // Kept for legacy 30-day trial accounts migration
  final bool isAutoRenewing;
  final bool isTrial;
  final String? purchaseToken;
  final String? orderId;
  final String? platform;
  final DateTime? lastVerifiedAt;
  final int maxDevices;
  final Map<String, bool> features;

  Subscription({
    this.productId = defaultProductId,
    this.basePlanId = defaultBasePlanId,
    this.planTier = PlanTier.premium,
    required this.status,
    this.startDate,
    this.expiryDate,
    this.trialStartDate,
    this.isAutoRenewing = true,
    this.isTrial = false,
    this.purchaseToken,
    this.orderId,
    this.platform = 'google_play',
    this.lastVerifiedAt,
    this.maxDevices = 999,
    Map<String, bool>? features,
  }) : features = features ?? defaultFeatures;

  static const Map<String, bool> defaultFeatures = {
    'cloudSync': true,
    'cloudBackup': true,
    'basicReports': true,
    'advancedReports': true,
    'multiUser': true,
    'grn': true,
    'multiBranch': true,
    'branchControl': true,
    'centralDashboard': true,
    'stockTransfer': true,
    'barcodeScanning': true,
    'thermalPrinting': true,
    'aiFeatures': true,
  };

  // Check if trial is active (either legacy 30-day trial or Google Play trial offer)
  bool get isTrialActive {
    if (status == SubscriptionStatus.trial || isTrial) {
      if (expiryDate != null) {
        return DateTime.now().isBefore(expiryDate!);
      }
      if (trialStartDate != null) {
        final trialEnd = trialStartDate!.add(const Duration(days: 30));
        return DateTime.now().isBefore(trialEnd);
      }
    }
    return false;
  }

  // Calculate days remaining in trial
  int get trialDaysRemaining {
    if (!isTrialActive) return 0;
    if (expiryDate != null) {
      final remaining = expiryDate!.difference(DateTime.now()).inDays;
      return remaining > 0 ? remaining : 0;
    }
    if (trialStartDate != null) {
      final trialEnd = trialStartDate!.add(const Duration(days: 30));
      final remaining = trialEnd.difference(DateTime.now()).inDays;
      return remaining > 0 ? remaining : 0;
    }
    return 0;
  }

  // Check if subscription or trial is currently valid
  bool get isValid {
    // 1. Trial state (Google Play trial or legacy Firestore trial)
    if (status == SubscriptionStatus.trial || isTrial) {
      return isTrialActive;
    }

    // 2. Active, inGracePeriod, or Cancelled (cancelled remains valid until expiryDate!)
    if (status == SubscriptionStatus.active ||
        status == SubscriptionStatus.inGracePeriod ||
        status == SubscriptionStatus.cancelled) {
      if (expiryDate == null) return true;
      return DateTime.now().isBefore(expiryDate!);
    }

    // 3. Expired or paused
    return false;
  }

  // Feature access check
  bool hasFeature(String featureName) {
    if (!isValid) return false;
    return features[featureName] ?? true;
  }

  // Factory: For legacy trial compatibility
  factory Subscription.newTrial({PlanTier tier = PlanTier.premium}) {
    final now = DateTime.now();
    return Subscription(
      productId: defaultProductId,
      basePlanId: defaultBasePlanId,
      planTier: tier,
      status: SubscriptionStatus.trial,
      trialStartDate: now,
      isTrial: true,
      expiryDate: now.add(const Duration(days: 30)),
      features: defaultFeatures,
    );
  }

  // Backward compatibility helper
  static Map<String, bool> getFeaturesForTier(PlanTier tier) {
    return defaultFeatures;
  }

  // Convert to Firestore map (verified entitlement state)
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'basePlanId': basePlanId,
      'planTier': planTier.name,
      'status': status.name,
      'startDate': startDate?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'trialStartDate': trialStartDate?.toIso8601String(),
      'isAutoRenewing': isAutoRenewing,
      'isTrial': isTrial,
      'purchaseToken': purchaseToken,
      'orderId': orderId,
      'platform': platform,
      'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
      'maxDevices': maxDevices,
      'features': features,
    };
  }

  // Create from Firestore map
  factory Subscription.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'trial';
    final parsedStatus = SubscriptionStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => SubscriptionStatus.trial,
    );

    final tierStr = map['planTier'] as String? ?? 'premium';
    final parsedTier = PlanTier.values.firstWhere(
      (e) => e.name == tierStr,
      orElse: () => PlanTier.premium,
    );

    return Subscription(
      productId: map['productId'] as String? ?? defaultProductId,
      basePlanId: map['basePlanId'] as String? ?? defaultBasePlanId,
      planTier: parsedTier,
      status: parsedStatus,
      startDate: map['startDate'] != null ? DateTime.tryParse(map['startDate']) : null,
      expiryDate: map['expiryDate'] != null ? DateTime.tryParse(map['expiryDate']) : null,
      trialStartDate: map['trialStartDate'] != null ? DateTime.tryParse(map['trialStartDate']) : null,
      isAutoRenewing: map['isAutoRenewing'] as bool? ?? true,
      isTrial: map['isTrial'] as bool? ?? (parsedStatus == SubscriptionStatus.trial),
      purchaseToken: map['purchaseToken'] as String?,
      orderId: map['orderId'] as String?,
      platform: map['platform'] as String? ?? 'google_play',
      lastVerifiedAt: map['lastVerifiedAt'] != null ? DateTime.tryParse(map['lastVerifiedAt']) : null,
      maxDevices: map['maxDevices'] as int? ?? 999,
      features: map['features'] != null
          ? Map<String, bool>.from(map['features'] as Map)
          : defaultFeatures,
    );
  }

  Subscription copyWith({
    String? productId,
    String? basePlanId,
    PlanTier? planTier,
    SubscriptionStatus? status,
    DateTime? startDate,
    DateTime? expiryDate,
    DateTime? trialStartDate,
    bool? isAutoRenewing,
    bool? isTrial,
    String? purchaseToken,
    String? orderId,
    String? platform,
    DateTime? lastVerifiedAt,
    int? maxDevices,
    Map<String, bool>? features,
  }) {
    return Subscription(
      productId: productId ?? this.productId,
      basePlanId: basePlanId ?? this.basePlanId,
      planTier: planTier ?? this.planTier,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      trialStartDate: trialStartDate ?? this.trialStartDate,
      isAutoRenewing: isAutoRenewing ?? this.isAutoRenewing,
      isTrial: isTrial ?? this.isTrial,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      orderId: orderId ?? this.orderId,
      platform: platform ?? this.platform,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      maxDevices: maxDevices ?? this.maxDevices,
      features: features ?? this.features,
    );
  }
}
