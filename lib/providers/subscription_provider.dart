import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';

// Subscription service provider
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService.instance;
});

// Stream provider for subscription
final subscriptionProvider = StreamProvider<Subscription?>((ref) {
  final shopUid = ref.watch(activeShopUidProvider);
  if (shopUid == null) return Stream.value(null);
  return ref.watch(subscriptionServiceProvider).subscriptionStream();
});

// Is subscription valid?
final isSubscriptionValidProvider = FutureProvider<bool>((ref) async {
  final subscription = await ref.watch(subscriptionProvider.future);
  return subscription?.isValid ?? false;
});

// Is user in trial?
final isTrialProvider = Provider<bool>((ref) {
  final subscriptionAsync = ref.watch(subscriptionProvider);
  return subscriptionAsync.when(
    data: (subscription) => subscription?.isTrialActive ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Trial days remaining
final trialDaysRemainingProvider = Provider<int>((ref) {
  final subscriptionAsync = ref.watch(subscriptionProvider);
  return subscriptionAsync.when(
    data: (subscription) => subscription?.trialDaysRemaining ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// Current plan tier
final planTierProvider = Provider<PlanTier>((ref) {
  final subscriptionAsync = ref.watch(subscriptionProvider);
  return subscriptionAsync.when(
    data: (subscription) => subscription?.planTier ?? PlanTier.starter,
    loading: () => PlanTier.starter,
    error: (_, __) => PlanTier.starter,
  );
});

// Feature gate provider
final hasFeatureProvider = Provider.family<bool, String>((ref, featureName) {
  final subscriptionAsync = ref.watch(subscriptionProvider);
  return subscriptionAsync.when(
    data: (subscription) {
      if (subscription == null || !subscription.isValid) return false;
      return subscription.hasFeature(featureName);
    },
    loading: () => false,
    error: (_, __) => false,
  );
});
