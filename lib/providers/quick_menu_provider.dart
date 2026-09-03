import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyQuickMenuEnabled = 'quick_menu_enabled';
const _keyQuickMenuProductIds = 'quick_menu_product_ids';
const _keyQuickMenuServiceIds = 'quick_menu_service_ids';

class QuickMenuState {
  final bool enabled;
  final List<int> pinnedProductIds; // empty = auto mode (show all or ≤12)
  
  // Nullable backing field so it survives Hot Reload without throwing a type error
  final List<int>? _pinnedServiceIds;
  
  List<int> get pinnedServiceIds => _pinnedServiceIds ?? const [];

  const QuickMenuState({
    this.enabled = true,
    this.pinnedProductIds = const [],
    List<int>? pinnedServiceIds,
  }) : _pinnedServiceIds = pinnedServiceIds;

  bool get isAutoMode => pinnedProductIds.isEmpty && pinnedServiceIds.isEmpty;

  QuickMenuState copyWith({bool? enabled, List<int>? pinnedProductIds, List<int>? pinnedServiceIds}) {
    return QuickMenuState(
      enabled: enabled ?? this.enabled,
      pinnedProductIds: pinnedProductIds ?? this.pinnedProductIds,
      pinnedServiceIds: pinnedServiceIds ?? this._pinnedServiceIds,
    );
  }
}

class QuickMenuNotifier extends AsyncNotifier<QuickMenuState> {
  late SharedPreferences _prefs;

  @override
  Future<QuickMenuState> build() async {
    _prefs = await SharedPreferences.getInstance();
    final enabled = _prefs.getBool(_keyQuickMenuEnabled) ?? false;
    final ids = _prefs.getStringList(_keyQuickMenuProductIds) ?? [];
    final pinnedIds = ids.map((e) => int.tryParse(e)).whereType<int>().toList();
    
    final sIds = _prefs.getStringList(_keyQuickMenuServiceIds) ?? [];
    final pinnedSIds = sIds.map((e) => int.tryParse(e)).whereType<int>().toList();
    
    return QuickMenuState(enabled: enabled, pinnedProductIds: pinnedIds, pinnedServiceIds: pinnedSIds);
  }

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_keyQuickMenuEnabled, value);
    state = AsyncData(state.value!.copyWith(enabled: value));
  }

  Future<void> setPinnedProducts(List<int> productIds) async {
    await _prefs.setStringList(
        _keyQuickMenuProductIds, productIds.map((e) => e.toString()).toList());
    state = AsyncData(state.value!.copyWith(pinnedProductIds: productIds));
  }

  Future<void> toggleProduct(int productId) async {
    final current = List<int>.from(state.value!.pinnedProductIds);
    if (current.contains(productId)) {
      current.remove(productId);
    } else {
      current.add(productId);
    }
    await setPinnedProducts(current);
  }

  Future<void> setPinnedServices(List<int> serviceIds) async {
    await _prefs.setStringList(
        _keyQuickMenuServiceIds, serviceIds.map((e) => e.toString()).toList());
    state = AsyncData(state.value!.copyWith(pinnedServiceIds: serviceIds));
  }

  Future<void> toggleService(int serviceId) async {
    final current = List<int>.from(state.value!.pinnedServiceIds);
    if (current.contains(serviceId)) {
      current.remove(serviceId);
    } else {
      current.add(serviceId);
    }
    await setPinnedServices(current);
  }
}

final quickMenuProvider =
    AsyncNotifierProvider<QuickMenuNotifier, QuickMenuState>(() {
  return QuickMenuNotifier();
});
