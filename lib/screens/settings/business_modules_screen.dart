import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_modules_provider.dart';
import '../../config/theme.dart';

class BusinessModulesScreen extends ConsumerWidget {
  const BusinessModulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(businessModulesProvider);
    final notifier = ref.read(businessModulesProvider.notifier);
    
    final txtColor = context.onSurface;
    final subColor = context.subText;
    final cardColor = context.cardColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('Business Modules', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Enable or disable features based on your business type. Turning off a module will hide its screens and menus, but your data will remain intact.',
            style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 14),
          ),
          const SizedBox(height: 24),

          _buildModuleTile(
            context,
            title: 'Retail & Inventory',
            description: 'Manage products, categories, suppliers, and stock tracking.',
            icon: Icons.inventory_2,
            iconColor: AppTheme.primaryBlue,
            value: modules.enableProducts,
            onChanged: (val) => notifier.toggleModule('module_products', val),
            isLocked: false, 
            cardColor: cardColor,
            txtColor: txtColor,
            subColor: subColor,
          ),

          const SizedBox(height: 12),

          _buildModuleTile(
            context,
            title: 'Services (Salons/Clinics)',
            description: 'Manage services, durations, and service pricing.',
            icon: Icons.spa,
            iconColor: AppTheme.primaryGreen,
            value: modules.enableServices,
            onChanged: (val) {
              if (!val && modules.enableAppointments) {
                // Warning: Disabling services also disables appointments
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Disable Services?'),
                    content: const Text('Disabling Services will also disable Appointments. Continue?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () {
                          notifier.toggleModule('module_services', false);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Disable Both'),
                      ),
                    ],
                  )
                );
              } else {
                notifier.toggleModule('module_services', val);
              }
            },
            cardColor: cardColor,
            txtColor: txtColor,
            subColor: subColor,
          ),

          const SizedBox(height: 12),

          _buildModuleTile(
            context,
            title: 'Appointments',
            description: 'Calendar scheduling and staff roster management. Requires Services.',
            icon: Icons.calendar_month,
            iconColor: AppTheme.primaryPurple,
            value: modules.enableAppointments,
            onChanged: (val) {
              if (val && !modules.enableServices) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You must enable Services to use Appointments.'))
                );
              } else {
                notifier.toggleModule('module_appointments', val);
              }
            },
            cardColor: cardColor,
            txtColor: txtColor,
            subColor: subColor,
          ),

          const SizedBox(height: 12),

          _buildModuleTile(
            context,
            title: 'Custom Orders (Made-to-Order)',
            description: 'For Tailors, Bakeries, Print Shops. Manage deposits, due dates, and custom measurements.',
            icon: Icons.assignment_turned_in,
            iconColor: AppTheme.errorRed,
            value: modules.enableCustomOrders,
            onChanged: (val) => notifier.toggleModule('module_custom_orders', val),
            cardColor: cardColor,
            txtColor: txtColor,
            subColor: subColor,
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTile(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required Function(bool) onChanged,
    bool isLocked = false,
    required Color cardColor,
    required Color txtColor,
    required Color subColor,
  }) {
    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: txtColor))),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 36),
            child: Text(description, style: TextStyle(color: subColor, height: 1.3)),
          ),
          value: value,
          onChanged: isLocked ? null : onChanged,
          activeColor: AppTheme.primaryBlue,
        ),
      ),
    );
  }
}
