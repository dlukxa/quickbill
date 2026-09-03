import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/customer_provider.dart';
import '../../providers/employee_provider.dart';
import '../../services/sync_service.dart';
import '../auth/profile_picker_screen.dart';
import 'desktop_pos_screen.dart';
import 'desktop_qr_link_screen.dart';

const _kShopUidKey = 'desktop_shop_uid';

/// Root wrapper for the Windows desktop app.
/// Handles three states:
///   1. Not linked → show QR code to link shop
///   2. Linked but no cashier selected → show profile picker (PIN screen)
///   3. Fully ready → show the full POS screen
class DesktopWrapper extends ConsumerStatefulWidget {
  const DesktopWrapper({super.key});

  @override
  ConsumerState<DesktopWrapper> createState() => _DesktopWrapperState();
}

class _DesktopWrapperState extends ConsumerState<DesktopWrapper> {
  String? _shopUid;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedShopUid();
  }

  Future<void> _loadSavedShopUid() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kShopUidKey);
    if (saved != null) {
      await prefs.setString('active_shop_uid', saved);
      _syncShopData(saved);
    }
    setState(() {
      _shopUid = saved;
      _isLoading = false;
    });
  }

  Future<void> _onLinked(String shopUid) async {
    // Persist the shopUid so we don't need to re-scan on next launch
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kShopUidKey, shopUid);
    await prefs.setString('active_shop_uid', shopUid);

    // Download employees and products from Firestore into local state
    await _syncShopData(shopUid);

    if (mounted) {
      setState(() => _shopUid = shopUid);
    }
  }

  Future<void> _syncShopData(String shopUid) async {
    // Trigger a lightweight sync of employees, products, and customers from Firestore
    try {
      await ref.read(syncServiceProvider).syncEssentialData();
      ref.invalidate(employeeListProvider);
      ref.invalidate(customersProvider);
      debugPrint('DesktopWrapper: synced shop data for $shopUid');
    } catch (e) {
      debugPrint('DesktopWrapper: sync error $e');
    }
  }

  Future<void> _unlink() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kShopUidKey);
    await prefs.remove('active_shop_uid');
    ref.read(currentEmployeeProvider.notifier).logout();
    setState(() => _shopUid = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Not linked → show QR
    if (_shopUid == null) {
      return DesktopQrLinkScreen(onLinked: _onLinked);
    }

    // Linked — check if a cashier profile has been selected
    final currentEmployeeAsync = ref.watch(currentEmployeeProvider);
    return currentEmployeeAsync.when(
      data: (employee) {
        if (employee == null) {
          // No cashier selected → show profile/PIN picker
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Column(
              children: [
                // Unlink button at top-right
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton.icon(
                      onPressed: _unlink,
                      icon: const Icon(Icons.link_off_rounded,
                          size: 16, color: Colors.white38),
                      label: const Text('Unlink',
                          style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ),
                  ),
                ),
                const Expanded(child: ProfilePickerScreen()),
              ],
            ),
          );
        }
        // Cashier selected → full POS
        return DesktopPosScreen(shopUid: _shopUid!);
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => DesktopQrLinkScreen(onLinked: _onLinked),
    );
  }
}
