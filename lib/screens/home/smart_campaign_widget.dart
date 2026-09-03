import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/customer_insights_provider.dart';
import '../../widgets/app_card.dart';
import '../customers/customer_list_screen.dart';

class SmartCampaignWidget extends ConsumerWidget {
  const SmartCampaignWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(customerInsightsProvider);

    return insightsAsync.when(
      data: (insights) {
        // 1. Identify Opportunities
        final atRiskCount = insights.where((i) => i.segment == CustomerSegment.atRisk).length;
        final bigSpenderCount = insights.where((i) => i.segment == CustomerSegment.bigSpender).length;
        final newCustomerCount = insights.where((i) => i.segment == CustomerSegment.recent).length;

        if (atRiskCount == 0 && bigSpenderCount == 0 && newCustomerCount == 0) {
          return const SizedBox.shrink();
        }

        // 2. Select the most important insight to show
        String title = '';
        String message = '';
        IconData icon = Icons.lightbulb;
        Color color = AppTheme.primaryBlue;
        CustomerSegment targetSegment = CustomerSegment.regular; // Default

        if (atRiskCount > 0) {
          title = 'Retention Alert';
          message = '$atRiskCount VIP customers haven\'t visited in 45+ days.';
          icon = Icons.warning_amber_rounded;
          color = AppTheme.warningOrange;
          targetSegment = CustomerSegment.atRisk;
        } else if (bigSpenderCount > 0) {
          title = 'High Value Opportunity';
          message = 'You have $bigSpenderCount new Big Spenders. Send a thank you?';
          icon = Icons.diamond_outlined;
          color = AppTheme.primaryGreen;
          targetSegment = CustomerSegment.bigSpender;
        } else {
          title = 'New Growth';
          message = '$newCustomerCount new customers this month. Turn them into regulars!';
          icon = Icons.spa_outlined;
          color = Colors.teal;
          targetSegment = CustomerSegment.recent;
        }

        return Column(
          children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              color: color,
              onTap: () {
                // Pre-select the filter and navigate
                ref.read(customerSegmentFilterProvider.notifier).state = targetSegment;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerListScreen()),
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
