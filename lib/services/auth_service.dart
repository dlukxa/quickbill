import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../providers/employee_provider.dart';
import '../models/subscription.dart';
import 'subscription_service.dart';
import 'database_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  // Wrap the stream to catch any library-level cast errors (like the PigeonUserDetails error)
  return FirebaseAuth.instance.authStateChanges().handleError((error) {
    debugPrint('Auth Stream Error: $error');
  });
});

final userDocumentProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final shopUid = ref.watch(activeShopUidProvider);
  if (shopUid == null) return Stream.value(null);
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(shopUid)
      .snapshots()
      .map((doc) => doc.data());
});

final employeeDocumentProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final shopUid = ref.watch(activeShopUidProvider);
  final employeeAsync = ref.watch(currentEmployeeProvider);
  final employeeId = employeeAsync.value?.id;
  
  if (shopUid == null || employeeId == null) return Stream.value(null);
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(shopUid)
      .collection('employees')
      .doc(employeeId.toString())
      .snapshots()
      .map((doc) => doc.data());
});

final activeShopUidProvider = StateNotifierProvider<ActiveShopUidNotifier, String?>((ref) {
  return ActiveShopUidNotifier(ref);
});

class ActiveShopUidNotifier extends StateNotifier<String?> {
  final Ref _ref;
  String? _overrideUid;

  ActiveShopUidNotifier(this._ref) : super(null) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _overrideUid = prefs.getString('active_shop_uid');
    
    // Listen to auth changes to update state when login happens
    _ref.listen(authStateProvider, (previous, next) {
      _computeState();
    });

    _computeState();
  }

  void _computeState() {
    if (_overrideUid != null && _overrideUid!.isNotEmpty) {
      state = _overrideUid;
    } else {
      final user = _ref.read(authStateProvider).value;
      state = user?.uid;
    }
  }

  void updateOverride(String? uid) {
    _overrideUid = uid;
    _computeState();
  }
}

final deviceIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  String? deviceId = prefs.getString('device_unique_id');

  if (deviceId == null) {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor;
    } else {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    }
    
    if (deviceId != null) {
      await prefs.setString('device_unique_id', deviceId);
    } else {
      deviceId = 'unknown_device';
    }
  }
  return deviceId;
});

class AuthService {
  static final AuthService instance = AuthService._init();
  AuthService._init();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up
  Future<UserCredential> signUp(String email, String password, [String? deviceId]) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // CACHE credentials for emulator auto-login bug bypass
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dev_email_cache', email);
      await prefs.setString('dev_password_cache', password);
      
      if (cred.user != null) {
        final Map<String, dynamic> data = {
          'updated_at': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        };
        if (deviceId != null) {
          data['last_device_id'] = deviceId;
        }
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set(data, SetOptions(merge: true));
        await _ensureTrialSubscription(cred.user!.uid);
      }

      return cred;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in
  Future<UserCredential> signIn(String email, String password, [String? deviceId]) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // CACHE credentials for emulator auto-login bug bypass
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dev_email_cache', email);
      await prefs.setString('dev_password_cache', password);
      
      if (cred.user != null) {
        final Map<String, dynamic> data = {
          'updated_at': FieldValue.serverTimestamp(),
        };
        if (deviceId != null) {
          data['last_device_id'] = deviceId;
        }
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set(data, SetOptions(merge: true));
        await _ensureTrialSubscription(cred.user!.uid);
      }
      
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  // Google Sign-In / Sign-Up
  Future<UserCredential> signInWithGoogle([String? deviceId]) async {
    final googleSignIn = GoogleSignIn(
      serverClientId: '20897788348-jelvtmta07f6l88i8ihmb50henjq9ttn.apps.googleusercontent.com',
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);

    if (cred.user != null) {
      final Map<String, dynamic> data = {
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (deviceId != null) {
        data['last_device_id'] = deviceId;
      }
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set(data, SetOptions(merge: true));
      await _ensureTrialSubscription(cred.user!.uid);
    }

    return cred;
  }

  /// Automatically provisions a 30-day Free Trial for new shops if no subscription exists
  Future<void> _ensureTrialSubscription(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists || doc.data()?['subscription'] == null) {
        final now = DateTime.now();
        final expiry = now.add(const Duration(days: 30));
        final trialSub = Subscription(
          productId: SubscriptionService.premiumMonthlyId,
          basePlanId: SubscriptionService.basePlanId,
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
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'subscription': trialSub.toMap(),
        }, SetOptions(merge: true));
        debugPrint('✅ Initial 30-day free trial provisioned for user $uid');
      }
    } catch (e) {
      debugPrint('Warning initializing user trial: $e');
    }
  }

  // --- Device Access Management ---
  Future<bool> checkDeviceAccess(String shopUid, String currentDeviceId) async {
    return true;
  }

  // Sign out
  Future<void> signOut() async {
    // 1. Clear database completely to prevent account data leakage
    try {
      await DatabaseService.instance.clearAllData();
    } catch (e) {
      debugPrint('Error clearing local local database on logout: $e');
    }

    // 2. Clear Shared Preferences (except device ID)
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_unique_id');
    await prefs.clear();
    if (deviceId != null) {
      await prefs.setString('device_unique_id', deviceId);
    }
    
    // 3. Clear shop uid logic
    await clearShopUid();
    
    // 4. Firebase Auth logout
    await _auth.signOut();
  }

  // --- Phone Authentication ---

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException e) onVerificationFailed,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> signInWithVerificationId(String verificationId, String smsCode, [String? deviceId]) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final cred = await _auth.signInWithCredential(credential);
    
    if (cred.user != null) {
      // Use `set` with merge so new users get their document created,
      // and existing users just get their device ID updated
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'last_device_id': deviceId ?? '',
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(), // will not overwrite existing value on merge
        'phone': cred.user!.phoneNumber ?? '',
      }, SetOptions(merge: true));
    }
    
    return cred;
  }

  Future<void> registerCurrentDevice(String deviceId) async {
    final user = _auth.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'last_device_id': deviceId,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // Current user
  User? get currentUser => _auth.currentUser;

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // --- Multi-Device Staff Logic ---
  Future<void> setShopUid(String ownerUid, [WidgetRef? ref]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_shop_uid', ownerUid);
    if (ref != null) {
      ref.read(activeShopUidProvider.notifier).updateOverride(ownerUid);
    }
  }

  Future<void> clearShopUid([WidgetRef? ref]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_shop_uid');
    if (ref != null) {
      ref.read(activeShopUidProvider.notifier).updateOverride(null);
    }
  }

  Future<String?> getShopUid() async {
    final prefs = await SharedPreferences.getInstance();
    final overrideUid = prefs.getString('active_shop_uid');
    if (overrideUid != null && overrideUid.isNotEmpty) {
      return overrideUid;
    }
    final desktopUid = prefs.getString('desktop_shop_uid');
    if (desktopUid != null && desktopUid.isNotEmpty) {
      return desktopUid;
    }
    return currentUser?.uid;
  }

  // Delete account
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final uid = user.uid;

    try {
      // 1. Delete Firestore user data
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // 2. Delete the user from Firebase Auth
      await user.delete();
      
      // 3. Clear local shop UID
      await clearShopUid();

      // 4. Clear database completely to prevent account data leakage
      try {
        await DatabaseService.instance.clearAllData();
      } catch (e) {
        debugPrint('Error clearing local local database on account delete: $e');
      }

      // 5. Clear Shared Preferences (except device ID)
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_unique_id');
      await prefs.clear();
      if (deviceId != null) {
        await prefs.setString('device_unique_id', deviceId);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please sign out and sign in again to delete your account for security reasons.');
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}
