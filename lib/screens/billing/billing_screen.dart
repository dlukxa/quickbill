import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/discount_provider.dart';
import '../../providers/preference_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/animate_in.dart';
import '../../widgets/cached_product_image.dart';
import '../customers/customer_list_screen.dart';
import 'payment_screen.dart';
import 'billing_scan_screen.dart';
import 'quick_item_sheet.dart';
import 'batch_selection_sheet.dart';
import '../../utils/category_icon_util.dart';
import '../../utils/region_utils.dart';
import '../../providers/employee_provider.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../models/service.dart';
import '../../providers/quick_menu_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/business_modules_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/custom_order_provider.dart';
import '../../models/custom_order.dart';
import '../../models/appointment.dart';

import 'quick_menu_settings_sheet.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../providers/multi_bill_provider.dart';
import '../../widgets/variable_quantity_dialog.dart';
import '../../widgets/cart_quantity_edit_dialog.dart';
import '../../services/sinhala_search_service.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  String _searchQuery = '';
  String _searchMode = 'products'; // 'products' or 'services'
  final _searchController = TextEditingController();
  bool _isQuickMenuExpanded = true;


  void _showOrderLoader(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final ordersAsync = ref.watch(customOrdersProvider);
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ready Custom Orders', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ordersAsync.when(
                      data: (orders) {
                        final readyOrders = orders.where((o) => o.status == 'ready').toList();
                        if (readyOrders.isEmpty) {
                          return const Center(child: Text('No orders ready for pickup.'));
                        }
                        return ListView.builder(
                          itemCount: readyOrders.length,
                          itemBuilder: (context, index) {
                            final order = readyOrders[index];
                            return ListTile(
                              title: Text((order.customerId != null ? (ref.read(customersProvider).valueOrNull?.firstWhere((c) => c.id == order.customerId, orElse: () => Customer(name: 'Unknown', createdAt: DateTime.now(), updatedAt: DateTime.now())).name ?? 'Unknown') : 'Unknown')),
                              subtitle: Text('Bal Due: \$${(order.totalAmount - order.depositAmount).toStringAsFixed(2)}'),
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  final cartNotifier = ref.read(cartProvider.notifier);
                                  
                                  // Create a quick custom item for the balance
                                  final balance = order.totalAmount - order.depositAmount;
                                  if (balance > 0) {
                                      cartNotifier.addQuickItem(
                                        name: 'Custom Order #${order.id} Balance',
                                        price: balance,
                                        quantity: 1,
                                      );
                                  }
                                  
                                  // Set customer
                                  if (order.customerId != null) {
                                    final customers = ref.read(customersProvider).valueOrNull ?? [];
                                    try {
                                      final cust = customers.firstWhere((c) => c.id == order.customerId);
                                      ref.read(selectedCustomerProvider.notifier).state = cust;
                                    } catch (e) {}
                                  }
                                  
                                  // Mark order as delivered (simplification, ideally done AFTER payment)
                                  ref.read(customOrderActionsProvider).updateStatus(order.id!, 'delivered');
                                  
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order balance loaded to cart.')));
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                                child: const Text('Load'),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAppointmentLoader(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final appointmentsAsync = ref.watch(appointmentsProvider(DateTime.now()));
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today\'s Appointments', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: appointmentsAsync.when(
                      data: (appointments) {
                        final active = appointments.where((a) => a.status == 'booked' || a.status == 'inProgress').toList();
                        if (active.isEmpty) {
                          return const Center(child: Text('No active appointments for today.'));
                        }
                        return ListView.builder(
                          itemCount: active.length,
                          itemBuilder: (context, index) {
                            final appt = active[index];
                            return ListTile(
                              title: Text((appt.customerId != null ? (ref.read(customersProvider).valueOrNull?.firstWhere((c) => c.id == appt.customerId, orElse: () => Customer(name: 'Unknown', createdAt: DateTime.now(), updatedAt: DateTime.now())).name ?? 'Unknown') : 'Unknown')),
                              subtitle: Text('Status: ${appt.status}'),
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  // Load services into cart
                                  final services = ref.read(servicesProvider).valueOrNull ?? [];
                                  final cartNotifier = ref.read(cartProvider.notifier);
                                  
                                  for (var serviceId in appt.serviceIds) {
                                    try {
                                      final service = services.firstWhere((s) => s.id == serviceId);
                                      cartNotifier.addService(service);
                                    } catch (e) {
                                      // Service not found
                                    }
                                  }
                                  
                                  // Set customer if possible
                                  if (appt.customerId != null) {
                                    final customers = ref.read(customersProvider).valueOrNull ?? [];
                                    try {
                                      final cust = customers.firstWhere((c) => c.id == appt.customerId);
                                      ref.read(selectedCustomerProvider.notifier).state = cust;
                                    } catch (e) {}
                                  } else {
                                    // Or create a temporary customer reference using the name
                                    final tempCust = Customer(name: 'Unknown', createdAt: DateTime.now(), updatedAt: DateTime.now());
                                    ref.read(selectedCustomerProvider.notifier).state = tempCust;
                                  }
                                  
                                  // Mark appointment as completed
                                  ref.read(appointmentActionsProvider).updateAppointment(appt.copyWith(status: 'completed'));
                                  
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment loaded to cart.')));
                                },
                                child: const Text('Load'),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showQuantityDialog(BuildContext context, WidgetRef ref, CartItem item, int itemIndex) {
    CartQuantityEditDialog.show(
      context,
      item: item,
      index: itemIndex,
      isDark: context.isDark,
    );
  }

  void _showItemDiscountDialog(BuildContext context, WidgetRef ref, CartItem item, int itemIndex) {
    final permissions = ref.read(currentEmployeeProvider).value?.permissions;
    if (!(permissions?.canGiveDiscount ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.accessDenied)),
      );
      return;
    }
    final controller = TextEditingController(text: item.discount > 0 ? item.discount.toString() : '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.discountLabel(item.itemName)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Max allowed: ${permissions!.maxDiscountPercent}%',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.enterDiscountAmount,
                hintText: '0.00',
                prefixText: '${globalAppRegion.currencySymbol} ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () {
              final discount = double.tryParse(controller.text) ?? 0.0;
              final maxDiscountAmount = (item.itemPrice * item.quantity) * (permissions.maxDiscountPercent / 100);
              if (discount >= 0 && discount <= (item.itemPrice * item.quantity)) {
                if (discount > maxDiscountAmount + 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.limitExceeded(
                        maxDiscountAmount.toStringAsFixed(2), permissions.maxDiscountPercent.toString()))),
                  );
                  return;
                }
                ref.read(cartProvider.notifier).updateItemDiscount(
                  discount: discount,
                  index: itemIndex,
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.invalidDiscount)),
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.apply),
          ),
        ],
      ),
    );
  }

  void _showBillDiscountDialog(BuildContext context, WidgetRef ref, double? currentDiscount, double subtotal) {
    final permissions = ref.read(currentEmployeeProvider).value?.permissions;
    if (!(permissions?.canGiveDiscount ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.accessDenied)),
      );
      return;
    }
    final discountController = TextEditingController(
        text: currentDiscount != null && currentDiscount > 0 ? currentDiscount.toString() : '');
    bool isPercentage = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.billDiscount),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Amount')),
                  ButtonSegment(value: true, label: Text('Percentage')),
                ],
                selected: {isPercentage},
                onSelectionChanged: (s) => setState(() => isPercentage = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isPercentage ? 'Discount Percentage (%)' : 'Discount Amount (Rs)',
                  prefixText: isPercentage ? null : '${globalAppRegion.currencySymbol} ',
                  prefixIcon: Icon(isPercentage ? Icons.percent : Icons.money),
                  helperText: 'Subtotal: ${Formatters.currency(subtotal)}',
                ),
                autofocus: true,
              ),
              if (ref.read(autoBillDiscountProvider) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'An automatic discount of ${Formatters.currency(ref.read(autoBillDiscountProvider))} is available.',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
          actions: [
            if (ref.read(manualBillDiscountProvider) != null)
              TextButton(
                onPressed: () {
                  ref.read(manualBillDiscountProvider.notifier).state = null;
                  Navigator.pop(context);
                },
                child: const Text('Reset to Auto', style: TextStyle(color: AppTheme.primaryGreen)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
            ElevatedButton(
              onPressed: () {
                final discountValue = double.tryParse(discountController.text) ?? 0.0;
                final maxDiscountAmount = subtotal * (permissions!.maxDiscountPercent / 100);
                if (discountValue < 0) return;
                double discount = discountValue;
                if (isPercentage) discount = subtotal * (discountValue / 100);
                if (discount > maxDiscountAmount + 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.limitExceeded(
                        maxDiscountAmount.toStringAsFixed(2), permissions.maxDiscountPercent.toString()))),
                  );
                  return;
                }
                if (discount > subtotal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discount cannot exceed subtotal')),
                  );
                  return;
                }
                ref.read(manualBillDiscountProvider.notifier).state = discount;
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.apply),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildFallbackCategoryIcon(String? category, double size, double iconSize) {
    final color = CategoryIconUtil.getColorForCategory(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        CategoryIconUtil.getIconForCategory(category),
        color: color,
        size: iconSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final businessModules = ref.watch(businessModulesProvider);
    final serviceSearchResults = ref.watch(searchServicesProvider(_searchQuery));

    // Auto-set search mode based on enabled modules
    if (!businessModules.enableProducts && businessModules.enableServices) {
      // Service-only business: always show services
      if (_searchMode != 'services') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _searchMode = 'services');
        });
      }
    } else if (businessModules.enableProducts && !businessModules.enableServices) {
      // Product-only business: always show products
      if (_searchMode != 'products') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _searchMode = 'products');
        });
      }
    }
    final cartTotal = ref.watch(cartTotalProvider);
    final selectedCustomer = ref.watch(selectedCustomerProvider);
    final searchResults = ref.watch(searchProductsProvider(_searchQuery));
    final multiBillState = ref.watch(multiBillProvider);
    final multiBillNotifier = ref.read(multiBillProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    // Smart mode: Quick Menu
    final allProducts = ref.watch(productsProvider);
    final allServices = ref.watch(servicesProvider);
    final qmAsync = ref.watch(quickMenuProvider);
    final qm = qmAsync.valueOrNull;
    final productList = allProducts.valueOrNull ?? [];
    final serviceList = allServices.valueOrNull ?? [];

    // Determine which products/services to show in Quick Menu
    final quickMenuProducts = (qm != null && qm.pinnedProductIds.isNotEmpty)
        ? productList.where((p) => qm.pinnedProductIds.contains(p.id)).toList()
        : <Product>[]; // Explicitly don't auto-add products
        
    final quickMenuServices = (qm != null && qm.pinnedServiceIds.isNotEmpty)
        ? serviceList.where((s) => qm.pinnedServiceIds.contains(s.id)).toList()
        : <Service>[]; // Explicitly don't auto-add services

    // Show Quick Menu if: products/services are enabled, and quick menu is enabled in settings
    final showQuickMenu = (businessModules.enableProducts || businessModules.enableServices) && qm != null &&
        qm.enabled;

    // Theme-adaptive colors
    final cardColor   = context.cardColor;
    final scaffoldBg  = context.scaffoldColor;
    final textColor   = context.onSurface;
    final subColor    = context.subText;
    final border      = context.borderColor;

    bool isTablet = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.newBill,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Quick Menu Settings',
            onPressed: () => QuickMenuSettingsSheet.show(context),
          ),
          if (businessModules.enableAppointments)
            IconButton(
              icon: const Icon(Icons.event_available),
              tooltip: 'Load Appointment',
              onPressed: () => _showAppointmentLoader(context, ref),
            ),
          if (businessModules.enableCustomOrders)
            IconButton(
              icon: const Icon(Icons.assignment_turned_in),
              tooltip: 'Load Ready Order',
              onPressed: () => _showOrderLoader(context, ref),
            ),
          if (cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.clearCartTitle,
              onPressed: () => _showClearCartDialog(context, l10n, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Bill Tabs ─────────────────────────────────────────────────
          _buildBillTabs(multiBillState, multiBillNotifier, scaffoldBg, cardColor, border, subColor),

          Expanded(
            child: isTablet 
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP/LEFT: Product Search & Discovery
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildSearchBox(l10n, businessModules.enableProducts, businessModules.enableServices),
                          Expanded(child: _buildItemFocusArea(searchResults, serviceSearchResults, _searchMode, cardColor, border, textColor, subColor, l10n)),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    // RIGHT: Cart Management
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: cardColor.withValues(alpha: 0.3),
                        child: Column(
                          children: [
                            _buildCustomerStrip(selectedCustomer, l10n, cardColor, border, textColor, subColor),
                            Expanded(child: _buildCartArea(cart, cardColor, scaffoldBg, textColor, subColor, border)),
                            _buildCheckoutPanel(cart, cartTotal, l10n, selectedCustomer),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : showQuickMenu
                ? Column(
                    children: [
                      _buildCustomerStrip(selectedCustomer, l10n, cardColor, border, textColor, subColor),
                      _buildSearchBox(l10n, businessModules.enableProducts, businessModules.enableServices),
                      // When cart is empty, show Quick Menu at the top (right under Quick Item button)
                      if (cart.isEmpty && _searchQuery.isEmpty)
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                flex: _isQuickMenuExpanded ? 1 : 0,
                                child: _searchMode == 'services'
                                    ? _buildServiceQuickMenuGrid(quickMenuServices, cardColor, border, textColor, subColor, isFullGrid: true)
                                    : _buildSmallInventoryGrid(quickMenuProducts, cardColor, border, textColor, subColor, isFullGrid: true),
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
                              ? _buildItemFocusArea(searchResults, serviceSearchResults, _searchMode, cardColor, border, textColor, subColor, l10n)
                              : _buildCartArea(cart, cardColor, scaffoldBg, textColor, subColor, border),
                        ),
                      // When cart has items (or searching), pin Quick Menu to the bottom
                      if (cart.isNotEmpty || _searchQuery.isNotEmpty)
                        Flexible(
                          child: SingleChildScrollView(
                            child: _searchMode == 'services'
                                ? _buildServiceQuickMenuGrid(quickMenuServices, cardColor, border, textColor, subColor, isFullGrid: false)
                                : _buildSmallInventoryGrid(quickMenuProducts, cardColor, border, textColor, subColor, isFullGrid: false),
                          ),
                        ),
                      if (businessModules.enableCustomOrders)
            IconButton(
              icon: const Icon(Icons.assignment_turned_in),
              tooltip: 'Load Ready Order',
              onPressed: () => _showOrderLoader(context, ref),
            ),
          if (cart.isNotEmpty) _buildCheckoutPanel(cart, cartTotal, l10n, selectedCustomer),
                    ],
                  )
                : Column(
                    children: [
                      _buildCustomerStrip(selectedCustomer, l10n, cardColor, border, textColor, subColor),
                      _buildSearchBox(l10n, businessModules.enableProducts, businessModules.enableServices),
                      Expanded(
                        child: _searchQuery.isNotEmpty
                            ? _buildItemFocusArea(searchResults, serviceSearchResults, _searchMode, cardColor, border, textColor, subColor, l10n)
                            : _buildCartArea(cart, cardColor, scaffoldBg, textColor, subColor, border),
                      ),
                      if (businessModules.enableCustomOrders)
            IconButton(
              icon: const Icon(Icons.assignment_turned_in),
              tooltip: 'Load Ready Order',
              onPressed: () => _showOrderLoader(context, ref),
            ),
          if (cart.isNotEmpty) _buildCheckoutPanel(cart, cartTotal, l10n, selectedCustomer),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, AppLocalizations l10n, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearCartTitle),
        content: Text(l10n.clearCartContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              Navigator.pop(context);
            },
            child: Text(l10n.clear, style: const TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildBillTabs(MultiBillState multiBillState, MultiBillNotifier multiBillNotifier, Color scaffoldBg, Color cardColor, Color border, Color subColor) {
    return Container(
      height: 52,
      color: scaffoldBg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(multiBillState.sessions.length, (index) {
                  final session = multiBillState.sessions[index];
                  final isActive = multiBillState.activeIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                    child: GestureDetector(
                      onTap: () => multiBillNotifier.switchToSession(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primaryGreen : cardColor,
                          gradient: isActive ? AppTheme.primaryGradient : null,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive ? Colors.transparent : border,
                          ),
                          boxShadow: isActive ? [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ] : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isActive) ...[
                              const Icon(Icons.check_circle, size: 13, color: Colors.white),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              session.name,
                              style: GoogleFonts.plusJakartaSans(
                                color: isActive ? Colors.white : subColor,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (multiBillState.sessions.length > 1) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Remove Bill'),
                                    content: Text('Remove "${session.name}"? All items will be lost.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () {
                                          multiBillNotifier.removeSession(index);
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Remove', style: TextStyle(color: AppTheme.errorRed)),
                                      ),
                                    ],
                                  ),
                                ),
                                child: Icon(Icons.close, size: 14, color: isActive ? Colors.white70 : subColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGreen),
            onPressed: () => multiBillNotifier.addNewSession(),
            tooltip: 'New Bill',
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerStrip(Customer? selectedCustomer, AppLocalizations l10n, Color cardColor, Color border, Color textColor, Color subColor) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerListScreen(isSelectionMode: true)),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline, color: AppTheme.primaryGreen, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedCustomer?.name ?? l10n.selectCustomer,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selectedCustomer != null ? textColor : AppTheme.primaryGreen,
                      fontSize: 14,
                    ),
                  ),
                  if (selectedCustomer != null)
                    Text(
                      l10n.balanceLabel(Formatters.currency(selectedCustomer.totalDebt)),
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                ],
              ),
            ),
            if (selectedCustomer != null)
              GestureDetector(
                onTap: () => ref.read(selectedCustomerProvider.notifier).state = null,
                child: Icon(Icons.close, size: 18, color: subColor),
              )
            else
              const Icon(Icons.chevron_right, color: AppTheme.primaryGreen, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox(AppLocalizations l10n, bool enableProducts, bool enableServices) {
    final bool showToggle = enableProducts && enableServices;
    final bool serviceOnly = !enableProducts && enableServices;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: context.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      hintStyle: TextStyle(color: context.subText, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: context.subText, size: 20),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: AppTheme.errorRed),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              // Only show barcode scan button when products are enabled
              if (!serviceOnly) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingScanScreen()));
                  },
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Show toggle only when BOTH products and services are enabled
          if (showToggle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'products', label: Text('Products')),
                  ButtonSegment(value: 'services', label: Text('Services')),
                ],
                selected: {_searchMode},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _searchMode = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: context.cardColor,
                  selectedBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                ),
              ),
            ),
          GestureDetector(
            onTap: () => _showQuickItemDialog(context, ref),
            child: Container(
              width: double.infinity,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.5), width: 1.5),
                color: AppTheme.primaryGreen.withValues(alpha: 0.06),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, color: AppTheme.primaryGreen, size: 18),
                  SizedBox(width: 6),
                  Text('Quick Item', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildItemFocusArea(AsyncValue<List<Product>> searchResults, AsyncValue<List<Service>> serviceSearchResults, String searchMode, Color cardColor, Color border, Color textColor, Color subColor, AppLocalizations l10n) {
    if (_searchQuery.isNotEmpty) {
      final products = searchResults.valueOrNull ?? [];
      final services = serviceSearchResults.valueOrNull ?? [];
      
      if (products.isEmpty && services.isEmpty) {
        return Center(child: Text(l10n.noProductsFound));
      }
      
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: products.length + services.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index < products.length) {
            return _buildHorizontalQuickMenuItem(products[index], cardColor, border, textColor, subColor);
          } else {
            return _buildHorizontalServiceItem(services[index - products.length], cardColor, border, textColor, subColor);
          }
        },
      );
    }

    if (searchMode == 'products') {
      return searchResults.when(
        data: (products) {
          if (products.isEmpty) return Center(child: Text(l10n.noProductsFound));
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _buildHorizontalQuickMenuItem(products[index], cardColor, border, textColor, subColor);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading products')),
      );
    } else {
      return serviceSearchResults.when(
        data: (services) {
          if (services.isEmpty) return const Center(child: Text('No services found'));
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _buildHorizontalServiceItem(services[index], cardColor, border, textColor, subColor);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading services')),
      );
    }
  }

  Widget _buildMiniCartStrip(List<CartItem> cart, Color cardColor, Color border, Color textColor, Color subColor, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: border)),
      ),
      constraints: const BoxConstraints(maxHeight: 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, size: 14, color: AppTheme.primaryGreen),
                const SizedBox(width: 6),
                Text('${cart.length} item${cart.length == 1 ? '' : 's'} in cart',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.primaryGreen)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showClearCartDialog(context, l10n, ref),
                  child: Text('Clear', style: TextStyle(fontSize: 12, color: subColor, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              itemCount: cart.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = cart[index];
                return GestureDetector(
                  onTap: () => _showQuantityDialog(context, ref, item, index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${Formatters.quantity(item.quantity)}× ${item.itemName}',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textColor),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            ref.read(cartProvider.notifier).removeItem(
                              index: index,
                            );
                          },
                          child: Icon(Icons.close, size: 14, color: subColor),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInventoryGrid(List<Product> products, Color cardColor, Color border, Color textColor, Color subColor, {bool isFullGrid = false}) {
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
            if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('Tap the gear icon to pin products', style: TextStyle(color: subColor, fontSize: 13)),
                ),
              )
            else if (isFullGrid)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _buildHorizontalQuickMenuItem(products[index], cardColor, border, textColor, subColor);
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
                      child: _buildVerticalQuickMenuItem(products[index], cardColor, border, textColor, subColor),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _handleProductTap(Product product) async {
    final stock = product.trackBatches ? product.calculatedStock : product.stock;
    if (stock <= 0) return;

    HapticFeedback.lightImpact();

    final parsed = SinhalaSearchService.parseSearchQuery(_searchController.text);

    if (product.trackBatches) {
      final selectedBatch = await BatchSelectionSheet.show(context, product);
      if (selectedBatch == null) return;
      if (product.hasMultipleSellingModes || product.isVariableQuantity) {
        if (parsed.hasQuantitySpec && parsed.quantity != null) {
          ref.read(cartProvider.notifier).addProduct(
            product,
            quantity: parsed.quantity!,
            unit: parsed.unit,
            sellingMode: parsed.sellingMode,
            batch: selectedBatch,
          );
        } else {
          if (!mounted) return;
          VariableQuantityDialog.show(
            context,
            product: product,
            isDark: context.isDark,
            onConfirmed: (qty, unit, {sellingMode, packSize, packSizeUnit, customPrice}) {
              ref.read(cartProvider.notifier).addProduct(
                product,
                quantity: qty,
                unit: unit,
                sellingMode: sellingMode,
                packSize: packSize,
                packSizeUnit: packSizeUnit,
                customPrice: customPrice,
                batch: selectedBatch,
              );
            },
          );
          return;
        }
      } else {
        ref.read(cartProvider.notifier).addProduct(product, batch: selectedBatch);
      }
    } else {
      if (product.hasMultipleSellingModes || product.isVariableQuantity) {
        if (parsed.hasQuantitySpec && parsed.quantity != null) {
          ref.read(cartProvider.notifier).addProduct(
            product,
            quantity: parsed.quantity!,
            unit: parsed.unit,
            sellingMode: parsed.sellingMode,
          );
        } else {
          VariableQuantityDialog.show(
            context,
            product: product,
            isDark: context.isDark,
            onConfirmed: (qty, unit, {sellingMode, packSize, packSizeUnit, customPrice}) {
              ref.read(cartProvider.notifier).addProduct(
                product,
                quantity: qty,
                unit: unit,
                sellingMode: sellingMode,
                packSize: packSize,
                packSizeUnit: packSizeUnit,
                customPrice: customPrice,
              );
            },
          );
          return;
        }
      } else {
        ref.read(cartProvider.notifier).addProduct(product);
      }
    }

    final discountRule = ref.read(discountsProvider.notifier).getActiveDiscountSync(product.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(discountRule != null
            ? '${product.name} added (${discountRule.discountType == 'percentage' ? '${discountRule.discountValue}% OFF' : '${Formatters.currency(discountRule.discountValue)} OFF'})'
            : '${product.name} added to cart'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: discountRule != null ? AppTheme.primaryGreen : null,
      ));
    }
  }

  Widget _buildVerticalQuickMenuItem(Product product, Color cardColor, Color border, Color textColor, Color subColor) {
    final stock = product.trackBatches ? product.calculatedStock : product.stock;
    final inStock = stock > 0;
    
    return GestureDetector(
      onTap: inStock ? () => _handleProductTap(product) : null,
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

  Widget _buildServiceQuickMenuGrid(List<Service> services, Color cardColor, Color border, Color textColor, Color subColor, {bool isFullGrid = false}) {
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
              ],
            ),
          ),
          if (_isQuickMenuExpanded)
            if (services.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('Tap the gear icon to pin services', style: TextStyle(color: subColor, fontSize: 13)),
                ),
              )
            else if (isFullGrid)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _buildHorizontalServiceItem(services[index], cardColor, border, textColor, subColor);
                  },
                ),
              )
            else
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: 120,
                      child: _buildVerticalServiceQuickMenuItem(services[index], cardColor, border, textColor, subColor),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildVerticalServiceQuickMenuItem(Service service, Color cardColor, Color border, Color textColor, Color subColor) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(cartProvider.notifier).addService(service);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${service.name} added to cart'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: Container(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  child: Center(
                    child: _buildFallbackCategoryIcon(service.category, 48, 22),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      service.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            Formatters.currency(service.price),
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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



  
  Widget _buildHorizontalServiceItem(Service service, Color cardColor, Color border, Color textColor, Color subColor) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(cartProvider.notifier).addService(service);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${service.name} added to cart'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildFallbackCategoryIcon(service.category, 48, 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    service.name,
                    style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.currency(service.price),
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryGreen),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalQuickMenuItem(Product product, Color cardColor, Color border, Color textColor, Color subColor) {
    final stock = product.trackBatches ? product.calculatedStock : product.stock;
    final inStock = stock > 0;
    
    return GestureDetector(
      onTap: inStock ? () => _handleProductTap(product) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.imageUrl != null
                  ? CachedProductImage(
                      imageUrl: product.imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: _buildFallbackCategoryIcon(product.category, 48, 22),
                    )
                  : _buildFallbackCategoryIcon(product.category, 48, 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: inStock ? textColor : subColor,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(product.nameEnglish != null && product.nameEnglish!.isNotEmpty && product.name != product.nameEnglish) ? "${product.nameEnglish} · " : ""}${Formatters.currency(product.price)} · Stock: ${Formatters.quantity(stock)} ${product.unit}',
                    style: TextStyle(fontSize: 12, color: subColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: inStock ? AppTheme.primaryGreen : cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: inStock ? AppTheme.primaryGreen : border),
              ),
              child: Icon(Icons.add, color: inStock ? Colors.white : subColor, size: 16),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildCartArea(List<CartItem> cart, Color cardColor, Color scaffoldBg, Color textColor, Color subColor, Color border) {
    final l10n = AppLocalizations.of(context)!;
    if (cart.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined, size: 36, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 20),
            Text(l10n.cartEmpty, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 6),
            Text(l10n.searchToAdd, style: TextStyle(color: subColor, fontSize: 14)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => QuickMenuSettingsSheet.show(context),
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: const Text('Configure Quick Menu'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                side: const BorderSide(color: AppTheme.primaryGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: cart.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final cartItem = cart[index];
        return AnimateIn(
          key: ValueKey(cartItem.isQuickItem ? 'quick_$index' : '${cartItem.product?.id}_${cartItem.batchId}'),
          duration: const Duration(milliseconds: 280),
          child: _CartItemCard(
            cartItem: cartItem,
            index: index,
            cardColor: cardColor,
            scaffoldBg: scaffoldBg,
            textColor: textColor,
            subColor: subColor,
            border: border,
            onDecrement: () {
              HapticFeedback.selectionClick();
              ref.read(cartProvider.notifier).decrementQuantity(
                index: index,
              );
            },
            onIncrement: cartItem.canIncrement
                ? () {
                    HapticFeedback.selectionClick();
                    ref.read(cartProvider.notifier).incrementQuantity(
                      index: index,
                    );
                  }
                : null,
            onDelete: () {
              HapticFeedback.mediumImpact();
              ref.read(cartProvider.notifier).removeItem(
                index: index,
              );
            },
            onDiscount: () => _showItemDiscountDialog(context, ref, cartItem, index),
            onQuantityTap: () => _showQuantityDialog(context, ref, cartItem, index),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutPanel(List<CartItem> cart, double cartTotal, AppLocalizations l10n, Customer? selectedCustomer) {
    final billDiscount = ref.watch(billDiscountProvider);
    final serviceCharge = ref.watch(cartServiceChargeProvider);
    final tax = ref.watch(cartTaxProvider);
    final settings = ref.watch(settingsProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.total.toUpperCase(),
                style: TextStyle(fontSize: isTablet ? 16 : 13, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1.4),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    Formatters.currency(cartTotal),
                    style: TextStyle(fontSize: isTablet ? 42 : 30, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              final subtotal = cart.fold(0.0, (sum, item) => sum + item.total);
              _showBillDiscountDialog(context, ref, billDiscount, subtotal);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.discount_outlined, size: isTablet ? 18 : 14, color: Colors.white60),
                    const SizedBox(width: 6),
                    Text(l10n.discount, style: TextStyle(fontSize: isTablet ? 16 : 13, color: Colors.white60)),
                  ]),
                  Text(
                    billDiscount > 0
                        ? '-${Formatters.currency(billDiscount)}'
                        : l10n.addDiscount,
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 13,
                      fontWeight: FontWeight.w700,
                      color: billDiscount > 0 ? Colors.orangeAccent : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (serviceCharge > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.room_service_outlined, size: isTablet ? 18 : 14, color: Colors.white60),
                    const SizedBox(width: 6),
                    Text('Service Charge (${settings.serviceChargeRate}%)', style: TextStyle(fontSize: isTablet ? 16 : 13, color: Colors.white60)),
                  ]),
                  Text(
                    '+${Formatters.currency(serviceCharge)}',
                    style: TextStyle(fontSize: isTablet ? 16 : 13, fontWeight: FontWeight.w700, color: Colors.white60),
                  ),
                ],
              ),
            ),
          if (tax > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.account_balance_outlined, size: isTablet ? 18 : 14, color: Colors.white60),
                    const SizedBox(width: 6),
                    Text('Tax (${settings.taxRate}%)', style: TextStyle(fontSize: isTablet ? 16 : 13, color: Colors.white60)),
                  ]),
                  Text(
                    '+${Formatters.currency(tax)}',
                    style: TextStyle(fontSize: isTablet ? 16 : 13, fontWeight: FontWeight.w700, color: Colors.white60),
                  ),
                ],
              ),
            ),
          const Divider(color: Colors.white24, height: 16),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentScreen(
                    cartItems: cart,
                    total: cartTotal,
                    discount: billDiscount,
                    tax: tax,
                    serviceCharge: serviceCharge,
                    customer: selectedCustomer,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: isTablet ? 64 : 54,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.completeSale,
                      style: TextStyle(fontSize: isTablet ? 20 : 17, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: const Color(0xFF059669), size: isTablet ? 24 : 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickItemDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => const QuickItemSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cart Item Card
// ─────────────────────────────────────────────────────────────────────────────

class _CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  final int index;
  final Color cardColor;
  final Color scaffoldBg;
  final Color textColor;
  final Color subColor;
  final Color border;
  final VoidCallback onDecrement;
  final VoidCallback? onIncrement;
  final VoidCallback onDelete;
  final VoidCallback onDiscount;
  final VoidCallback onQuantityTap;

  const _CartItemCard({
    required this.cartItem,
    required this.index,
    required this.cardColor,
    required this.scaffoldBg,
    required this.textColor,
    required this.subColor,
    required this.border,
    required this.onDecrement,
    this.onIncrement,
    required this.onDelete,
    required this.onDiscount,
    required this.onQuantityTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cartItem.product?.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedProductImage(
                    imageUrl: cartItem.product!.imageUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: CategoryIconUtil.getColorForCategory(cartItem.product?.category).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        CategoryIconUtil.getIconForCategory(cartItem.product?.category),
                        color: CategoryIconUtil.getColorForCategory(cartItem.product?.category),
                        size: 20,
                      ),
                    ),
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final itemCategory = cartItem.itemType == 'service'
                        ? cartItem.serviceObj?.category
                        : cartItem.product?.category;
                    return Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: CategoryIconUtil.getColorForCategory(itemCategory).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        CategoryIconUtil.getIconForCategory(itemCategory),
                        color: CategoryIconUtil.getColorForCategory(itemCategory),
                        size: 20,
                      ),
                    );
                  }
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (cartItem.isQuickItem)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(4)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, size: 11, color: Colors.white),
                                SizedBox(width: 2),
                                Text('QUICK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                              ],
                            ),
                          ),
                        Expanded(
                          child: Text(cartItem.itemName,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${Formatters.currency(cartItem.itemPrice)} / ${cartItem.productBaseUnit} • ${cartItem.formattedQuantity}',
                        style: TextStyle(color: subColor, fontSize: 13)),
                    if (cartItem.batchNumber != null)
                      Text('Batch: ${cartItem.batchNumber}', style: TextStyle(fontSize: 11, color: subColor)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Formatters.currency(cartItem.total),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                  if (cartItem.discount > 0)
                    Text('-${Formatters.currency(cartItem.discount)}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.errorRed)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: border, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: onDiscount,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cartItem.discount > 0 ? AppTheme.errorRed.withValues(alpha: 0.12) : scaffoldBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cartItem.discount > 0 ? AppTheme.errorRed.withValues(alpha: 0.4) : border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.discount_outlined, size: 14,
                          color: cartItem.discount > 0 ? AppTheme.errorRed : subColor),
                      const SizedBox(width: 4),
                      Text('Disc.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: cartItem.discount > 0 ? AppTheme.errorRed : subColor)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _QtyButton(icon: Icons.remove, onTap: onDecrement, color: subColor, bg: scaffoldBg, border: border),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onQuantityTap,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: scaffoldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Text(cartItem.formattedQuantity,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _QtyButton(
                    icon: Icons.add, onTap: onIncrement,
                    color: onIncrement != null ? AppTheme.primaryGreen : border,
                    bg: scaffoldBg, border: border,
                  ),
                  const SizedBox(width: 8),
                  _QtyButton(icon: Icons.delete_outline, onTap: onDelete, color: AppTheme.errorRed, bg: scaffoldBg, border: border),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Color bg;
  final Color border;

  const _QtyButton({required this.icon, this.onTap, required this.color, required this.bg, required this.border});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
