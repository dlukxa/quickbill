import re

file_path = '/Users/dlukxa/Development/projects/POS/quickbill/lib/screens/billing/billing_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

# We'll replace the method signature and the block where ListView/GridView is used.
pattern = re.compile(
    r"  Widget _buildSmallInventoryGrid\(List<Product> products, Color cardColor, Color border, Color textColor, Color subColor\) \{.*?(?=  Widget _buildCartArea)",
    re.DOTALL
)

corrected = """  Widget _buildSmallInventoryGrid(List<Product> products, Color cardColor, Color border, Color textColor, Color subColor, {bool isFullGrid = false}) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: Column(
        mainAxisSize: isFullGrid ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grid_view_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 5),
                      Text('Quick Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('Tap to add', style: TextStyle(color: subColor, fontSize: 12)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isQuickMenuExpanded = !_isQuickMenuExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: subColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isQuickMenuExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      size: 16,
                      color: subColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => QuickMenuSettingsSheet.show(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: subColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tune_rounded, size: 16, color: subColor),
                  ),
                ),
              ],
            ),
          ),
          if (_isQuickMenuExpanded)
            if (isFullGrid)
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return _buildQuickMenuItem(products[index], cardColor, border, textColor, subColor);
                  },
                ),
              )
            else
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: 120,
                      child: _buildQuickMenuItem(products[index], cardColor, border, textColor, subColor),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildQuickMenuItem(Product product, Color cardColor, Color border, Color textColor, Color subColor) {
    final stock = product.trackBatches ? product.calculatedStock : product.stock;
    final inStock = stock > 0;
    
    return GestureDetector(
      onTap: inStock ? () async {
        HapticFeedback.lightImpact();
        if (product.trackBatches) {
          final selectedBatch = await BatchSelectionSheet.show(context, product);
          if (selectedBatch == null) return;
          ref.read(cartProvider.notifier).addProduct(product, batch: selectedBatch);
        } else {
          ref.read(cartProvider.notifier).addProduct(product);
        }
        final discountRule = ref.read(discountsProvider.notifier).getActiveDiscountSync(product.id!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(discountRule != null
                ? '${product.name} added (${discountRule.discountType == 'percentage' ? '${discountRule.discountValue}% OFF' : 'Rs.${discountRule.discountValue} OFF'})'
                : '${product.name} added to cart'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: discountRule != null ? AppTheme.primaryGreen : null,
          ));
        }
      } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: inStock ? cardColor : cardColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inStock ? AppTheme.primaryGreen.withValues(alpha: 0.35) : border,
            width: 1.5,
          ),
          boxShadow: inStock ? [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: product.imageUrl != null
                        ? CachedProductImage(
                            imageUrl: product.imageUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: _buildFallbackCategoryIcon(product.category, double.infinity, 28),
                          )
                        : _buildFallbackCategoryIcon(product.category, double.infinity, 28),
                  ),
                  if (!inStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: const Center(
                          child: Text('OUT', textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Name + price
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: inStock ? textColor : subColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            Formatters.currency(product.price),
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (inStock)
                          Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 13),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

"""

new_content = re.sub(pattern, corrected, content)
with open(file_path, 'w') as f:
    f.write(new_content)
