import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../config/theme.dart';
import '../../providers/preference_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animate_in.dart';
import '../../services/sync_service.dart';
import '../../utils/region_utils.dart';
import '../../services/database_service.dart';
import '../../providers/business_modules_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/category_constants.dart';

class ShopSetupScreen extends ConsumerStatefulWidget {
  const ShopSetupScreen({super.key});

  @override
  ConsumerState<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends ConsumerState<ShopSetupScreen> {
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _logoFile;

  String _selectedRegion = 'LK'; // Default to SL
  String _selectedBusinessType = 'Retail';
  bool _isLoading = false;

  final PageController _pageController = PageController();
  int _currentPage = 0;



  @override
  void dispose() {
    _pageController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      if (!_formKey1.currentState!.validate()) return;
    } else if (_currentPage == 1) {
      // Logo page is optional, no validation required
    } else if (_currentPage == 2) {
      if (!_formKey2.currentState!.validate()) return;
    } else if (_currentPage == 3) {
      if (!_formKey3.currentState!.validate()) return;
      _completeSetup();
      return;
    }

    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentPage++);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentPage--);
    }
  }

  Future<void> _completeSetup() async {
    setState(() => _isLoading = true);

    try {
      final settingsNotifier = ref.read(settingsProvider.notifier);
      
      // Update Shop Settings
      await settingsNotifier.updateShopName(_shopNameController.text.trim());
      await settingsNotifier.updateShopAddress(_addressController.text.trim());
      await settingsNotifier.updateShopPhone(_phoneController.text.trim());

      await settingsNotifier.updateRegion(_selectedRegion);
      await settingsNotifier.updateBusinessType(_selectedBusinessType);
      
      // Automatically configure Business Modules based on shop type
      final modulesNotifier = ref.read(businessModulesProvider.notifier);
      if (_selectedBusinessType == 'Salon') {
        await modulesNotifier.toggleModule('module_services', true);
        await modulesNotifier.toggleModule('module_appointments', true);
        await modulesNotifier.toggleModule('module_custom_orders', false);
      } else if (['Tailor', 'Bakery', 'Print Shop'].contains(_selectedBusinessType)) {
        await modulesNotifier.toggleModule('module_services', false);
        await modulesNotifier.toggleModule('module_appointments', false);
        await modulesNotifier.toggleModule('module_custom_orders', true);
      } else {
        await modulesNotifier.toggleModule('module_services', false);
        await modulesNotifier.toggleModule('module_appointments', false);
        await modulesNotifier.toggleModule('module_custom_orders', false);
      }
      
      // Dismiss the POS Terminal setup banner automatically since this is a new signup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dismissed_backup_name', 'empty_db_setup_dismissed');
      await prefs.setString('last_pull_timestamp', DateTime.now().toIso8601String());
      
      // Mark setup as complete
      await settingsNotifier.completeSetup();

      if (_logoFile != null) {
        final shopUid = ref.read(activeShopUidProvider);
        if (shopUid != null) {
          final storage = ref.read(storageServiceProvider);
          final url = await storage.uploadImage(
            path: 'shops/$shopUid/logo.jpg',
            imageFile: _logoFile!,
          );
          if (url != null) {
            await settingsNotifier.updateShopLogo(url);
          }
        }
      }

      // Ensure the default owner profile exists in local DB immediately
      await DatabaseService.instance.ensureOwnerExists(1);

      // Trigger cloud sync for settings immediately
      await ref.read(syncServiceProvider).syncSettings();

      // AuthWrapper will automatically rebuild and show home screen
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index <= _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 24 : 8,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryGreen : context.borderColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe to force button use
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                  _buildPage4(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        if (_currentPage > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _prevPage,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: context.borderColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text('Back', style: GoogleFonts.plusJakartaSans(color: context.onSurface, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        if (_currentPage > 0) const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: GradientButton(
                            colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.8)],
                            onPressed: _nextPage,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_currentPage == 3) const Icon(Icons.check_circle_outline, color: Colors.white),
                                if (_currentPage == 3) const SizedBox(width: 8),
                                Text(
                                  _currentPage == 3 ? 'Start QuickBill' : 'Continue',
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey1,
        child: AnimateIn(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Text(
                'Welcome to QuickBill',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Let\'s set up your shop identity',
                style: GoogleFonts.plusJakartaSans(color: context.subText, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your shop name will appear on all your printed receipts and digital invoices. This helps build your brand and makes your business easily recognizable to customers.',
                        style: GoogleFonts.plusJakartaSans(color: context.onSurface.withValues(alpha: 0.8), fontSize: 15, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              FormField(
                validator: (value) => _shopNameController.text.isEmpty ? 'Required' : null,
                builder: (state) => TextFormField(
                  controller: _shopNameController,
                  style: TextStyle(color: context.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Shop Name',
                    hintText: 'e.g., Sunrise Groceries',
                    hintStyle: TextStyle(color: context.subText.withValues(alpha: 0.5)),
                    prefixIcon: const Icon(Icons.business_rounded, size: 20),
                    border: const OutlineInputBorder(),
                    errorText: state.errorText,
                  ),
                  onChanged: (val) => state.didChange(val),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AnimateIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Text(
              'Shop Logo',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: context.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a professional touch',
              style: GoogleFonts.plusJakartaSans(color: context.subText, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your logo will be printed at the top of your receipts. It\'s optional right now and you can always add or change it later from the settings.',
                      style: GoogleFonts.plusJakartaSans(color: context.onSurface.withValues(alpha: 0.8), fontSize: 15, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final source = await showModalBottomSheet<ImageSource>(
                  context: context,
                  backgroundColor: context.cardColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: Icon(Icons.photo_library_rounded, color: context.onSurface),
                          title: Text('Photo Library', style: TextStyle(color: context.onSurface)),
                          onTap: () => Navigator.pop(context, ImageSource.gallery),
                        ),
                        ListTile(
                          leading: Icon(Icons.photo_camera_rounded, color: context.onSurface),
                          title: Text('Camera', style: TextStyle(color: context.onSurface)),
                          onTap: () => Navigator.pop(context, ImageSource.camera),
                        ),
                      ],
                    ),
                  ),
                );
                if (source == null) return;
                final pickedFile = await picker.pickImage(source: source, maxWidth: 400, maxHeight: 400);
                if (pickedFile != null) {
                  setState(() {
                    _logoFile = File(pickedFile.path);
                  });
                }
              },
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: context.cardColor,
                  shape: BoxShape.circle,
                  image: _logoFile != null ? DecorationImage(image: FileImage(_logoFile!), fit: BoxFit.cover) : null,
                  border: Border.all(color: context.borderColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _logoFile == null
                    ? const Icon(Icons.add_a_photo_rounded, size: 48, color: AppTheme.primaryGreen)
                    : null,
              ),
            ),
            if (_logoFile != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _logoFile = null;
                  });
                },
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                label: const Text('Remove Logo', style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey2,
        child: AnimateIn(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Text(
                'Shop Location',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Where is your business located?',
                style: GoogleFonts.plusJakartaSans(color: context.subText, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'We use your location to automatically configure your currency and local tax rules. Your address will also be printed directly on your bills for your customers\' convenience.',
                        style: GoogleFonts.plusJakartaSans(color: context.onSurface.withValues(alpha: 0.8), fontSize: 15, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              DropdownButtonFormField<String>(
                value: _selectedRegion,
                dropdownColor: context.cardColor,
                style: TextStyle(color: context.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Country/Region',
                  prefixIcon: Icon(Icons.public_rounded, size: 20),
                  border: OutlineInputBorder(),
                ),
                items: AppRegion.values
                    .map((region) => DropdownMenuItem(
                          value: region.code,
                          child: Text(region.displayName),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedRegion = val!;
                    _phoneController.text = RegionUtils.fromCode(val).phonePrefix;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                style: TextStyle(color: context.onSurface),
                decoration: InputDecoration(
                  labelText: 'Shop Address',
                  hintText: 'e.g., 123 Main Street, Colombo 03',
                  hintStyle: TextStyle(color: context.subText.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.location_on_rounded, size: 20),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey3,
        child: AnimateIn(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Text(
                'Business Details',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us a bit more about what you do',
                style: GoogleFonts.plusJakartaSans(color: context.subText, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'By selecting your specific business type, QuickBill automatically turns on the perfect tools for you. For example, selecting \'Salon\' activates our built-in Appointments system!',
                        style: GoogleFonts.plusJakartaSans(color: context.onSurface.withValues(alpha: 0.8), fontSize: 15, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              DropdownButtonFormField<String>(
                value: _selectedBusinessType,
                dropdownColor: context.cardColor,
                style: TextStyle(color: context.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Type of Business',
                  prefixIcon: Icon(Icons.category_rounded, size: 20),
                  border: OutlineInputBorder(),
                ),
                items: CategoryConstants.businessTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBusinessType = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: context.onSurface),
                decoration: InputDecoration(
                  labelText: 'Shop Phone Number',
                  hintText: 'e.g., +94 77 123 4567',
                  hintStyle: TextStyle(color: context.subText.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                  border: const OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),

            ],
          ),
        ),
      ),
    );
  }
}
