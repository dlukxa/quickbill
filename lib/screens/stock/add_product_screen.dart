import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../services/barcode_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_button.dart';
import '../../utils/region_utils.dart';
import '../../widgets/animate_in.dart';
import '../../providers/preference_provider.dart';
import '../../services/category_detection_service.dart';
import '../../utils/category_icon_util.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../utils/category_constants.dart';
import '../../utils/l10n_extensions.dart';
import '../../services/yolo_world_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../../services/local_media_storage_service.dart';
import '../../models/supplier.dart';
import '../../providers/supplier_provider.dart';
import '../../services/sinhala_search_service.dart';
import '../../services/sinhala_transliteration_service.dart';
import '../../widgets/sinhala_transliteration_input.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final Product? product;
  final String? initialBarcode;
  const AddProductScreen({super.key, this.product, this.initialBarcode});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameSinhalaController = TextEditingController();
  final _nameEnglishController = TextEditingController();
  final _searchAliasesController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '10.0');

  // Multi-Mode Selling
  bool _allowLoose = true;
  bool _allowPack = false;
  final _packSizeController = TextEditingController(text: '1.0');
  String _packSizeUnit = 'kg';
  String _packUnit = 'pack';
  final _packPriceController = TextEditingController();
  final _packCostPriceController = TextEditingController();
 
  String? _selectedCategory;
  String _selectedUnit = 'pcs';
  String _productType = 'product';
  bool _trackBatches = false;
  int? _selectedSupplierId;
  bool _isSubmitting = false;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  bool _isDetecting = false;
  YoloWorldDetection? _detectedResult;
  final _categorySearchController = TextEditingController();
  bool _showAdvancedBilingual = false;
 
  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _nameSinhalaController.text = widget.product!.nameSinhala ?? '';
      _nameEnglishController.text = widget.product!.nameEnglish ?? '';
      _searchAliasesController.text = widget.product!.searchAliases ?? '';
      _barcodeController.text = widget.product!.baseBarcode ?? '';
      _priceController.text = widget.product!.price.toString();
      _costPriceController.text = widget.product!.costPrice?.toString() ?? '';
      _stockController.text = widget.product!.stock.toString();
      _minStockController.text = widget.product!.minStock.toString();
      _allowLoose = widget.product!.allowLoose;
      _allowPack = widget.product!.allowPack;
      _packSizeController.text = (widget.product!.packSize ?? 1.0).toString();
      _packSizeUnit = widget.product!.packSizeUnit;
      _packUnit = widget.product!.packUnit;
      _packPriceController.text = widget.product!.packPrice?.toString() ?? '';
      _packCostPriceController.text = widget.product!.packCostPrice?.toString() ?? '';
      final cat = widget.product!.category;
      if (cat != null) {
        _selectedCategory = cat;
      }
      _productType = widget.product!.type;
      _selectedUnit = widget.product!.unit;
      _trackBatches = widget.product!.trackBatches;
      _selectedSupplierId = widget.product!.supplierId;
      _imagePath = widget.product!.imageUrl;
      if (_nameSinhalaController.text.isNotEmpty || _nameEnglishController.text.isNotEmpty || _searchAliasesController.text.isNotEmpty) {
        _showAdvancedBilingual = true;
      }
    } else if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      _barcodeController.text = widget.initialBarcode!;
    }
    _nameController.addListener(_onNameChanged);
  }
 
  void _onNameChanged() {
    if (_selectedCategory == null || _selectedCategory == 'Miscellaneous' || _selectedCategory == 'Other') {
      final detected = CategoryDetectionService.detectCategory(_nameController.text);
      if (detected != null && detected != _selectedCategory) {
        setState(() {
          _selectedCategory = detected;
        });
      }
    }
  }
 
  @override
  void dispose() {
    _nameController.dispose();
    _nameSinhalaController.dispose();
    _nameEnglishController.dispose();
    _searchAliasesController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Processing image aspect ratio...'),
              duration: Duration(milliseconds: 500),
            ),
          );
        }

        final bytes = await File(pickedFile.path).readAsBytes();
        final croppedBytes = await compute(_cropToSquareIsolate, bytes);

        if (croppedBytes != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final localImage = File('${appDir.path}/$fileName');
          await localImage.writeAsBytes(croppedBytes);

          setState(() {
            _imagePath = localImage.path;
            _isDetecting = true;
            _detectedResult = null;
          });

          // Run OCR detection silently in background to auto-fill details
          YoloWorldService.instance.detectProduct(localImage).then((detection) {
            if (mounted) {
              setState(() {
                _isDetecting = false;
                _detectedResult = detection;
              });
            }
          }).catchError((e) {
            if (mounted) {
              setState(() {
                _isDetecting = false;
                _detectedResult = null;
              });
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.errorPickingImage}: $e')),
        );
      }
    }
  }

  static Uint8List? _cropToSquareIsolate(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final size = image.width < image.height ? image.width : image.height;
    final x = (image.width - size) ~/ 2;
    final y = (image.height - size) ~/ 2;

    final cropped = img.copyCrop(image, x: x, y: y, width: size, height: size);
    final resized = img.copyResize(cropped, width: 300, height: 300);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
  }
 
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
 
    setState(() => _isSubmitting = true);
 
    try {
      String? finalImageUrl = _imagePath;
      
      // If a new local image was picked, upload it to Storage
      if (_imagePath != null && !_imagePath!.startsWith('http')) {
        final storage = ref.read(storageServiceProvider);
        final shopUid = ref.read(activeShopUidProvider);
        if (shopUid != null) {
          final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final url = await storage.uploadImage(
            path: 'shops/$shopUid/products/$fileName',
            imageFile: File(_imagePath!),
          );
          if (url != null) {
            finalImageUrl = url;
            await LocalMediaStorageService.instance.saveLocalUploadedImage(
              localFile: File(_imagePath!),
              remoteUrl: url,
            );
          }
        }
      }

      final tokens = SinhalaSearchService.generateSearchTokens(
        name: _nameController.text.trim(),
        nameSinhala: _nameSinhalaController.text.trim().isEmpty ? null : _nameSinhalaController.text.trim(),
        nameEnglish: _nameEnglishController.text.trim().isEmpty ? null : _nameEnglishController.text.trim(),
        searchAliases: _searchAliasesController.text.trim().isEmpty ? null : _searchAliasesController.text.trim(),
        baseBarcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      );

      final parsedPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final parsedCost = _costPriceController.text.trim().isEmpty ? null : double.tryParse(_costPriceController.text.trim());
      final parsedStock = _trackBatches ? 0.0 : (double.tryParse(_stockController.text.trim()) ?? 0.0);
      final parsedMinStock = double.tryParse(_minStockController.text.trim()) ?? 10.0;

      if (widget.product != null) {
        // Update existing product
        final updatedProduct = widget.product!.copyWith(
          name: _nameController.text.trim(),
          nameSinhala: _nameSinhalaController.text.trim().isEmpty ? null : _nameSinhalaController.text.trim(),
          nameEnglish: _nameEnglishController.text.trim().isEmpty ? null : _nameEnglishController.text.trim(),
          searchAliases: _searchAliasesController.text.trim().isEmpty ? null : _searchAliasesController.text.trim(),
          normalizedTerms: tokens.join(','),
          baseBarcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
          price: parsedPrice,
          costPrice: parsedCost,
          stock: parsedStock,
          minStock: parsedMinStock,
          category: _selectedCategory,
          unit: _selectedUnit,
          type: _productType,
          trackBatches: _trackBatches,
          supplierId: _selectedSupplierId,
          imageUrl: finalImageUrl,
          allowLoose: _allowLoose,
          allowPack: _allowPack,
          packPrice: double.tryParse(_packPriceController.text.trim()),
          packCostPrice: double.tryParse(_packCostPriceController.text.trim()),
          packSize: double.tryParse(_packSizeController.text.trim()) ?? 1.0,
          packUnit: _packUnit,
          packSizeUnit: _packSizeUnit,
        );
        await ref.read(productActionsProvider).updateProduct(updatedProduct);
      } else {
        // Add new product
        final product = Product(
          name: _nameController.text.trim(),
          nameSinhala: _nameSinhalaController.text.trim().isEmpty ? null : _nameSinhalaController.text.trim(),
          nameEnglish: _nameEnglishController.text.trim().isEmpty ? null : _nameEnglishController.text.trim(),
          searchAliases: _searchAliasesController.text.trim().isEmpty ? null : _searchAliasesController.text.trim(),
          normalizedTerms: tokens.join(','),
          baseBarcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
          price: parsedPrice,
          costPrice: parsedCost,
          stock: parsedStock,
          minStock: parsedMinStock,
          category: _selectedCategory,
          unit: _selectedUnit,
          type: _productType,
          trackBatches: _trackBatches,
          supplierId: _selectedSupplierId,
          imageUrl: finalImageUrl,
          allowLoose: _allowLoose,
          allowPack: _allowPack,
          packPrice: double.tryParse(_packPriceController.text.trim()),
          packCostPrice: double.tryParse(_packCostPriceController.text.trim()),
          packSize: double.tryParse(_packSizeController.text.trim()) ?? 1.0,
          packUnit: _packUnit,
          packSizeUnit: _packSizeUnit,
        );
        await ref.read(productActionsProvider).addProduct(product);
      }
 
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.product != null 
              ? AppLocalizations.of(context)!.productUpdatedSuccessfully 
              : AppLocalizations.of(context)!.productAddedSuccessfully)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.error}: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isRetailOrGrocery = settings.businessType == 'Retail' || settings.businessType == 'Grocery';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.product != null 
            ? AppLocalizations.of(context)!.editProduct 
            : AppLocalizations.of(context)!.addNewProduct,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            child: AnimateIn(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                  // Image Picker Section
                  AnimateIn(
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.photo_library),
                                    title: Text(AppLocalizations.of(context)!.photoLibrary),
                                    onTap: () {
                                      _pickImage(ImageSource.gallery);
                                      Navigator.pop(context);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_camera),
                                    title: Text(AppLocalizations.of(context)!.camera),
                                    onTap: () {
                                      _pickImage(ImageSource.camera);
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
                            image: _imagePath != null
                                ? DecorationImage(
                                    image: _imagePath!.startsWith('http')
                                        ? NetworkImage(_imagePath!) as ImageProvider
                                        : FileImage(File(_imagePath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _imagePath == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_a_photo, size: 40, color: AppTheme.primaryGreen),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppLocalizations.of(context)!.addPhoto, 
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12, 
                                        color: context.subText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Basic Info
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (!isRetailOrGrocery) ...[
                          DropdownButtonFormField<String>(
                            value: _productType,
                            decoration: InputDecoration(
                              labelText: 'Item Type',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'product', child: Text('Standard Product (Inventory)')),
                              DropdownMenuItem(value: 'service', child: Text('Service (No Inventory)')),
                              DropdownMenuItem(value: 'package', child: Text('Package / Bundle')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _productType = val);
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.productNameLabel,
                            hintText: 'උදා: කිරි තේ / Milk Tea / White Sugar',
                            suffixIcon: SinhalaConvertSuffix(
                              controller: _nameController,
                              onConverted: () {
                                final sinhala = SinhalaTransliterationService.transliterate(_nameController.text);
                                if (_nameSinhalaController.text.trim().isEmpty) {
                                  _nameSinhalaController.text = sinhala;
                                }
                                setState(() {});
                              },
                            ),
                            helperText: _nameController.text.trim().isNotEmpty
                                ? (SinhalaTransliterationService.isSinhala(_nameController.text)
                                    ? '⚡ Auto Singlish Search Enabled (Cashiers can type in English alphabet)'
                                    : '⚡ Smart Sinhala Matching Active')
                                : null,
                            helperStyle: const TextStyle(fontSize: 11, color: AppTheme.primaryGreen),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return AppLocalizations.of(context)!.productNameRequired;
                            }
                            return null;
                          },
                        ),
                        SinhalaSuggestionBanner(
                          controller: _nameController,
                          onApplied: () {
                            if (_nameSinhalaController.text.trim().isEmpty) {
                              _nameSinhalaController.text = _nameController.text;
                            }
                            setState(() {});
                          },
                        ),
                        // Bilingual & Alias Section Toggle
                        InkWell(
                          onTap: () => setState(() => _showAdvancedBilingual = !_showAdvancedBilingual),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _showAdvancedBilingual ? Icons.expand_less : Icons.expand_more,
                                  size: 20,
                                  color: AppTheme.primaryGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'සිංහල / English & Search Aliases (Optional)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showAdvancedBilingual) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameSinhalaController,
                            decoration: InputDecoration(
                              labelText: 'Sinhala Name (සිංහල නම)',
                              hintText: 'උදා: කිරි තේ',
                              suffixIcon: SinhalaConvertSuffix(
                                controller: _nameSinhalaController,
                                onConverted: () => setState(() {}),
                              ),
                            ),
                          ),
                          SinhalaSuggestionBanner(
                            controller: _nameSinhalaController,
                            onApplied: () => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameEnglishController,
                            decoration: const InputDecoration(
                              labelText: 'English Name',
                              hintText: 'e.g. Milk Tea',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _searchAliasesController,
                            decoration: const InputDecoration(
                              labelText: 'Search Aliases (Singlish / Keywords)',
                              hintText: 'e.g. kiri the, milk tea, hot tea',
                              helperText: 'Comma-separated keywords for cashiers to find this item',
                              helperStyle: TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_isDetecting) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Scanning image...',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: context.subText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ] else if (_detectedResult != null && _detectedResult!.isDetected) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AnimateIn(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _nameController.text = _detectedResult!.productName;
                                      _selectedCategory = _detectedResult!.category;
                                      _detectedResult = null;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Autofilled name & category'),
                                        duration: const Duration(seconds: 1),
                                        backgroundColor: AppTheme.primaryGreen,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryGreen,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Auto',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _detectedResult!.productName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _barcodeController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.barcodeLabel,
                            hintText: AppLocalizations.of(context)!.optionalHint,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final barcode = await BarcodeScannerService.scanBarcode(context);
                                if (barcode != null) {
                                  setState(() {
                                    _barcodeController.text = barcode;
                                  });
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(AppLocalizations.of(context)!.barcodeScanned(barcode)),
                                      duration: const Duration(seconds: 1),
                                      backgroundColor: AppTheme.primaryGreen,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
 
                  const SizedBox(height: 20),
                  
                  // Pricing & Unit Info
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.scale_rounded, color: Color(0xFF10B981), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Base Measurement Unit',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Select how this product is stored and tracked in your inventory',
                                  style: GoogleFonts.inter(fontSize: 11, color: context.subText),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Unit Category Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildUnitChip('kg', '⚖️ Weight (kg)'),
                            _buildUnitChip('g', '⚖️ Grams (g)'),
                            _buildUnitChip('pcs', '🔢 Pieces (pcs)'),
                            _buildUnitChip('dozen', '🔢 Dozen (12)'),
                            _buildUnitChip('L', '💧 Liters (L)'),
                            _buildUnitChip('ml', '💧 Milliliters (ml)'),
                            _buildUnitChip('pack', '📦 Packets (pack)'),
                            _buildUnitChip('box', '📦 Boxes (box)'),
                            _buildUnitChip('bottle', '🍾 Bottles (bottle)'),
                            _buildUnitChip('can', '🥫 Cans (can)'),
                            _buildUnitChip('m', '📏 Meters (m)'),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Selling Price & Cost Price Fields
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!.sellingPriceLabel,
                                  hintText: '0.00',
                                  prefixText: '${globalAppRegion.currencySymbol} ',
                                  suffixText: '/ $_selectedUnit',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return AppLocalizations.of(context)!.priceRequired;
                                  }
                                  if (double.tryParse(value) == null) {
                                    return AppLocalizations.of(context)!.invalidPrice;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _costPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!.costPriceLabel,
                                  hintText: '0.00',
                                  prefixText: '${globalAppRegion.currencySymbol} ',
                                  suffixText: '/ $_selectedUnit',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        Builder(
                          builder: (context) {
                            final pPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
                            final pCost = double.tryParse(_costPriceController.text.trim());
                            if (pPrice <= 0) return const SizedBox.shrink();
                            final profit = pCost != null ? pPrice - pCost : pPrice;
                            final margin = pPrice > 0 && pCost != null ? ((profit / pPrice) * 100) : 100.0;
                            return Container(
                              margin: const EdgeInsets.only(top: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF10B981).withValues(alpha: 0.15),
                                    const Color(0xFF059669).withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.trending_up_rounded, color: Color(0xFF10B981), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Estimated Profit: ${globalAppRegion.currencySymbol} ${profit.toStringAsFixed(2)} / $_selectedUnit',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${margin.toStringAsFixed(1)}% Margin',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Selling Methods (Multiple Selling Modes)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.swap_horizontal_circle_outlined, color: AppTheme.primaryBlue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selling Methods (Flexible Billing Modes)',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Enable cashiers to sell loose (e.g. 250g, 500g) and/or in pre-packaged units',
                                  style: GoogleFonts.inter(fontSize: 11, color: context.subText),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Mode 1: Weight / Loose Card
                        InkWell(
                          onTap: () => setState(() => _allowLoose = !_allowLoose),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _allowLoose
                                  ? const Color(0xFF10B981).withValues(alpha: context.isDark ? 0.15 : 0.08)
                                  : (context.isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _allowLoose ? const Color(0xFF10B981) : context.borderColor.withValues(alpha: 0.5),
                                width: _allowLoose ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _allowLoose,
                                  activeColor: const Color(0xFF10B981),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _allowLoose = val);
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sell Loose / by Direct Units (e.g. 250g, 500g, 1kg)',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Rate: ${globalAppRegion.currencySymbol} ${_priceController.text.trim().isEmpty ? '0.00' : _priceController.text.trim()} / $_selectedUnit',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Mode 2: Pre-Packaged Item Card
                        InkWell(
                          onTap: () => setState(() => _allowPack = !_allowPack),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _allowPack
                                  ? const Color(0xFF10B981).withValues(alpha: context.isDark ? 0.15 : 0.08)
                                  : (context.isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _allowPack ? const Color(0xFF10B981) : context.borderColor.withValues(alpha: 0.5),
                                width: _allowPack ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _allowPack,
                                  activeColor: const Color(0xFF10B981),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _allowPack = val);
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sell as Pre-Packaged Item (e.g. 1kg Pack, 500g Pack)',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Custom pack selling price with automatic bulk inventory deduction',
                                        style: GoogleFonts.inter(fontSize: 11.5, color: context.subText),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_allowPack) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _packSizeController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                                        decoration: InputDecoration(
                                          labelText: 'Pack Size',
                                          hintText: '1.0',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        value: _packSizeUnit,
                                        decoration: InputDecoration(
                                          labelText: 'Size Unit',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'kg', child: Text('kg')),
                                          DropdownMenuItem(value: 'g', child: Text('g')),
                                          DropdownMenuItem(value: 'L', child: Text('L')),
                                          DropdownMenuItem(value: 'ml', child: Text('ml')),
                                          DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setState(() => _packSizeUnit = val);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        value: _packUnit,
                                        decoration: InputDecoration(
                                          labelText: 'Pack Unit',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'pack', child: Text('pack')),
                                          DropdownMenuItem(value: 'box', child: Text('box')),
                                          DropdownMenuItem(value: 'bottle', child: Text('bottle')),
                                          DropdownMenuItem(value: 'can', child: Text('can')),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setState(() => _packUnit = val);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _packPriceController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                                        decoration: InputDecoration(
                                          labelText: 'Pack Selling Price',
                                          hintText: '0.00',
                                          prefixText: '${globalAppRegion.currencySymbol} ',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _packCostPriceController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                                        decoration: InputDecoration(
                                          labelText: 'Pack Cost Price',
                                          hintText: '0.00',
                                          prefixText: '${globalAppRegion.currencySymbol} ',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
 
                  const SizedBox(height: 20),

                  // Supplier Selection
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supplier (Optional)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.subText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Consumer(
                          builder: (context, ref, child) {
                            final suppliersAsync = ref.watch(suppliersProvider);
                            return suppliersAsync.when(
                              data: (suppliers) {
                                if (suppliers.isEmpty) {
                                  return Text('No suppliers available. Add from Suppliers tab.', style: GoogleFonts.plusJakartaSans(color: context.subText, fontSize: 13));
                                }
                                return DropdownButtonFormField<int>(
                                  value: _selectedSupplierId,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  hint: const Text('Select a supplier'),
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('None'),
                                    ),
                                    ...suppliers.map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.name),
                                    )),
                                  ],
                                  onChanged: (val) => setState(() => _selectedSupplierId = val),
                                );
                              },
                              loading: () => const Center(child: const CircularProgressIndicator()),
                              error: (_, __) => const Text('Failed to load suppliers'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
 
                  const SizedBox(height: 20),
 
                  // Batch Tracking Toggle & Manual Stock
                  if (_productType == 'product')
                    AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(AppLocalizations.of(context)!.trackBatchesLabel),
                          subtitle: Text(AppLocalizations.of(context)!.trackBatchesSubtitle),
                          value: _trackBatches,
                          activeColor: AppTheme.primaryGreen,
                          onChanged: (val) {
                            setState(() => _trackBatches = val);
                          },
                        ),
                        if (_trackBatches) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 20, color: AppTheme.primaryGreen),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(context)!.batchStockNote,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12, 
                                      color: context.onSurface.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (!_trackBatches) ...[
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _stockController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(context)!.stockQuantityLabel,
                                    hintText: '0.0',
                                  ),
                                  validator: (value) {
                                    if (_trackBatches) return null;
                                    if (value != null && value.trim().isNotEmpty && double.tryParse(value.trim()) == null) {
                                      return AppLocalizations.of(context)!.invalidQuantity;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _minStockController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(context)!.minStockAlertLabel,
                                    hintText: '10.0',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (_productType == 'product') const SizedBox(height: 20),
                  
                  // Category Selection — Search and Subcategories
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.category,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.subText,
                              ),
                            ),
                            if (_selectedCategory != null)
                              Builder(
                                builder: (context) {
                                  String selectedPrefix = 'Selected';
                                  final locale = Localizations.localeOf(context).languageCode;
                                  if (locale == 'si') {
                                    selectedPrefix = 'තෝරාගෙන ඇත';
                                  } else if (locale == 'ta') {
                                    selectedPrefix = 'தேர்ந்தெடுக்கப்பட்டது';
                                  } else if (locale == 'hi') {
                                    selectedPrefix = 'चयनित';
                                  } else if (locale == 'bn') {
                                    selectedPrefix = 'নির্বাচিত';
                                  } else if (locale == 'dv') {
                                    selectedPrefix = 'ހޮވާފައިވަނީ';
                                  }
                                  return Text(
                                    '$selectedPrefix: ${context.getLocalizedCategory(_selectedCategory!)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Search box for categories
                        TextFormField(
                          controller: _categorySearchController,
                          decoration: InputDecoration(
                            hintText: 'Search categories...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _categorySearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _categorySearchController.clear();
                                      });
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),

                        if (_categorySearchController.text.trim().isNotEmpty) ...[
                          // Display filtered search results
                          Text(
                            'Search Results',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: context.subText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final query = _categorySearchController.text.trim().toLowerCase();
                              final matchingMain = CategoryConstants.mainCategories
                                  .where((cat) => cat.toLowerCase().contains(query) ||
                                                  context.getLocalizedCategory(cat).toLowerCase().contains(query))
                                  .toList();
                              final matchingSub = CategoryConstants.allSubcategories
                                  .where((sub) => sub.toLowerCase().contains(query) ||
                                                  context.getLocalizedCategory(sub).toLowerCase().contains(query))
                                  .toList();

                              if (matchingMain.isEmpty && matchingSub.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      'No categories found.',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: context.subText,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...matchingMain.map((main) {
                                    final isSelected = _selectedCategory == main;
                                    final color = CategoryIconUtil.getColorForMainCategory(main);
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCategory = main;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? color.withValues(alpha: 0.15)
                                              : context.cardColor,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? color : context.borderColor.withValues(alpha: 0.4),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              CategoryIconUtil.getIconForMainCategory(main),
                                              size: 16,
                                              color: isSelected ? color : context.subText,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              context.getLocalizedCategory(main),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                color: isSelected ? color : context.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  ...matchingSub.map((sub) {
                                    final isSelected = _selectedCategory == sub;
                                    final color = CategoryIconUtil.getColorForCategory(sub);
                                    final parentMain = CategoryConstants.getMainCategory(sub);
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCategory = sub;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? color.withValues(alpha: 0.15)
                                              : context.cardColor,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? color : context.borderColor.withValues(alpha: 0.4),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              CategoryIconUtil.getIconForCategory(sub),
                                              size: 16,
                                              color: isSelected ? color : context.subText,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${context.getLocalizedCategory(sub)} (${context.getLocalizedCategory(parentMain)})',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                color: isSelected ? color : context.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                          ),
                        ] else ...[
                          // Display main categories
                          Text(
                            'Main Categories',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: context.subText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: CategoryConstants.mainCategories.map((main) {
                              final parentMain = CategoryConstants.getMainCategory(_selectedCategory);
                              final isParentSelected = parentMain == main;
                              final color = CategoryIconUtil.getColorForMainCategory(main);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = main;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isParentSelected
                                        ? color.withValues(alpha: 0.15)
                                        : context.cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isParentSelected ? color : context.borderColor.withValues(alpha: 0.4),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CategoryIconUtil.getIconForMainCategory(main),
                                        size: 16,
                                        color: isParentSelected ? color : context.subText,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        context.getLocalizedCategory(main),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: isParentSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isParentSelected ? color : context.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          // If a main category is selected, display its subcategories below it
                          Builder(
                            builder: (context) {
                              final parentMain = CategoryConstants.getMainCategory(_selectedCategory);
                              final subs = CategoryConstants.subsFor(parentMain);
                              if (subs.isEmpty) return const SizedBox.shrink();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (context) {
                                      final locale = Localizations.localeOf(context).languageCode;
                                      final localizedParent = context.getLocalizedCategory(parentMain);
                                      String label;
                                      if (locale == 'si') {
                                        label = '$localizedParent සඳහා උපකාණ්ඩ';
                                      } else if (locale == 'ta') {
                                        label = '$localizedParent இன் துணைப்பிரிவுகள்';
                                      } else if (locale == 'hi') {
                                        label = '$localizedParent के लिए उपश्रेणियाँ';
                                      } else if (locale == 'bn') {
                                        label = '$localizedParent-এর উপশ্রেণী';
                                      } else if (locale == 'dv') {
                                        label = '$localizedParent ގެ ސަބްކެޓަގަރީތައް';
                                      } else {
                                        label = 'Subcategories for $parentMain';
                                      }
                                      return Text(
                                        label,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: context.subText,
                                        ),
                                      );
                                    }
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: subs.map((sub) {
                                      final isSelected = _selectedCategory == sub;
                                      final color = CategoryIconUtil.getColorForCategory(sub);
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedCategory = sub;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? color.withValues(alpha: 0.15)
                                                : context.cardColor,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected ? color : context.borderColor.withValues(alpha: 0.4),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                CategoryIconUtil.getIconForCategory(sub),
                                                size: 16,
                                                color: isSelected ? color : context.subText,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                context.getLocalizedCategory(sub),
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                  color: isSelected ? color : context.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  
                  GradientButton(
                    onPressed: _isSubmitting ? null : _saveProduct,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : Text(widget.product != null 
                            ? AppLocalizations.of(context)!.updateProduct 
                            : AppLocalizations.of(context)!.addProduct),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildUnitChip(String unit, String label) {
    final isSelected = _selectedUnit == unit;
    return InkWell(
      onTap: () => setState(() => _selectedUnit = unit),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981)
              : (context.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : (context.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (context.isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}


