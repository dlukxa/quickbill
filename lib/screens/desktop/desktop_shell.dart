import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/employee.dart';
import '../../providers/branch_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/preference_provider.dart';
import '../../services/cash_drawer_service.dart';
import '../../services/sync_service.dart';
import 'desktop_customers_view.dart';
import 'desktop_dashboard_view.dart';
import 'desktop_expenses_view.dart';
import 'desktop_inventory_view.dart';
import 'desktop_pos_screen.dart';
import 'desktop_sales_view.dart';
import 'desktop_settings_view.dart';
import 'desktop_suppliers_view.dart';

/// Master Desktop Shell for QuickBill Desktop POS
/// Provides:
/// - Persistent sidebar navigation across all features
/// - Cart state preservation using [IndexedStack]
/// - Hardware keyboard function key handlers (F1-F10)
/// - Background cloud sync management
/// - Lock screen & Cash Drawer ejectors
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Ensure cloud sync is running on desktop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(syncServiceProvider).startSync();
      } catch (e) {
        debugPrint('Desktop background sync startup: $e');
      }
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _navigateTo(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
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
    final res = await CashDrawerService.instance.openCashDrawer(settings, isManual: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.success ? 'Cash Drawer Ejected' : 'Cash Drawer: ${res.message}'),
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
    final currentEmp = ref.watch(currentEmployeeProvider).value;
    final selectedBranch = ref.watch(branchProvider).selectedBranch;

    final sidebarBg = isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B);
    final sidebarBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFF334155);

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: Row(
          children: [
            // Collapsible Navigation Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSidebarCollapsed ? 74 : 240,
              decoration: BoxDecoration(
                color: sidebarBg,
                border: Border(right: BorderSide(color: sidebarBorder)),
              ),
              child: Column(
                children: [
                  // Top Branding
                  _buildSidebarHeader(selectedBranch?.name ?? 'Main Branch'),
                  const Divider(height: 1, color: Color(0xFF334155)),

                  // Nav items list
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      children: [
                        _buildNavButton(0, 'POS Terminal', Icons.point_of_sale_rounded, 'F1'),
                        _buildNavButton(1, 'Dashboard', Icons.analytics_rounded, 'F2'),
                        _buildNavButton(2, 'Inventory', Icons.inventory_2_rounded, 'F3'),
                        _buildNavButton(3, 'Invoices & Sales', Icons.receipt_long_rounded, 'F4'),
                        _buildNavButton(4, 'Customers', Icons.people_alt_rounded, 'F5'),
                        _buildNavButton(5, 'Suppliers (GRN)', Icons.local_shipping_rounded, 'F6'),
                        _buildNavButton(6, 'Expenses', Icons.payments_rounded, 'F7'),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: Color(0xFF334155)),
                        const SizedBox(height: 8),
                        _buildNavButton(7, 'Settings', Icons.settings_rounded, 'F10'),
                      ],
                    ),
                  ),

                  // Bottom Utilities & Profile
                  _buildSidebarFooter(currentEmp),
                ],
              ),
            ),

            // Main Content Area with IndexedStack to PRESERVE cart state
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  DesktopPosScreen(),
                  DesktopDashboardView(),
                  DesktopInventoryView(),
                  DesktopSalesView(),
                  DesktopCustomersView(),
                  DesktopSuppliersView(),
                  DesktopExpensesView(),
                  DesktopSettingsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(String branchName) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _isSidebarCollapsed ? 12 : 16, vertical: 16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.storefront_rounded,
                color: AppTheme.primaryGreen,
                size: 28,
              ),
            ),
          ),
          if (!_isSidebarCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QuickBill POS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
          ],
        ],
      ),
    );
  }

  Widget _buildNavButton(int index, String label, IconData icon, String shortcut) {
    final isSelected = _selectedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: _isSidebarCollapsed ? 16 : 14, vertical: 2),
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          size: 20,
        ),
        title: _isSidebarCollapsed
            ? null
            : Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                  fontSize: 13,
                ),
              ),
        trailing: _isSidebarCollapsed
            ? null
            : Container(
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
        onTap: () => _navigateTo(index),
      ),
    );
  }

  Widget _buildSidebarFooter(Employee? currentEmp) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF0B132B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        children: [
          // Quick actions row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.point_of_sale_rounded, size: 18, color: AppTheme.primaryGreen),
                tooltip: 'Open Cash Drawer (F9)',
                onPressed: _ejectCashDrawer,
              ),
              IconButton(
                icon: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.orange),
                tooltip: 'Lock Terminal / Switch User (F8)',
                onPressed: _lockTerminal,
              ),
              IconButton(
                icon: Icon(
                  _isSidebarCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                  size: 20,
                  color: const Color(0xFF94A3B8),
                ),
                tooltip: _isSidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
              ),
            ],
          ),

          // Cashier Profile Badge
          if (!_isSidebarCollapsed && currentEmp != null) ...[
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
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentEmp.role.name.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.w600),
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
