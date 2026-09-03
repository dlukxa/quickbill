import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animate_in.dart';
import '../../providers/preference_provider.dart';
import '../../providers/employee_provider.dart';
import '../../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'staff_login_screen.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../widgets/language_selector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final deviceId = await ref.read(deviceIdProvider.future);
      await auth.signInWithGoogle(deviceId);
      await ref.read(isStaffDeviceProvider.notifier).setStaffDevice(false);
      // Success handled by authStateProvider
    } catch (e) {
      if (mounted && e.toString() != 'Exception: Google sign-in cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    final auth = ref.read(authServiceProvider);

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.fillAllFields)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        final deviceId = await ref.read(deviceIdProvider.future);
        await auth.signIn(_emailController.text.trim(), _passwordController.text.trim(), deviceId);
        await ref.read(isStaffDeviceProvider.notifier).setStaffDevice(false);
      } else {
        // Clear any stale local data before creating a new account 
        // to prevent inheriting a previous session's state (e.g. if the user was deleted from Firebase Console).
        try {
          await DatabaseService.instance.clearAllData();
        } catch (e) {
          debugPrint('Error clearing DB before signup: $e');
        }
        final prefs = await SharedPreferences.getInstance();
        final currentDeviceId = prefs.getString('device_unique_id');
        await prefs.clear();
        if (currentDeviceId != null) {
          await prefs.setString('device_unique_id', currentDeviceId);
        }
        // Refresh the settings provider so it knows we wiped everything
        await ref.read(settingsProvider.notifier).init();
        
        // INVALIDATE cached providers so they don't hold onto the old session's data
        ref.invalidate(currentEmployeeProvider);
        ref.invalidate(activeShopUidProvider);

        final deviceId = await ref.read(deviceIdProvider.future);
        await auth.signUp(_emailController.text.trim(), _passwordController.text.trim(), deviceId);
        await ref.read(isStaffDeviceProvider.notifier).setStaffDevice(false);
        if (_phoneController.text.isNotEmpty) {
          // Do not await this, as it triggers a cloud sync which may hang on slow networks.
          // We want the user to proceed immediately to the setup screen.
          ref.read(settingsProvider.notifier).updateShopPhone(_phoneController.text.trim());
        }
      }
      // Success handled by authStateProvider in main.dart
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        String message = l10n.authFailed;
        if (e.code == 'invalid-credential' ||
            e.code == 'user-not-found' ||
            e.code == 'wrong-password') {
          message = l10n.invalidPin;
        } else if (e.code == 'operation-not-allowed') {
          message = 'This login method is currently disabled. Please contact support.';
        } else {
          message = e.message ?? l10n.authFailed;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(20),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimateIn(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: context.borderColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                AnimateIn(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    _isLogin
                        ? AppLocalizations.of(context)!.welcomeBack
                        : AppLocalizations.of(context)!.createAccount,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: context.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                AnimateIn(
                  delay: const Duration(milliseconds: 150),
                  child: Text(
                    _isLogin
                        ? AppLocalizations.of(context)!.signInPrompt
                        : AppLocalizations.of(context)!.signUpPrompt,
                    style: GoogleFonts.plusJakartaSans(
                      color: context.subText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // ─── STAFF DEVICE LINK — Primary option for cashier tablets ───
                AnimateIn(
                  delay: const Duration(milliseconds: 175),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StaffLoginScreen()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: AppTheme.primaryGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.staffLogin,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cashier or staff? Scan QR or enter link code',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: context.subText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: AppTheme.primaryGreen.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Divider separating staff link from owner login form
                AnimateIn(
                  delay: const Duration(milliseconds: 195),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: context.borderColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OWNER LOGIN',
                          style: TextStyle(
                            color: context.subText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.borderColor)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AnimateIn(
                  delay: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: context.onSurface),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.email,
                            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_isLogin) ...[
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(color: context.onSurface),
                            decoration: const InputDecoration(
                              labelText: 'Phone (optional)',
                              prefixIcon: Icon(Icons.phone_rounded, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: TextStyle(color: context.onSurface),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.password,
                            prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : GradientButton(
                                colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.8)],
                                onPressed: _handleSubmit,
                                width: double.infinity,
                                child: Text(
                                  _isLogin
                                      ? AppLocalizations.of(context)!.logIn
                                      : AppLocalizations.of(context)!.signUp,
                                ),
                              ),
                        const SizedBox(height: 24),
                        // OR divider
                        Row(children: [
                          Expanded(child: Divider(color: context.borderColor)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OR', style: TextStyle(color: context.subText, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(child: Divider(color: context.borderColor)),
                        ]),
                        const SizedBox(height: 16),
                        // Google button
                        _isGoogleLoading
                            ? const CircularProgressIndicator()
                            : ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 400),
                                child: OutlinedButton.icon(
                                  onPressed: _handleGoogleSignIn,
                                  icon: Image.asset(
                                    'assets/icons/google_logo.webp',
                                    width: 20,
                                    height: 20,
                                  ),
                                  label: Text(
                                    'Continue with Google',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w600,
                                      color: context.onSurface,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    side: BorderSide(color: context.borderColor),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    backgroundColor: context.cardColor,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimateIn(
                  delay: const Duration(milliseconds: 250),
                  child: TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? AppLocalizations.of(context)!.newHerePrompt
                          : AppLocalizations.of(context)!.backToLogin,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          top: 16,
          right: 16,
          child: LanguageSelector(),
        ),
      ],
    ),
  ),
);
  }
}
