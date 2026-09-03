import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../providers/subscription_provider.dart';
import '../../services/subscription_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'shop_setup_screen.dart';
import '../../providers/preference_provider.dart';
import '../subscription/subscription_expired_screen.dart';
import '../subscription/subscription_paywall_screen.dart';
import 'profile_picker_screen.dart';
import '../../providers/employee_provider.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../models/subscription.dart';
import '../../models/employee.dart';
import 'device_restricted_screen.dart';
import 'staff_login_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final settings = ref.watch(settingsProvider);
    final subscriptionAsync = ref.watch(subscriptionProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // ONE DEVICE RULE: If this device was previously linked as a staff device
          // (i.e. it was set up using a QR/code handshake), skip the full login screen
          // and go straight to the Staff Link screen. Staff devices should never see
          // the owner's email/password form.
          final isLinkedStaffDevice = ref.watch(isStaffDeviceProvider);
          if (isLinkedStaffDevice) {
            return const StaffLoginScreen();
          }
          return const LoginScreen();
        }

        // --- ONE DEVICE RULE ENFORCEMENT ---
        final deviceIdAsync = ref.watch(deviceIdProvider);
        final shopUid = ref.watch(activeShopUidProvider);
        
        if (shopUid != null) {
          // Identify if we are currently logged in as a specific employee
          final employeeAsync = ref.watch(currentEmployeeProvider);
          final currentEmployee = employeeAsync.valueOrNull;
          
          // Use the appropriate document provider based on the login type
          // If staff is logged in, we watch their specific employee document.
          // Otherwise (owner or profile picker), we watch the main owner/shop document.
          final isStaff = currentEmployee != null && currentEmployee.role != EmployeeRole.owner;
          final remoteDocAsync = isStaff 
              ? ref.watch(employeeDocumentProvider) 
              : ref.watch(userDocumentProvider);
          
          return deviceIdAsync.when(
            data: (currentDeviceId) {
              final userData = remoteDocAsync.value;
              final lastDeviceId = userData?['last_device_id'] as String?;
              
              int maxDevices = 999;
              
              if (maxDevices == 1 && lastDeviceId != null && lastDeviceId != currentDeviceId) {
                return const DeviceRestrictedScreen();
              }

              // Data Presence Check: If we are the authorized device but have 0 products,
              // we likely need an immediate sync to show the dashboard correctly.
              Future.microtask(() async {
                final productCount = await DatabaseService.instance.getTableRecordCount('products');
                if (productCount == 0) {
                  ref.read(syncServiceProvider).startSync();
                }
              });
              
              return _buildMainFlow(context, ref, user, settings, subscriptionAsync);
            },
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (e, _) => _buildMainFlow(context, ref, user, settings, subscriptionAsync),
          );
        }
        
        return _buildMainFlow(context, ref, user, settings, subscriptionAsync);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const LoginScreen(),
    );
  }

  Widget _buildMainFlow(BuildContext context, WidgetRef ref, User user, dynamic settings, AsyncValue<Subscription?> subscriptionAsync) {
    // 1. Setup Check: Owners must complete initial shop setup first.
    // Staff members skip this check and go straight to the app.
    final currentEmployeeAsync = ref.watch(currentEmployeeProvider);
    final isEmployeeLoggedIn = currentEmployeeAsync.valueOrNull != null;

    if (!settings.isSetupComplete && !isEmployeeLoggedIn) {
      // Go straight to ShopSetupScreen.
      ref.watch(settingsSyncProvider); // trigger sync in background
      return const ShopSetupScreen();
    }

    // 2. Subscription Check: If expired/invalid after trial, show paywall screen.
    final subscription = subscriptionAsync.value;
    if (subscription != null && !subscription.isValid) {
      return const SubscriptionPaywallScreen(isDismissible: false);
    }

    return _buildAuthFlow(context, ref, user, subscriptionAsync);
  }

  Widget _buildAuthFlow(BuildContext context, WidgetRef ref, dynamic user, AsyncValue<Subscription?> subscriptionAsync) {
    // ALWAYS watch settingsSyncProvider to ensure we have latest employees/branches
    ref.watch(settingsSyncProvider);
    
    // Employee Selection Check
    final currentEmployeeAsync = ref.watch(currentEmployeeProvider);
    return currentEmployeeAsync.when(
      data: (employee) {
        if (employee == null) {
          // Trigger a background startup sync now that we have a shop ID
          Future.microtask(() => ref.read(syncServiceProvider).startSync());
          return const ProfilePickerScreen();
        }
        return const HomeScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const ProfilePickerScreen(),
    );
  }
}
