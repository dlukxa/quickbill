import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animate_in.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../providers/employee_provider.dart';

class DeviceRestrictedScreen extends ConsumerWidget {
  const DeviceRestrictedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimateIn(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.devices_rounded,
                    size: 64,
                    color: Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              AnimateIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  'Account in Use',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimateIn(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'Your account is currently active on another device. Your plan allows only one active device at a time.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              AnimateIn(
                delay: const Duration(milliseconds: 300),
                child: GradientButton(
                  onPressed: () async {
                    try {
                      final deviceId = await ref.read(deviceIdProvider.future);
                      await ref.read(authServiceProvider).registerCurrentDevice(deviceId);
                      // AuthWrapper will automatically rebuild and allow access
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to switch device: $e')),
                        );
                      }
                    }
                  },
                  width: double.infinity,
                  child: const Text('Switch to this device'),
                ),
              ),
              const SizedBox(height: 16),
              AnimateIn(
                delay: const Duration(milliseconds: 350),
                child: OutlinedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(AppLocalizations.of(context)!.signOut),
                        content: Text(
                          AppLocalizations.of(context)!.localeName == 'si' ? 'ඔබට විශ්වාසද ඉවත් වීමට අවශ්‍ය බව?' :
                          AppLocalizations.of(context)!.localeName == 'ta' ? 'நீங்கள் வெளியேற விரும்புகிறீர்களா?' :
                          AppLocalizations.of(context)!.localeName == 'hi' ? 'क्या आप साइन आउट करना चाहते हैं?' :
                          AppLocalizations.of(context)!.localeName == 'bn' ? 'আপনি কি সাইন আউট করতে চান?' :
                          AppLocalizations.of(context)!.localeName == 'dv' ? 'ސައިން އައުޓް ކުރަންވީތޯ؟' :
                          'Are you sure you want to sign out?'
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: Text(AppLocalizations.of(context)!.signOut),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;

                    ref.invalidate(isStaffDeviceProvider);
                    await AuthService.instance.signOut();
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    l10n.logIn,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimateIn(
                delay: const Duration(milliseconds: 400),
                child: TextButton(
                  onPressed: () {
                    // Navigate to upgrade screen or support
                  },
                  child: Text(
                    'Upgrade Plan',
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
    );
  }
}
