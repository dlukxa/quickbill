import re

file_path = '/Users/dlukxa/Development/projects/POS/quickbill/lib/screens/billing/billing_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

pattern = re.compile(
    r"                      // When cart is empty, show Quick Menu at the top \(right under Quick Item button\)\n                      if \(cart\.isEmpty && _searchQuery\.isEmpty\)\n                        _buildSmallInventoryGrid\(quickMenuProducts, cardColor, border, textColor, subColor\),\n                      Expanded\(\n                        child: _searchQuery\.isNotEmpty\n                            \? _buildProductFocusArea\(searchResults, cardColor, border, textColor, subColor, l10n\)\n                            : _buildCartArea\(cart, cardColor, scaffoldBg, textColor, subColor, border\),\n                      \),\n                      // When cart has items \(or searching\), pin Quick Menu to the bottom\n                      if \(cart\.isNotEmpty \|\| _searchQuery\.isNotEmpty\)\n                        _buildSmallInventoryGrid\(quickMenuProducts, cardColor, border, textColor, subColor\),",
    re.DOTALL
)

corrected = """                      // When cart is empty, show Quick Menu at the top (right under Quick Item button)
                      if (cart.isEmpty && _searchQuery.isEmpty)
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                flex: _isQuickMenuExpanded ? 1 : 0,
                                child: _buildSmallInventoryGrid(quickMenuProducts, cardColor, border, textColor, subColor, isFullGrid: true),
                              ),
                              if (!_isQuickMenuExpanded)
                                Expanded(
                                  child: _buildCartArea(cart, cardColor, scaffoldBg, textColor, subColor, border),
                                ),
                            ],
                          ),
                        ),
                      if (!(cart.isEmpty && _searchQuery.isEmpty))
                        Expanded(
                          child: _searchQuery.isNotEmpty
                              ? _buildProductFocusArea(searchResults, cardColor, border, textColor, subColor, l10n)
                              : _buildCartArea(cart, cardColor, scaffoldBg, textColor, subColor, border),
                        ),
                      // When cart has items (or searching), pin Quick Menu to the bottom
                      if (cart.isNotEmpty || _searchQuery.isNotEmpty)
                        _buildSmallInventoryGrid(quickMenuProducts, cardColor, border, textColor, subColor, isFullGrid: false),"""

new_content = re.sub(pattern, corrected, content)
with open(file_path, 'w') as f:
    f.write(new_content)
