import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/theme.dart';
import '../../models/employee.dart';
import '../../providers/branch_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/preference_provider.dart';
import '../../services/cash_drawer_service.dart';
import '../../services/sync_service.dart';
import '../../utils/pos_l10n.dart';
import 'desktop_customers_view.dart';
import 'desktop_dashboard_view.dart';
import 'desktop_expenses_view.dart';
import 'desktop_inventory_view.dart';
import 'desktop_pos_screen.dart';
import 'desktop_sales_view.dart';
import 'desktop_settings_view.dart';
import 'desktop_suppliers_view.dart';
import '../../widgets/store_logo_widget.dart';

import '../../providers/desktop_nav_provider.dart';
export '../../providers/desktop_nav_provider.dart';

/// Master Desktop Shell for QuickBill Desktop POS
/// Provides:
/// - Persistent, resizable sidebar navigation across all features
/// - Sized-up (expanded) mode and icon-only (collapsed) rail mode
/// - Interactive drag handle to resize the sidebar dynamically
/// - Cart state preservation using [IndexedStack]
/// - Hardware keyboard function key handlers (F1-F11)
/// - Background cloud sync management
/// - Lock screen & Cash Drawer ejectors
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _isDragging = false;

  static const double _kCollapsedWidth = 68.0;
  static const double _kMinExpandedWidth = 180.0;
  static const double _kMaxExpandedWidth = 360.0;
  static const double _kDefaultExpandedWidth = 240.0;

  @override
  void initState() {
    super.initState();
    _loadSidebarPreferences();

    // Ensure cloud sync is running on desktop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(syncServiceProvider).startSync();
      } catch (e) {
        debugPrint('Desktop background sync startup: $e');
      }
    });
  }

  Future<void> _loadSidebarPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCollapsed = prefs.getBool('desktop_sidebar_collapsed') ?? false;
      final savedWidth = prefs.getDouble('desktop_sidebar_width') ?? _kDefaultExpandedWidth;

      if (mounted) {
        ref.read(desktopSidebarCollapsedProvider.notifier).state = savedCollapsed;
        ref.read(desktopSidebarWidthProvider.notifier).state = savedWidth.clamp(_kMinExpandedWidth, _kMaxExpandedWidth);
      }
    } catch (_) {}
  }

  Future<void> _persistSidebarCollapsed(bool collapsed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('desktop_sidebar_collapsed', collapsed);
    } catch (_) {}
  }

  Future<void> _persistSidebarWidth(double width) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('desktop_sidebar_width', width);
    } catch (_) {}
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _navigateTo(int index) {
    if (ref.read(desktopNavIndexProvider) == index) return;
    ref.read(desktopNavIndexProvider.notifier).state = index;
  }

  void _toggleSidebar() {
    final current = ref.read(desktopSidebarCollapsedProvider);
    final next = !current;
    ref.read(desktopSidebarCollapsedProvider.notifier).state = next;
    _persistSidebarCollapsed(next);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Toggle sidebar collapse: F11 or Ctrl+[ / Cmd+[ or Ctrl+B / Cmd+B
    if (key == LogicalKeyboardKey.f11 ||
        ((key == LogicalKeyboardKey.bracketLeft || key == LogicalKeyboardKey.keyB) &&
            (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed))) {
      _toggleSidebar();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.f1) {
      _navigateTo(0); // POS Terminal
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.f2) {
      _navigateTo(1); // Dashboard
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.f3) {
      _navigateTo(2); // Inventory
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.f4) {
      _navigateTo(3); // Sales
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.f5) {
      _navigateTo(4); // Customers
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.f6) {
      _navigateTo(5); // Suppliers & Purchases
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.f7) {
      _navigateTo(6); // Operating Expenses
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.f8) {
      _lockTerminal();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.f9) {
      _ejectCashDrawer();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.f10) {
      _navigateTo(7); // Settings
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _ejectCashDrawer() async {
    final settings = ref.read(settingsProvider);
    final posL10n = PosL10n.of(settings.languageCode);
    final res = await CashDrawerService.instance.openCashDrawer(settings, isManual: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.success ? posL10n.drawerEjected : 'Cash Drawer: ${res.message}'),
          backgroundColor: res.success ? AppTheme.primaryGreen : Colors.orange.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _lockTerminal() {
    ref.read(currentEmployeeProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final posL10n = PosL10n.of(settings.languageCode);
    final currentEmp = ref.watch(currentEmployeeProvider).value;
    final selectedBranch = ref.watch(branchProvider).selectedBranch;

    final isCollapsed = ref.watch(desktopSidebarCollapsedProvider);
    final sidebarWidth = ref.watch(desktopSidebarWidthProvider);
    final selectedIndex = ref.watch(desktopNavIndexProvider);

    final effectiveWidth = isCollapsed ? _kCollapsedWidth : sidebarWidth;
    final sidebarBg = isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B);
    final sidebarBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFF334155);

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: Row(
          children: [
            // Collapsible / Resizable Navigation Sidebar
            AnimatedContainer(
              duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
              curve: Curves.easeInOutCubic,
              width: effectiveWidth,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: sidebarBg,
                border: Border(right: BorderSide(color: sidebarBorder)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showCollapsed = constraints.maxWidth < 140;
                  return Column(
                    children: [
                      // Top Branding / Header with Collapse/Expand Toggle
                      if (showCollapsed)
                        _buildCollapsedHeader(settings, posL10n)
                      else
                        _buildExpandedHeader(settings, selectedBranch?.name ?? 'Main Branch', posL10n),

                      const Divider(height: 1, color: Color(0xFF334155)),

                      // Nav items list
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: showCollapsed ? 6 : 8,
                          ),
                          children: [
                            _buildNavItem(0, posL10n.posTerminal, Icons.point_of_sale_rounded, 'F1', showCollapsed, selectedIndex),
                            _buildNavItem(1, posL10n.dashboardNav, Icons.analytics_rounded, 'F2', showCollapsed, selectedIndex),
                            _buildNavItem(2, posL10n.inventoryNav, Icons.inventory_2_rounded, 'F3', showCollapsed, selectedIndex),
                            _buildNavItem(3, posL10n.invoicesAndSalesNav, Icons.receipt_long_rounded, 'F4', showCollapsed, selectedIndex),
                            _buildNavItem(4, posL10n.customersNav, Icons.people_alt_rounded, 'F5', showCollapsed, selectedIndex),
                            _buildNavItem(5, posL10n.suppliersGrnNav, Icons.local_shipping_rounded, 'F6', showCollapsed, selectedIndex),
                            _buildNavItem(6, posL10n.expensesNav, Icons.payments_rounded, 'F7', showCollapsed, selectedIndex),
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: Color(0xFF334155)),
                            const SizedBox(height: 8),
                            _buildNavItem(7, posL10n.settingsNav, Icons.settings_rounded, 'F10', showCollapsed, selectedIndex),
                          ],
                        ),
                      ),

                      // Bottom Utilities & Profile
                      if (showCollapsed)
                        _buildCollapsedFooter(currentEmp, posL10n)
                      else
                        _buildExpandedFooter(currentEmp, posL10n),
                    ],
                  );
                },
              ),
            ),

            // Interactive Drag Handle on the right edge of sidebar
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                onHorizontalDragEnd: (_) {
                  setState(() => _isDragging = false);
                  _persistSidebarWidth(ref.read(desktopSidebarWidthProvider));
                },
                onHorizontalDragCancel: () => setState(() => _isDragging = false),
                onHorizontalDragUpdate: (details) {
                  final curWidth = ref.read(desktopSidebarWidthProvider);
                  final collapsed = ref.read(desktopSidebarCollapsedProvider);
                  final targetWidth = (collapsed ? _kCollapsedWidth : curWidth) + details.delta.dx;

                  if (targetWidth < 120.0) {
                    if (!collapsed) {
                      ref.read(desktopSidebarCollapsedProvider.notifier).state = true;
                      _persistSidebarCollapsed(true);
                    }
                  } else {
                    final clamped = targetWidth.clamp(_kMinExpandedWidth, _kMaxExpandedWidth);
                    if (collapsed) {
                      ref.read(desktopSidebarCollapsedProvider.notifier).state = false;
                      _persistSidebarCollapsed(false);
                    }
                    ref.read(desktopSidebarWidthProvider.notifier).state = clamped;
                  }
                },
                onDoubleTap: _toggleSidebar,
                child: Container(
                  width: 6,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 1.5,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isDragging ? AppTheme.primaryGreen : Colors.white12,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main Content Area with IndexedStack to PRESERVE cart state
            Expanded(
              child: IndexedStack(
                index: selectedIndex,
                children: [
                  const DesktopPosScreen(),
                  DesktopDashboardView(onNavigateTo: _navigateTo),
                  const DesktopInventoryView(),
                  const DesktopSalesView(),
                  const DesktopCustomersView(),
                  const DesktopSuppliersView(),
                  const DesktopExpensesView(),
                  const DesktopSettingsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header: Collapsed (Icon-only) ─────────────────────────────────────────

  Widget _buildCollapsedHeader(AppSettings settings, PosL10n posL10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Tooltip(
            message: '${posL10n.expandSidebar} (Ctrl+[)',
            child: InkWell(
              onTap: _toggleSidebar,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: StoreLogoWidget(
                  logoUrl: settings.shopLogoUrl,
                  size: 32,
                  borderRadius: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Tooltip(
            message: '${posL10n.expandSidebar} (Ctrl+[)',
            child: IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF94A3B8), size: 20),
              onPressed: _toggleSidebar,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header: Expanded (Sized-up) ───────────────────────────────────────────

  Widget _buildExpandedHeader(AppSettings settings, String branchName, PosL10n posL10n) {
    final title = settings.shopName.trim().isNotEmpty
        ? settings.shopName.trim()
        : 'QuickBill POS';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          StoreLogoWidget(
            logoUrl: settings.shopLogoUrl,
            size: 34,
            borderRadius: 8,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  branchName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Tooltip(
            message: '${posL10n.collapseSidebar} (Ctrl+[)',
            child: IconButton(
              icon: const Icon(Icons.menu_open_rounded, color: Color(0xFF94A3B8), size: 20),
              onPressed: _toggleSidebar,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Navigation Items ───────────────────────────────────────────────────────

  Widget _buildNavItem(
    int index,
    String label,
    IconData icon,
    String shortcut,
    bool isCollapsed,
    int selectedIndex,
  ) {
    final isSelected = selectedIndex == index;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Tooltip(
          message: '$label ($shortcut)',
          preferBelow: false,
          verticalOffset: 20,
          waitDuration: const Duration(milliseconds: 250),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateTo(index),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 48,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateTo(index),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    shortcut,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Footer: Collapsed (Icon-only) ─────────────────────────────────────────

  Widget _buildCollapsedFooter(Employee? currentEmp, PosL10n posL10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0B132B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: posL10n.openCashDrawerTooltip,
            child: IconButton(
              icon: const Icon(Icons.point_of_sale_rounded, size: 18, color: AppTheme.primaryGreen),
              onPressed: _ejectCashDrawer,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
          Tooltip(
            message: posL10n.lockTerminalTooltip,
            child: IconButton(
              icon: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.orange),
              onPressed: _lockTerminal,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
          Tooltip(
            message: posL10n.expandSidebar,
            child: IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
              onPressed: _toggleSidebar,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
          if (currentEmp != null) ...[
            const SizedBox(height: 4),
            Tooltip(
              message: '${currentEmp.name} (${currentEmp.role.name.toUpperCase()})',
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                child: Text(
                  currentEmp.name.isNotEmpty ? currentEmp.name[0].toUpperCase() : 'U',
                  style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  // ─── Footer: Expanded (Sized-up) ───────────────────────────────────────────

  Widget _buildExpandedFooter(Employee? currentEmp, PosL10n posL10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF0B132B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.point_of_sale_rounded, size: 18, color: AppTheme.primaryGreen),
                  tooltip: posL10n.openCashDrawerTooltip,
                  onPressed: _ejectCashDrawer,
                ),
                IconButton(
                  icon: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.orange),
                  tooltip: posL10n.lockTerminalTooltip,
                  onPressed: _lockTerminal,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF94A3B8)),
                  tooltip: posL10n.collapseSidebar,
                  onPressed: _toggleSidebar,
                ),
              ],
            ),
          ),
          if (currentEmp != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    child: Text(
                      currentEmp.name.isNotEmpty ? currentEmp.name[0].toUpperCase() : 'U',
                      style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentEmp.name,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentEmp.role.name.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
