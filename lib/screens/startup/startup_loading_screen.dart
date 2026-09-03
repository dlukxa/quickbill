import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import '../../providers/preference_provider.dart';
import '../../providers/employee_provider.dart';
import '../../firebase_options.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../services/database_service.dart';
import '../../services/backup_service.dart';
import '../../widgets/cloud_backups_sheet.dart';
import 'package:intl/intl.dart';
import '../../services/update_service.dart';
import 'update_required_screen.dart';
import '../../services/subscription_service.dart';
import '../../services/remote_config_service.dart';
import 'subscription_required_screen.dart';
import '../subscription/subscription_paywall_screen.dart';
import '../../services/pdf_service.dart';
class StartupLoadingScreen extends ConsumerStatefulWidget {
  final VoidCallback onInitializationComplete;

  const StartupLoadingScreen({
    super.key,
    required this.onInitializationComplete,
  });

  @override
  ConsumerState<StartupLoadingScreen> createState() => _StartupLoadingScreenState();
}

class _StartupLoadingScreenState extends ConsumerState<StartupLoadingScreen> with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  String _statusMessage = 'Waking up engine...';
  String? _errorMessage;
  bool _showErrorDetails = false;
  late AnimationController _pulseController;
  
  bool _updateRequired = false;
  String _updateUrl = '';
  String _latestVersion = '';
  
  bool _subscriptionRequired = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Start the asynchronous initialization process
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runInitialization();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runInitialization() async {
    setState(() {
      _progress = 0.0;
      _statusMessage = 'Connecting to Google Cloud Services...';
      _errorMessage = null;
    });

    try {
      // 1. Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Activate Firebase App Check.
      // Uses the debug provider in debug builds (shows a debug token in the console
      // the first time — add it to the Firebase Console under App Check).
      // Uses Play Integrity on Android release builds for real protection.
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttest,
      );
      
      // Initialize Remote Config for dynamic cloud keys and flags
      await RemoteConfigService.instance.initialize();
      
      // Initialize Crashlytics for crash and ANR tracking
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      if (!mounted) return;
      setState(() {
        _progress = 0.05;
        _statusMessage = 'Checking for updates...';
      });

      // Check for forced app updates
      await UpdateService.instance.checkUpdateRequired();
      
      // Auto-login workaround for Android Emulator Keystore bug
      if (FirebaseAuth.instance.currentUser == null) {
        final prefs = await SharedPreferences.getInstance();
        final devEmail = prefs.getString('dev_email_cache');
        final devPass = prefs.getString('dev_password_cache');
        if (devEmail != null && devPass != null) {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(email: devEmail, password: devPass);
            debugPrint('🛡️ Dev Auto-login succeeded');
          } catch (e) {
            debugPrint('🛡️ Dev Auto-login failed: $e');
          }
        }
      }
      
      if (!mounted) return;
      setState(() {
        _progress = 0.15;
        _statusMessage = 'Establishing notification dispatcher...';
      });

      // 2. Initialize Notifications
      await NotificationService.instance.init().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );

      if (!mounted) return;
      setState(() {
        _progress = 0.50;
        _statusMessage = 'Warming up services...';
      });

      // 3. Pre-load PDF fonts
      await PdfService.instance.preWarmFonts().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );

      if (!mounted) return;
      setState(() {
        _progress = 0.60;
        _statusMessage = 'Synchronizing user settings...';
      });

      // 4. Initialize Local Preferences/Settings
      await ref.read(settingsProvider.notifier).init().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );

      if (!mounted) return;
      setState(() {
        _progress = 0.70;
        _statusMessage = 'Validating POS terminal profile...';
      });

      // 5. Initialize Staff device configurations
      await ref.read(isStaffDeviceProvider.notifier).init().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );


      if (!mounted) return;
      setState(() {
        _progress = 0.85;
        _statusMessage = 'Verifying active subscription...';
      });

      // 6. Verify Subscription Status (Only if logged in)
      if (FirebaseAuth.instance.currentUser != null) {
        await SubscriptionService.instance.checkSubscriptionAccess().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      }

      if (!mounted) return;
      setState(() {
        _progress = 1.0;
        _statusMessage = 'System Ready';
      });

      // Brief delay to show 100% progress state
      await Future.delayed(const Duration(milliseconds: 400));
      
      if (mounted) {
        widget.onInitializationComplete();
      }
    } on UpdateRequiredException catch (e) {
      if (mounted) {
        setState(() {
          _updateRequired = true;
          _updateUrl = e.updateUrl;
          _latestVersion = e.latestVersion;
        });
      }
    } on SubscriptionExpiredException catch (e) {
      if (mounted) {
        setState(() {
          _subscriptionRequired = true;
        });
      }
    } catch (e) {
      debugPrint('QuickBill Startup Exception: $e');
      if (mounted) {
        setState(() {
          _progress = 0.0;
          _statusMessage = 'Initialization Failed';
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<dynamic> _showRestoreOptionsDialog(List<Map<String, dynamic>> backups) async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subTextColor = isDark ? Colors.white60 : const Color(0xFF475569);
        final cardColor = isDark ? const Color(0xFF151D30) : Colors.white;
        final borderColor = isDark ? const Color(0xFF263554) : const Color(0xFFE2E8F0);

        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: borderColor),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings_backup_restore_rounded,
                  color: AppTheme.primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Restore Business Data?',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We detected a fresh installation. You can restore your data from a cloud backup, sync live data, or start fresh.',
                  style: GoogleFonts.plusJakartaSans(
                    color: subTextColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                if (backups.isNotEmpty) ...[
                  Text(
                    'Available Cloud Backups (Select to Download):',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: backups.length,
                        itemBuilder: (context, index) {
                          final backup = backups[index];
                          final date = backup['created'] as DateTime;
                          final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(date);
                          final sizeStr = BackupService.instance.formatSize(backup['size'] as int);

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: const Icon(Icons.cloud_download_rounded, color: AppTheme.primaryBlue),
                            title: Text(
                              dateStr,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'Size: $sizeStr',
                              style: GoogleFonts.plusJakartaSans(
                                color: subTextColor,
                                fontSize: 11,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                            onTap: () => Navigator.pop(context, backup),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      border: Border.all(color: Colors.amber.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No cloud backups found for your account.',
                            style: GoogleFonts.plusJakartaSans(
                              color: isDark ? Colors.amber[200] : Colors.amber[800],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Alternatives:',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowButtonSpacing: 8,
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, 'sync'),
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: const Text('Sync Latest Data'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: BorderSide(color: subTextColor.withOpacity(0.3)),
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, 'fresh'),
              child: const Text('Start Fresh (Empty DB)'),
            ),
          ],
        );
      },
    );
    return result ?? 'fresh';
  }

  @override
  Widget build(BuildContext context) {
    if (_updateRequired) {
      return UpdateRequiredScreen(
        updateUrl: _updateUrl,
        latestVersion: _latestVersion,
      );
    }
    
    if (_subscriptionRequired) {
      return const SubscriptionPaywallScreen(isDismissible: false);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Cyber-dark styling palette
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF151D30) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white60 : const Color(0xFF475569);
    final borderColor = isDark ? const Color(0xFF263554) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Elegant subtle gradient mesh in the background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: 1.2 + (_pulseController.value * 0.1),
                      colors: [
                        AppTheme.primaryGreen.withOpacity(isDark ? 0.08 : 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsating app logo icon
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGreen.withOpacity(0.15 * _pulseController.value),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 64,
                              height: 64,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      // App Name
                      Text(
                        'QuickBill POS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Intelligent Retail Suite',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: subTextColor,
                        ),
                      ),
                      
                      const SizedBox(height: 40),

                      if (_errorMessage == null) ...[
                        // Dynamic progress text
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _statusMessage,
                            key: ValueKey(_statusMessage),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Premium smooth progress bar
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 6,
                              width: MediaQuery.of(context).size.width * 0.7 * _progress,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryGreen.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Percentage ticker
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ] else ...[
                        // Error Panel
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.errorRed.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Startup failed to complete.',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.errorRed,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'A service failed to respond. This is usually caused by missing Google services credentials or lack of connection during initial load.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: subTextColor,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Technical details accordion
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showErrorDetails = !_showErrorDetails;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _showErrorDetails ? 'Hide details' : 'Show details',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: subTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Icon(
                                  _showErrorDetails ? Icons.expand_less : Icons.expand_more,
                                  color: subTextColor,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        if (_showErrorDetails) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 12,
                                  color: AppTheme.errorRed,
                                ),
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 28),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppTheme.errorRed.withOpacity(0.5)),
                                  foregroundColor: AppTheme.errorRed,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () {
                                  // Skip / Proceed offline override
                                  widget.onInitializationComplete();
                                },
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Skip / Offline'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: _runInitialization,
                                icon: const Icon(Icons.replay_rounded),
                                label: const Text('Retry Startup'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
