import re

file_path = '/Users/dlukxa/Development/projects/POS/quickbill/lib/screens/suppliers/add_purchase_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Add imports
imports_to_add = """import 'package:google_fonts/google_fonts.dart';
import '../../utils/category_icon_util.dart';
"""
if "import 'package:google_fonts/google_fonts.dart';" not in content:
    content = content.replace("import '../../widgets/cached_product_image.dart';", "import '../../widgets/cached_product_image.dart';\n" + imports_to_add)

# Replace list item
pattern = re.compile(r"                      return ListTile\(.*?\n                      \);", re.DOTALL)

new_item = """                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: p.imageUrl == null
                                  ? CategoryIconUtil.getColorForCategory(p.category).withValues(alpha: 0.15)
                                  : AppTheme.stockStatusColor(p.stockStatus).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: p.imageUrl != null
                                  ? ClipOval(
                                      child: CachedProductImage(
                                        imageUrl: p.imageUrl!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        placeholder: Icon(
                                          CategoryIconUtil.getIconForCategory(p.category),
                                          color: CategoryIconUtil.getColorForCategory(p.category),
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      CategoryIconUtil.getIconForCategory(p.category),
                                      color: CategoryIconUtil.getColorForCategory(p.category),
                                    ),
                            ),
                            title: Text(
                              p.name,
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Formatters.currency(p.price),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.stockStatusColor(p.stockStatus).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Wrap(
                                        spacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Icon(
                                            p.isOutOfStock
                                                ? Icons.cancel
                                                : p.isLowStock
                                                    ? Icons.warning
                                                    : Icons.check_circle,
                                            size: 14,
                                            color: AppTheme.stockStatusColor(p.stockStatus),
                                          ),
                                          Text(
                                            AppLocalizations.of(context)!.stockLabel(
                                              (p.trackBatches ? p.calculatedStock : p.stock).toString(),
                                              p.unit
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.stockStatusColor(p.stockStatus),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _showItemDetailInput(p);
                            },
                          ),
                        ),
                      );"""

# Replace all occurrences (supplier list is also matched? Wait!)
# Let's check supplier list tile vs product list tile
# Supplier list tile is at line 331, product is at line 378
# We only want to replace the product one.
# So I'll split by `final p = products[index];`
parts = content.split("final p = products[index];")
if len(parts) == 2:
    new_second_part = re.sub(pattern, new_item, parts[1], count=1)
    new_content = parts[0] + "final p = products[index];\n" + new_second_part
    with open(file_path, 'w') as f:
        f.write(new_content)
else:
    print("Could not find anchor 'final p = products[index];'")

