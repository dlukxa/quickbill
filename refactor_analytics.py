import re

with open('lib/screens/reports/analytics_dashboard_screen.dart', 'r') as f:
    content = f.read()

build_method_pattern = re.compile(r'(Widget build\(BuildContext context, WidgetRef ref\) \{.*?RefreshIndicator\(\s*onRefresh:.*?child: ListView\(\s*padding: const EdgeInsets\.all\(16\),\s*children: \[)(.*?)(\s*const SizedBox\(height: 40\),\s*],\s*\),\s*\),\s*\);\s*})', re.DOTALL)

build_start, children_content, build_end = build_method_pattern.search(content).groups()

# Extract Net Profit & Margins
summary_section = re.search(r'// Net Profit & Margins(.*?)const SizedBox\(height: 24\),', children_content, re.DOTALL).group(0)
# Extract AI Predictor Insights
ai_insights = re.search(r'// AI Predictor Insights(.*?)const SizedBox\(height: 24\),', children_content, re.DOTALL).group(0)
# Extract Profit Waterfall
waterfall = re.search(r'// Profit Waterfall \(Visual Breakdown\)(.*?)const SizedBox\(height: 24\),', children_content, re.DOTALL).group(0)
# Extract Profit Trend Chart
trend_chart = re.search(r'// Profit Trend Chart(.*?)const SizedBox\(height: 24\),', children_content, re.DOTALL).group(0)
# Extract Top Profitable Categories
cat_profit = re.search(r'// Top Profitable Categories(.*?)const SizedBox\(height: 24\),', children_content, re.DOTALL).group(0)
# Extract Top Profitable Products
top_products = re.search(r'// Top Profitable Products(.*)', children_content, re.DOTALL).group(0)

new_build_children = """
            // Net Profit & Margins
            _buildSummaryCard(context, summaryAsync),
            const SizedBox(height: 24),
            
            if (isTablet)
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAIInsightsSection(l10n, ref),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWaterfallSection(l10n, summaryAsync, context),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfitTrendSection(l10n, trendsAsync),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCategoryProfitSection(l10n, categoryAsync, context),
                            const SizedBox(height: 24),
                            _buildTopProductsSection(l10n, topProfitableAsync, context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAIInsightsSection(l10n, ref),
                  const SizedBox(height: 24),
                  _buildWaterfallSection(l10n, summaryAsync, context),
                  const SizedBox(height: 24),
                  _buildProfitTrendSection(l10n, trendsAsync),
                  const SizedBox(height: 24),
                  _buildCategoryProfitSection(l10n, categoryAsync, context),
                  const SizedBox(height: 24),
                  _buildTopProductsSection(l10n, topProfitableAsync, context),
                ],
              ),
"""

helpers = f"""
  Widget _buildSummaryCard(BuildContext context, AsyncValue<Map<String, dynamic>> summaryAsync) {{
    return {summary_section.replace('// Net Profit & Margins', '').replace('const SizedBox(height: 24),', '').strip()};
  }}

  Widget _buildAIInsightsSection(AppLocalizations l10n, WidgetRef ref) {{
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        {ai_insights.replace('// AI Predictor Insights', '').replace('const SizedBox(height: 24),', '').strip()}
      ],
    );
  }}

  Widget _buildWaterfallSection(AppLocalizations l10n, AsyncValue<Map<String, dynamic>> summaryAsync, BuildContext context) {{
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        {waterfall.replace('// Profit Waterfall (Visual Breakdown)', '').replace('const SizedBox(height: 24),', '').strip()}
      ],
    );
  }}

  Widget _buildProfitTrendSection(AppLocalizations l10n, AsyncValue<List<dynamic>> trendsAsync) {{
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        {trend_chart.replace('// Profit Trend Chart', '').replace('const SizedBox(height: 24),', '').strip()}
      ],
    );
  }}

  Widget _buildCategoryProfitSection(AppLocalizations l10n, AsyncValue<List<dynamic>> categoryAsync, BuildContext context) {{
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        {cat_profit.replace('// Top Profitable Categories', '').replace('const SizedBox(height: 24),', '').strip()}
      ],
    );
  }}

  Widget _buildTopProductsSection(AppLocalizations l10n, AsyncValue<List<dynamic>> topProfitableAsync, BuildContext context) {{
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        {top_products.replace('// Top Profitable Products', '').strip()}
      ],
    );
  }}
"""

new_build_method = build_start.replace('final l10n = AppLocalizations.of(context)!;', 'final l10n = AppLocalizations.of(context)!;\\n    final isTablet = MediaQuery.sizeOf(context).width >= 720;') + new_build_children + build_end + helpers

content = content.replace(build_start + children_content + build_end, new_build_method)

with open('lib/screens/reports/analytics_dashboard_screen.dart', 'w') as f:
    f.write(content)
