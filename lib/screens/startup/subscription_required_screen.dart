import 'package:flutter/material.dart';
import '../subscription/subscription_paywall_screen.dart';

class SubscriptionRequiredScreen extends StatelessWidget {
  const SubscriptionRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SubscriptionPaywallScreen(isDismissible: false);
  }
}
