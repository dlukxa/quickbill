import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/theme.dart';
import '../../services/staff_login_service.dart';
import '../../services/auth_service.dart';
import '../../providers/employee_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animate_in.dart';
import '../../widgets/app_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../widgets/language_selector.dart';

class StaffLoginScreen extends ConsumerStatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  ConsumerState<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends ConsumerState<StaffLoginScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isScanning = true;

  Future<void> _handleLogin(String rawCode) async {
    final code = rawCode.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length != 6) return;

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      
      // 1. If not logged in at all, sign in anonymously to get a valid Firebase session.
      // This is required for Firestore Security Rules to allow searching for the staff code.
      if (authService.currentUser == null) {
        try {
          await FirebaseAuth.instance.signInAnonymously();
        } catch (e) {
          if (e.toString().contains('admin-restricted-operation')) {
            throw 'Anonymous Login is disabled in your Firebase Console. Please enable it under Authentication > Sign-in method.';
          }
          rethrow;
        }
      }

      final credentials = await StaffLoginService.instance.validateLoginCode(code);
      
      if (credentials != null) {
        final currentAuthUser = authService.currentUser;
        
        // 1. If we are not already signed into the owner's account:
        if (currentAuthUser == null || (currentAuthUser.email != credentials['email'] && currentAuthUser.phoneNumber != credentials['email'])) {
          if (credentials['password'] != 'bypass_password') {
            await authService.signIn(
              credentials['email'],
              credentials['password'],
            );
          } else {
             // For Phone Auth users, the staff device stays anon.
             // We'll set the active_shop_uid so SyncService can map to the owner's data.
             await authService.setShopUid(credentials['owner_uid'], ref);
             
             // Register this device for the employee
             final deviceId = await ref.read(deviceIdProvider.future);
             await FirebaseFirestore.instance
                 .collection('users')
                 .doc(credentials['owner_uid'])
                 .collection('employees')
                 .doc(credentials['employee_id'].toString())
                 .update({
                   'last_device_id': deviceId,
                   'updated_at': FieldValue.serverTimestamp(),
                 });
          }
        } else {
           // Clear any overrides if we correctly hit the owner
           await authService.clearShopUid(ref);
        }

        // 2. Clear the code from Firestore
        await StaffLoginService.instance.deleteCode(code);

        // 2.5 Trigger immediate sync to get owner's data (Shop info, Employees, Products)
        // This is critical on new devices where the local DB is empty!
        await ref.read(syncServiceProvider).pullRemoteChanges(isManual: true);

        // 3. Wait for AuthState to trigger and then find the employee
        // We query the database directly instead of using employeeListProvider 
        // because the provider might be invalidated by SyncService responding to the new auth state.
        
        final targetEmployee = await DatabaseService.instance.getEmployeeById(credentials['employee_id']);
        
        if (targetEmployee != null) {
          await ref.read(isStaffDeviceProvider.notifier).setStaffDevice(true);
          await ref.read(currentEmployeeProvider.notifier).selectEmployee(targetEmployee);
        }
        
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid or expired code'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.staffLogin,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: context.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.scaffoldColor,
        elevation: 0,
        actions: const [
          LanguageSelector(),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              AnimateIn(
                child: Column(
                  children: [
                    if (_isScanning)
                      Container(
                        height: 300,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: MobileScanner(
                            onDetect: (capture) {
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                if (barcode.rawValue != null) {
                                  _handleLogin(barcode.rawValue!);
                                  setState(() => _isScanning = false);
                                  break;
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    Text(
                      _isScanning ? AppLocalizations.of(context)!.scanQrCode : AppLocalizations.of(context)!.enterStaffCode,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: context.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.staffLoginInstructions,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: context.subText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (!_isScanning) ...[
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 12,
                          color: AppTheme.primaryGreen,
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          counterText: '',
                          filled: true,
                          fillColor: context.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.borderColor, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.borderColor),
                          ),
                        ),
                        onChanged: (val) {
                          if (val.length == 6) _handleLogin(val);
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _isScanning = !_isScanning),
                            icon: Icon(
                              _isScanning ? Icons.keyboard_rounded : Icons.qr_code_scanner_rounded,
                              size: 20,
                              color: context.onSurface,
                            ),
                            label: Text(
                              _isScanning ? AppLocalizations.of(context)!.typeCode : AppLocalizations.of(context)!.scanQr,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 0.5,
                                color: context.onSurface,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: context.borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              foregroundColor: context.onSurface,
                              backgroundColor: context.cardColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator(color: AppTheme.primaryGreen)
              else
                Text(
                  AppLocalizations.of(context)!.codeValidityNote,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.subText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
