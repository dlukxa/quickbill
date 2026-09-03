import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../providers/employee_provider.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../widgets/animate_in.dart';
import '../../widgets/gradient_button.dart';

class SubscriptionPaywallScreen extends ConsumerStatefulWidget {
  final bool isDismissible;
  const SubscriptionPaywallScreen({super.key, this.isDismissible = false});

  @override
  ConsumerState<SubscriptionPaywallScreen> createState() => _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends ConsumerState<SubscriptionPaywallScreen> {
  bool _isLoadingProduct = true;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  String? _errorMessage;
  ProductDetails? _product;

  static const String _playStoreSubUrl =
      'https://play.google.com/store/account/subscriptions?sku=${SubscriptionService.premiumMonthlyId}&package=lk.unio.quickbillpos';
  static const String _termsUrl = 'https://quickbillpos.com/terms';
  static const String _privacyUrl = 'https://quickbillpos.com/privacy';

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoadingProduct = true;
      _errorMessage = null;
    });

    try {
      final product = await SubscriptionService.instance.getPrimaryProduct();
      if (mounted) {
        setState(() {
          _product = product;
          _isLoadingProduct = false;
          if (product == null) {
            _errorMessage = 'Could not load subscription details from Google Play. Please check your internet connection.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProduct = false;
          _errorMessage = 'Failed to connect to Google Play Billing: $e';
        });
      }
    }
  }

  Future<void> _startFreeTrial() async {
    if (_product == null) return;

    setState(() => _isPurchasing = true);
    try {
      await SubscriptionService.instance.buySubscription(_product!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);
    try {
      final success = await SubscriptionService.instance.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Checking Google Play for previous purchases...'
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

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Get dynamic formatted price from Google Play
  String _getFormattedPrice() {
    if (_product == null) return '';
    return _product!.price;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF151E33) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF24324F) : const Color(0xFFE2E8F0);

    final formattedPrice = _getFormattedPrice();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: widget.isDismissible
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.close, color: textColor),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimateIn(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Header Icon
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryBlue, AppTheme.primaryPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      'QuickBill Premium',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Free Trial Highlight Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, color: AppTheme.primaryGreen, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '1 MONTH FREE TRIAL',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryGreen,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dynamic Subtitle
                    Text(
                      formattedPrice.isNotEmpty
                          ? 'Enjoy 30 days completely free. Then $formattedPrice / month.'
                          : 'Enjoy 30 days free. Then continue with an auto-renewing monthly subscription.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: subTextColor,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Plan Details & Feature Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Everything Included',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              if (_isLoadingProduct)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else if (formattedPrice.isNotEmpty)
                                Text(
                                  '$formattedPrice/mo',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureRow('Unlimited POS Billing & Invoicing', textColor),
                          _buildFeatureRow('Real-time Cloud Sync & Multi-Device', textColor),
                          _buildFeatureRow('Automated Cloud Data Backups', textColor),
                          _buildFeatureRow('Inventory, Stock & Batch Tracking', textColor),
                          _buildFeatureRow('Profit & Loss and Tax Reports', textColor),
                          _buildFeatureRow('Thermal Printer & Barcode Support', textColor),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error display if store load fails
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.red, size: 18),
                              onPressed: _loadProductDetails,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Primary Action Button (Start Free Trial)
                    GradientButton(
                      onPressed: (_isLoadingProduct || _isPurchasing) ? null : _startFreeTrial,
                      colors: [AppTheme.primaryBlue, AppTheme.primaryPurple],
                      child: _isPurchasing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Connecting to Google Play...'),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.flash_on_rounded, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  formattedPrice.isNotEmpty
                                      ? 'Start 1-Month Free Trial'
                                      : 'Subscribe with Google Play',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Secondary Actions: Restore Purchases & Manage Subscription
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _isRestoring ? null : _restorePurchases,
                          icon: _isRestoring
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.restore_rounded, size: 18),
                          label: Text(
                            'Restore Purchases',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: subTextColor,
                            ),
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                        TextButton(
                          onPressed: () => _launchExternalUrl(_playStoreSubUrl),
                          child: Text(
                            'Manage on Google Play',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: subTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Google Play Compliance Disclosures
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Subscription Terms & Auto-Renewal',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your subscription begins with a 1-month free trial. At the end of the trial period, Google Play will automatically charge the monthly subscription price of $formattedPrice (or local currency rate) to your Google Play payment method unless cancelled at least 24 hours before the trial ends. You can cancel or modify your subscription at any time in Google Play Settings > Subscriptions.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: subTextColor,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Legal Links (Terms & Privacy)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => _launchExternalUrl(_termsUrl),
                          child: Text(
                            'Terms of Service',
                            style: TextStyle(
                              fontSize: 12,
                              color: subTextColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () => _launchExternalUrl(_privacyUrl),
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 12,
                              color: subTextColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sign Out Option (For staff switching / multi-account)
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(AppLocalizations.of(context)?.signOut ?? 'Sign Out'),
                            content: const Text('Are you sure you want to sign out?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          ref.invalidate(isStaffDeviceProvider);
                          await AuthService.instance.signOut();
                        }
                      },
                      icon: const Icon(Icons.logout, size: 16, color: Colors.grey),
                      label: const Text(
                        'Sign Out of Account',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppTheme.primaryGreen,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
