import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/subscription.dart';
import '../../providers/subscription_provider.dart';
import '../../services/subscription_service.dart';
import '../../widgets/animate_in.dart';
import '../../widgets/app_card.dart';
import '../subscription/subscription_paywall_screen.dart';

class SubscriptionSettingsScreen extends ConsumerStatefulWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  ConsumerState<SubscriptionSettingsScreen> createState() => _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState extends ConsumerState<SubscriptionSettingsScreen> {
  bool _isRestoring = false;

  static const String _playStoreSubUrl =
      'https://play.google.com/store/account/subscriptions?sku=${SubscriptionService.premiumMonthlyId}&package=lk.unio.quickbillpos';
  static const String _termsUrl = 'https://quickbillpos.com/terms';
  static const String _privacyUrl = 'https://quickbillpos.com/privacy';

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);
    try {
      final success = await SubscriptionService.instance.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Synced with Google Play. Active purchases restored.'
                : 'Unable to connect to Google Play store.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final subscription = subscriptionAsync.value;

    final isTrial = subscription?.isTrialActive ?? false;
    final isValid = subscription?.isValid ?? false;
    final status = subscription?.status ?? SubscriptionStatus.expired;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription & Billing'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Plan Status Banner
          AnimateIn(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isValid
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFF7F1D1D), const Color(0xFF450A0A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isTrial
                              ? AppTheme.primaryGreen
                              : (isValid ? AppTheme.primaryBlue : Colors.red),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isTrial
                              ? 'FREE TRIAL'
                              : (isValid ? 'ACTIVE' : 'EXPIRED'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.amber,
                        size: 28,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'QuickBill Premium',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTrial
                        ? '1-Month Free Trial via Google Play'
                        : (isValid ? 'Monthly Auto-Renewing Subscription' : 'Subscription Expired'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Details Card
          AnimateIn(
            delay: const Duration(milliseconds: 100),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Status',
                    _formatStatus(status, isTrial),
                    Icons.info_outline,
                  ),
                  const Divider(height: 24),
                  if (subscription?.expiryDate != null) ...[
                    _buildDetailRow(
                      isTrial ? 'Trial Ends' : 'Next Renewal Date',
                      DateFormat('dd MMM yyyy, hh:mm a').format(subscription!.expiryDate!.toLocal()),
                      Icons.event_rounded,
                    ),
                    const Divider(height: 24),
                  ],
                  if (isTrial) ...[
                    _buildDetailRow(
                      'Trial Days Remaining',
                      '${subscription?.trialDaysRemaining ?? 0} days',
                      Icons.timelapse_rounded,
                    ),
                    const Divider(height: 24),
                  ],
                  _buildDetailRow(
                    'Platform',
                    'Google Play Billing',
                    Icons.shop_rounded,
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Billing Cycle',
                    'Monthly Auto-Renewing',
                    Icons.autorenew_rounded,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          AnimateIn(
            delay: const Duration(milliseconds: 150),
            child: Column(
              children: [
                if (!isValid) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionPaywallScreen(isDismissible: true),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.flash_on_rounded),
                    label: const Text(
                      'Subscribe Now with Google Play',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: () => _launchUrl(_playStoreSubUrl),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Manage or Cancel on Google Play'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isRestoring ? null : _restorePurchases,
                  icon: _isRestoring
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.restore_rounded),
                  label: const Text('Restore Purchases'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Legal & Support Links
          AnimateIn(
            delay: const Duration(milliseconds: 200),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () => _launchUrl(_termsUrl),
                  child: const Text(
                    'Terms of Service',
                    style: TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.underline),
                  ),
                ),
                const Text(' • ', style: TextStyle(color: Colors.grey)),
                InkWell(
                  onTap: () => _launchUrl(_privacyUrl),
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _formatStatus(SubscriptionStatus status, bool isTrial) {
    if (isTrial) return 'Active (Free Trial)';
    switch (status) {
      case SubscriptionStatus.active:
        return 'Active (Auto-Renewing)';
      case SubscriptionStatus.cancelled:
        return 'Cancelled (Active until period ends)';
      case SubscriptionStatus.inGracePeriod:
        return 'Payment Issue (Grace Period)';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.paused:
        return 'Paused';
      case SubscriptionStatus.trial:
        return 'Free Trial';
    }
  }

  Widget _buildDetailRow(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
