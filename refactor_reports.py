import re

with open('lib/screens/reports/reports_screen.dart', 'r') as f:
    content = f.read()

# Replace build method to use helper methods and responsive layout
build_method_pattern = re.compile(r'(Widget build\(BuildContext context, WidgetRef ref\) \{.*?RefreshIndicator\(\s*onRefresh:.*?child: ListView\(\s*padding: const EdgeInsets\.all\(16\),\s*children: \[)(.*?)(\s*const SizedBox\(height: 40\), // Space at bottom\s*],\s*\),\s*\),\s*\);\s*})', re.DOTALL)

build_start, children_content, build_end = build_method_pattern.search(content).groups()

# Extract P&L Overview
pl_card = re.search(r'// P&L Overview Cards(.*?)const SizedBox\(height: 20\),', children_content, re.DOTALL).group(0)
# Extract Sales Trend Chart
sales_trend = re.search(r'// Sales Trend Chart(.*?)const SizedBox\(height: 20\),', children_content, re.DOTALL).group(0)
# Extract Sales by Category
sales_cat = re.search(r'// Sales by Category(.*?)const SizedBox\(height: 20\),', children_content, re.DOTALL).group(0)
# Extract Inventory
inv_card = re.search(r'// Inventory & Assets(.*?)const SizedBox\(height: 20\),', children_content, re.DOTALL).group(0)
# Extract Top Products
top_prod = re.search(r'// Top Products(.*?)const SizedBox\(height: 20\),', children_content, re.DOTALL).group(0)
# Extract Top Customers
top_cust = re.search(r'// Top Customers(.*?)const SizedBox\(height: 20\),', children_content, re.DOTALL).group(0)

# Extract Detailed Reports
detailed_reports = re.search(r'// Detailed Reports Section(.*)', children_content, re.DOTALL).group(0)
detailed_tiles = re.search(r'Column\(\s*children: \[(.*?)\]\s*,\s*\)', detailed_reports, re.DOTALL).group(1)

new_build_children = """
            // Period Indicator
            _buildPeriodHeader(context, dateRange, ref),
            const SizedBox(height: 12),
            // Preset Filters
            _buildPresetFilters(context, ref, dateRange),
            const SizedBox(height: 16),
            
            // P&L Overview Cards
            _buildPLCards(l10n, profitLossAsync),
            const SizedBox(height: 20),

            if (isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildSalesTrendCard(l10n, salesChartAsync),
                        const SizedBox(height: 20),
                        _buildInventoryCard(l10n, inventoryAsync),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _buildCategorySalesCard(l10n, categorySalesAsync),
                        const SizedBox(height: 20),
                        _buildTopProductsCard(l10n, topProductsAsync),
                        const SizedBox(height: 20),
                        _buildTopCustomersCard(l10n, topCustomersAsync),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildSalesTrendCard(l10n, salesChartAsync),
                  const SizedBox(height: 20),
                  _buildCategorySalesCard(l10n, categorySalesAsync),
                  const SizedBox(height: 20),
                  _buildInventoryCard(l10n, inventoryAsync),
                  const SizedBox(height: 20),
                  _buildTopProductsCard(l10n, topProductsAsync),
                  const SizedBox(height: 20),
                  _buildTopCustomersCard(l10n, topCustomersAsync),
                ],
              ),
            
            const SizedBox(height: 20),
            Text(l10n.detailedReports.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            
            if (isTablet)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _buildDetailedReportTiles(context, l10n).map((tile) {
                  return SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 32 - 12) / 2, // 2 columns
                    child: tile,
                  );
                }).toList(),
              )
            else
              Column(
                children: _buildDetailedReportTiles(context, l10n),
              ),
"""

helpers = f"""
  Widget _buildPLCards(AppLocalizations l10n, AsyncValue<Map<String, dynamic>> profitLossAsync) {{
    return {pl_card.replace('// P&L Overview Cards', '').replace('const SizedBox(height: 20),', '').strip()};
  }}

  Widget _buildSalesTrendCard(AppLocalizations l10n, AsyncValue<List<dynamic>> salesChartAsync) {{
    return {sales_trend.replace('// Sales Trend Chart', '').replace('const SizedBox(height: 20),', '').strip()};
  }}

  Widget _buildCategorySalesCard(AppLocalizations l10n, AsyncValue<List<dynamic>> categorySalesAsync) {{
    return {sales_cat.replace('// Sales by Category', '').replace('const SizedBox(height: 20),', '').strip()};
  }}

  Widget _buildInventoryCard(AppLocalizations l10n, AsyncValue<Map<String, dynamic>> inventoryAsync) {{
    return {inv_card.replace('// Inventory & Assets', '').replace('const SizedBox(height: 20),', '').strip()};
  }}

  Widget _buildTopProductsCard(AppLocalizations l10n, AsyncValue<List<dynamic>> topProductsAsync) {{
    return {top_prod.replace('// Top Products', '').replace('const SizedBox(height: 20),', '').strip()};
  }}

  Widget _buildTopCustomersCard(AppLocalizations l10n, AsyncValue<List<dynamic>> topCustomersAsync) {{
    return {top_cust.replace('// Top Customers', '').replace('const SizedBox(height: 20),', '').strip()};
  }}

  List<Widget> _buildDetailedReportTiles(BuildContext context, AppLocalizations l10n) {{
    return [
{detailed_tiles}
    ];
  }}
"""

new_build_method = build_start.replace('final l10n = AppLocalizations.of(context)!;', 'final l10n = AppLocalizations.of(context)!;\\n    final isTablet = MediaQuery.sizeOf(context).width >= 720;') + new_build_children + build_end + helpers

content = content.replace(build_start + children_content + build_end, new_build_method)

with open('lib/screens/reports/reports_screen.dart', 'w') as f:
    f.write(content)
