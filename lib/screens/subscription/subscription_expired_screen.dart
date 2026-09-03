import 'package:flutter/material.dart';
import 'subscription_paywall_screen.dart';

class SubscriptionExpiredScreen extends StatelessWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SubscriptionPaywallScreen(isDismissible: false);
  }
}
