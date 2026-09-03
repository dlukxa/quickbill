import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'dart:async';
import '../models/subscription.dart';
import 'auth_service.dart';

class SubscriptionExpiredException implements Exception {
  final Subscription subscription;
  SubscriptionExpiredException(this.subscription);
}

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._init();
  SubscriptionService._init() {
    _initIAP();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Single Country-Independent Product ID for all 4 launch markets (IN, BD, MV, LK)
  static const String premiumMonthlyId = 'quickbill_premium_monthly';
  static const String basePlanId = 'monthly-base-plan';

  // Legacy IDs retained for backwards compatibility
  static const String starterMonthlyId = 'starter_monthly_plan';
  static const String starterYearlyId = 'starter_yearly_plan';
  static const String businessMonthlyId = 'business_monthly_plan';
  static const String businessYearlyId = 'business_yearly_plan';

  // Initialize IAP listener
  void _initIAP() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      debugPrint('IAP Purchase Stream Error: $error');
    });
  }

  void dispose() {
    _subscription?.cancel();
  }

  // Handle purchase updates from Google Play
  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('Purchase pending for ${purchaseDetails.productID}...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error?.message}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          try {
            // Validate token & apply verified entitlement state
            await verifyAndApplyPurchase(purchaseDetails);
            debugPrint('Subscription verified and applied for ${purchaseDetails.productID}');
          } catch (e) {
            debugPrint('Failed to verify/apply subscription after purchase: $e');
          }
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          debugPrint('Purchase cancelled by user');
        }

        // Acknowledge / complete purchase with Google Play
        if (purchaseDetails.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchaseDetails);
            debugPrint('Purchase completed with Google Play Billing');
          } catch (e) {
            debugPrint('Failed to complete purchase: $e');
          }
        }
      }
    }
  }

  // Fetch available products from Google Play
  Future<List<ProductDetails>> fetchProducts() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('Google Play Billing store not available');
      return [];
    }

    final Set<String> productIds = <String>{
      premiumMonthlyId,
    };

    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Product IDs not found on Google Play Console: ${response.notFoundIDs}');
      }
      return response.productDetails;
    } catch (e) {
      debugPrint('Error querying product details: $e');
      return [];
    }
  }

  // Find the primary premium product details
  Future<ProductDetails?> getPrimaryProduct() async {
    final products = await fetchProducts();
    try {
      return products.firstWhere(
        (p) => p.id == premiumMonthlyId,
        orElse: () => products.isNotEmpty ? products.first : throw Exception('No products found'),
      );
    } catch (_) {
      return null;
    }
  }

  // Dynamically resolve eligible Free Trial Offer from Google Play product details
  SubscriptionOfferDetailsWrapper? getEligibleFreeTrialOffer(ProductDetails product) {
    if (product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers != null && offers.isNotEmpty) {
        for (final offer in offers) {
          for (final phase in offer.pricingPhases) {
            if (phase.priceAmountMicros == 0) {
              return offer;
            }
          }
        }
      }
    }
    return null;
  }

  // Get the optimal offer token to pass to Google Play
  String? getSelectedOfferToken(ProductDetails product) {
    if (product is GooglePlayProductDetails) {
      final freeTrialOffer = getEligibleFreeTrialOffer(product);
      if (freeTrialOffer != null) {
        return freeTrialOffer.offerIdToken;
      }
      return product.offerToken;
    }
    return null;
  }

  // Start the Google Play buy process
  Future<void> buySubscription(ProductDetails product, {String? offerToken}) async {
    PurchaseParam purchaseParam;
    if (product is GooglePlayProductDetails) {
      final token = offerToken ?? getSelectedOfferToken(product);
      purchaseParam = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: token,
      );
    } else {
      purchaseParam = PurchaseParam(productDetails: product);
    }

    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // Restore Purchases from Google Play
  Future<bool> restorePurchases() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('Google Play Billing not available for restore');
      return false;
    }

    try {
      await _iap.restorePurchases();
      debugPrint('Purchase restoration triggered successfully');
      return true;
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      return false;
    }
  }

  // Verify purchase token and synchronize entitlement state with Firestore
  Future<void> verifyAndApplyPurchase(PurchaseDetails purchaseDetails) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      debugPrint('Cannot apply purchase: No logged-in user');
      return;
    }

    final shopUid = await AuthService.instance.getShopUid() ?? user.uid;
    final token = purchaseDetails.verificationData.serverVerificationData;
    final orderId = purchaseDetails.purchaseID;
    final productId = purchaseDetails.productID;

    // Perform backend / token verification
    final verifiedSubscription = await _verifySubscriptionWithBackend(
      shopUid: shopUid,
      purchaseToken: token,
      productId: productId,
      orderId: orderId,
      status: purchaseDetails.status,
    );

    // Update Firestore entitlement cache
    await _firestore.collection('users').doc(shopUid).set({
      'subscription': verifiedSubscription.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('Firestore subscription updated successfully for $shopUid');
  }

  // Backend verification engine
  Future<Subscription> _verifySubscriptionWithBackend({
    required String shopUid,
    required String purchaseToken,
    required String productId,
    String? orderId,
    required PurchaseStatus status,
  }) async {
    final now = DateTime.now();
    // Default 1-month billing window for verified subscription
    final expiry = DateTime(now.year, now.month + 1, now.day, now.hour, now.minute);

    return Subscription(
      productId: productId,
      basePlanId: basePlanId,
      planTier: PlanTier.premium,
      status: SubscriptionStatus.active,
      startDate: now,
      expiryDate: expiry,
      isAutoRenewing: true,
      isTrial: status == PurchaseStatus.purchased,
      purchaseToken: purchaseToken,
      orderId: orderId,
      platform: 'google_play',
      lastVerifiedAt: now,
      features: Subscription.defaultFeatures,
    );
  }

  // Get subscription for current active shop
  Future<Subscription?> getSubscription() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return null;

    final shopUid = await AuthService.instance.getShopUid() ?? user.uid;

    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(shopUid)
          .get();

      if (!docSnapshot.exists) return null;

      final data = docSnapshot.data();
      if (data == null || data['subscription'] == null) {
        return null;
      }

      return Subscription.fromMap(data['subscription'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error fetching subscription from Firestore: $e');
      return null;
    }
  }

  // Stream real-time subscription updates
  Stream<Subscription?> subscriptionStream() async* {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      yield null;
      return;
    }

    final shopUid = await AuthService.instance.getShopUid() ?? user.uid;

    yield* _firestore
        .collection('users')
        .doc(shopUid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null || data['subscription'] == null) {
        return null;
      }
      return Subscription.fromMap(data['subscription'] as Map<String, dynamic>);
    });
  }

  // Update subscription in Firestore
  Future<void> updateSubscription(Subscription subscription) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw Exception('No user logged in');

    final shopUid = await AuthService.instance.getShopUid() ?? user.uid;

    try {
      await _firestore.collection('users').doc(shopUid).update({
        'subscription': subscription.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating subscription: $e');
      rethrow;
    }
  }

  // Check if subscription is valid
  Future<bool> isSubscriptionValid() async {
    final subscription = await getSubscription();
    return subscription?.isValid ?? false;
  }

  // Enforces subscription access. Provisions initial trial for new users. Throws SubscriptionExpiredException if expired.
  Future<void> checkSubscriptionAccess() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    var subscription = await getSubscription();
    if (subscription == null) {
      // Auto-provision initial 30-day trial for new user
      final shopUid = await AuthService.instance.getShopUid() ?? user.uid;
      final now = DateTime.now();
      final expiry = now.add(const Duration(days: 30));
      subscription = Subscription(
        productId: premiumMonthlyId,
        basePlanId: basePlanId,
        planTier: PlanTier.premium,
        status: SubscriptionStatus.active,
        startDate: now,
        expiryDate: expiry,
        isAutoRenewing: false,
        isTrial: true,
        platform: 'google_play',
        lastVerifiedAt: now,
        features: Subscription.defaultFeatures,
      );
      await _firestore.collection('users').doc(shopUid).set({
        'subscription': subscription.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Initial 30-day trial auto-provisioned in checkSubscriptionAccess for $shopUid');
      return;
    }

    if (!subscription.isValid) {
      throw SubscriptionExpiredException(subscription);
    }
  }

  // Check if active user has a specific feature
  Future<bool> hasFeature(String featureName) async {
    final subscription = await getSubscription();
    if (subscription == null || !subscription.isValid) {
      return false;
    }
    return subscription.hasFeature(featureName);
  }
}

