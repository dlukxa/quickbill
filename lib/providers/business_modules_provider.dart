import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_modules.dart';

final businessModulesProvider = StateNotifierProvider<BusinessModulesNotifier, BusinessModules>((ref) {
  return BusinessModulesNotifier();
});

class BusinessModulesNotifier extends StateNotifier<BusinessModules> {
  BusinessModulesNotifier() : super(const BusinessModules()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = BusinessModules(
      enableProducts: prefs.getBool('module_products') ?? true, // Default ON for existing users
      enableServices: prefs.getBool('module_services') ?? false,
      enableAppointments: prefs.getBool('module_appointments') ?? false,
      enableCustomOrders: prefs.getBool('module_custom_orders') ?? false,
    );
  }

  Future<void> toggleModule(String module, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Safety check: Appointments require Services
    if (module == 'module_appointments' && value && !state.enableServices) {
      return; // Ignore invalid state transition
    }

    // Safety check: Cannot turn off services if appointments is ON
    if (module == 'module_services' && !value && state.enableAppointments) {
      await prefs.setBool('module_appointments', false);
      state = state.copyWith(enableServices: false, enableAppointments: false);
      await prefs.setBool(module, value);
      return;
    }

    await prefs.setBool(module, value);
    
    switch (module) {
      case 'module_products':
        state = state.copyWith(enableProducts: value);
        break;
      case 'module_services':
        state = state.copyWith(enableServices: value);
        break;
      case 'module_appointments':
        state = state.copyWith(enableAppointments: value);
        break;
      case 'module_custom_orders':
        state = state.copyWith(enableCustomOrders: value);
        break;
    }
  }
}
