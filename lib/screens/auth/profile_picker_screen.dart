import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../main.dart';
import '../../providers/employee_provider.dart';
import '../../widgets/animate_in.dart';
import '../../models/employee.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../services/sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePickerScreen extends ConsumerWidget {
  final Future<void> Function()? onSignOut;

  const ProfilePickerScreen({super.key, this.onSignOut});

  // ─────────────────────────────────────────────────────
  // Disconnect / Sign Out / Unlink handler
  // ─────────────────────────────────────────────────────
  Future<void> _handleSignOutOrUnlink(BuildContext context, WidgetRef ref) async {
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final isStaffDevice = ref.read(isStaffDeviceProvider);
    final l10n = AppLocalizations.of(context);

    final title = isDesktop
        ? 'Disconnect POS Terminal'
        : (isStaffDevice ? 'Unlink This Device' : (l10n?.signOut ?? 'Sign Out'));

    final content = isDesktop
        ? 'Are you sure you want to disconnect this terminal? You will return to the shop connection screen.'
        : (isStaffDevice
            ? 'Are you sure you want to unlink this device from the shop? All local data will be cleared.'
            : (l10n?.localeName == 'si'
                ? 'ඔබට විශ්වාසද ඉවත් වීමට අවශ්‍ය බව?'
                : l10n?.localeName == 'ta'
                    ? 'நீங்கள் வெளியேற விரும்புகிறீர்களா?'
                    : l10n?.localeName == 'hi'
                        ? 'क्या आप साइन आउट करना चाहते हैं?'
                        : l10n?.localeName == 'bn'
                            ? 'আপনি কি সাইন আউট করতে চান?'
                            : l10n?.localeName == 'dv'
                                ? 'ސައިން އައުޓް ކުރަންވީތޯ؟'
                                : 'Are you sure you want to sign out?'));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          content,
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isDesktop ? 'Disconnect' : (l10n?.signOut ?? 'Sign Out')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    if (onSignOut != null) {
      await onSignOut!();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('desktop_shop_uid');
    await prefs.remove('active_shop_uid');
    await prefs.remove('current_employee_id');
    await prefs.setBool('is_staff_device', false);
    await ref.read(isStaffDeviceProvider.notifier).setStaffDevice(false);
    await ref.read(currentEmployeeProvider.notifier).logout();
    await AuthService.instance.signOut();

    if (context.mounted) {
      RestartWidget.restartApp(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeList = ref.watch(employeeListProvider);
    final currentEmployeeAsync = ref.watch(currentEmployeeProvider);
    final isStaffDevice = ref.watch(isStaffDeviceProvider);
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.scaffoldColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(syncServiceProvider).syncEssentialData();
              await DatabaseService.instance.ensureOwnerExists(1);
              ref.invalidate(employeeListProvider);
            },
            icon: Icon(Icons.sync_rounded, color: context.onSurface.withValues(alpha: 0.5)),
            tooltip: 'Sync Profiles',
          ),
          IconButton(
            onPressed: () => _handleSignOutOrUnlink(context, ref),
            icon: Icon(
              isStaffDevice ? Icons.link_off_rounded : Icons.logout_rounded,
              color: isStaffDevice ? Colors.orange : Colors.red,
            ),
            tooltip: isDesktop
                ? 'Disconnect POS Terminal'
                : (isStaffDevice ? 'Unlink Device' : (l10n?.signOut ?? 'Sign Out')),
          ),
          const SizedBox(width: 8),
        ],
      ),

      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                AnimateIn(
                  child: Text(
                    l10n?.whoAreYou ?? 'Who are you?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: context.onSurface,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimateIn(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    l10n?.selectProfilePrompt ?? 'Select your profile to continue',
                    style: GoogleFonts.plusJakartaSans(
                      color: context.subText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                Expanded(
                  child: employeeList.when(
                    data: (employees) {
                      final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
                      // On Desktop POS, or if user is authenticated as owner, or if no other profiles exist, always show owner
                      final showOwner = isDesktop ||
                          !isAnonymous ||
                          !isStaffDevice ||
                          employees.every((e) => e.role == EmployeeRole.owner);

                      final displayEmployees = showOwner
                          ? employees
                          : employees.where((e) => e.role != EmployeeRole.owner).toList();

                      if (displayEmployees.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_rounded, size: 64, color: context.borderColor),
                              const SizedBox(height: 16),
                              Text(
                                l10n?.noProfilesFound ?? 'No Profiles Found',
                                style: GoogleFonts.plusJakartaSans(
                                  color: context.subText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await DatabaseService.instance.ensureOwnerExists(1);
                                      ref.invalidate(employeeListProvider);
                                    },
                                    icon: const Icon(Icons.person_add_rounded),
                                    label: const Text('Add Default Profiles (PIN: 1234)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await ref.read(syncServiceProvider).syncEssentialData();
                                      await DatabaseService.instance.ensureOwnerExists(1);
                                      ref.invalidate(employeeListProvider);
                                    },
                                    icon: const Icon(Icons.cloud_download_rounded),
                                    label: const Text('Sync Profiles from Cloud'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryGreen,
                                      side: const BorderSide(color: AppTheme.primaryGreen),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: displayEmployees.length,
                        itemBuilder: (context, index) {
                          final employee = displayEmployees[index];
                          return _ProfileCard(employee: employee);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),
          // Loading Overlay for selection
          if (currentEmployeeAsync.isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryGreen),
                    SizedBox(height: 16),
                    Text(
                      'Signing in...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  final Employee employee;

  const _ProfileCard({required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = employee.rawRole == EmployeeRole.owner;
    final l10n = AppLocalizations.of(context);

    return AnimateIn(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {

             try {
               await ref.read(currentEmployeeProvider.notifier).selectEmployee(employee);
             } catch (e) {
               if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
                 );
               }
             }
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.onSurface.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOwner ? Icons.shield_rounded : Icons.person_rounded,
                    size: 32,
                    color: isOwner ? context.onSurface : AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  employee.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: context.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isOwner ? (l10n?.owner ?? 'Owner') : (l10n?.staff ?? 'Staff'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.subText,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
