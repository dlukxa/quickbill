import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../generated/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../providers/batch_provider.dart';
import '../../services/barcode_service.dart';
import '../../services/batch_ocr_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animate_in.dart';
import '../../utils/region_utils.dart';
import 'ocr_scanner_screen.dart';

class AddBatchScreen extends ConsumerStatefulWidget {
  final Product product;
  final ProductBatch? batch;

  const AddBatchScreen({
    super.key,
    required this.product,
    this.batch,
  });

  @override
  ConsumerState<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends ConsumerState<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batchNumberController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _stockController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _factoryController = TextEditingController();
  final _expiryController = TextEditingController();
  final _mfgController = TextEditingController();
  
  DateTime? _selectedExpiryDate;
  DateTime? _selectedMfgDate;
  bool _isSubmitting = false;
  bool _isOcrLoading = false;
  String _ocrLoadingMessage = 'Scanning label...';

  @override
  void initState() {
    super.initState();
    if (widget.batch != null) {
      _batchNumberController.text = widget.batch!.batchNumber;
      _barcodeController.text = widget.batch!.barcode;
      _stockController.text = widget.batch!.stock.toString();
      _purchasePriceController.text = widget.batch!.purchasePrice?.toString() ?? '';
      _factoryController.text = widget.batch!.factoryLocation ?? '';
      _selectedExpiryDate = widget.batch!.expiryDate;
      if (_selectedExpiryDate != null) {
        _expiryController.text = DateFormat('yyyy-MM-dd').format(_selectedExpiryDate!);
      }
      _selectedMfgDate = widget.batch!.productionDate;
      if (_selectedMfgDate != null) {
        _mfgController.text = DateFormat('yyyy-MM-dd').format(_selectedMfgDate!);
      }
    } else {
      // Default expiry 6 months from now
      _selectedExpiryDate = DateTime.now().add(const Duration(days: 180));
      _expiryController.text = DateFormat('yyyy-MM-dd').format(_selectedExpiryDate!);
      // Auto generate batch number
      _generateBatchNumber();
    }
  }

  void _generateBatchNumber() {
    final date = DateTime.now();
    final factory = _factoryController.text.isNotEmpty 
        ? _factoryController.text.substring(0, min(3, _factoryController.text.length)) 
        : 'GEN';
    _batchNumberController.text = ProductBatch.generateBatchNumber(factory, date);
  }
  
  int min(int a, int b) => a < b ? a : b;

  @override
  void dispose() {
    _batchNumberController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _purchasePriceController.dispose();
    _factoryController.dispose();
    _expiryController.dispose();
    _mfgController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final firstDate = DateTime(2020);
    final lastDate = DateTime(2035);
    var initialDate = _selectedExpiryDate ?? DateTime.now();
    // Clamp initialDate within the allowed range
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null && picked != _selectedExpiryDate) {
      setState(() {
        _selectedExpiryDate = picked;
        _expiryController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectMfgDate(BuildContext context) async {
    final firstDate = DateTime(2015);
    final lastDate = DateTime.now().add(const Duration(days: 30));
    var initialDate = _selectedMfgDate ?? DateTime.now();
    // Clamp initialDate within the allowed range
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null && picked != _selectedMfgDate) {
      setState(() {
        _selectedMfgDate = picked;
        _mfgController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _scanPackagingLabel() async {
    final ImagePicker picker = ImagePicker();
    final OcrSelectionResult? selection = await showModalBottomSheet<OcrSelectionResult?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => const _OcrSelectionSheet(),
    );

    if (!mounted) return;
    if (selection == null) return;

    File? imageFile;
    
    // 1. If it's live camera scanner, run it immediately
    if (selection.mode == OcrScanMode.localLive) {
      final ocrResult = await Navigator.push<BatchOcrResult?>(
        context,
        MaterialPageRoute(
          builder: (context) => const OcrScannerScreen(),
        ),
      );
      if (!mounted) return;
      if (ocrResult != null) {
        _applyOcrResult(ocrResult);
      }
      return;
    }

    // 2. Pick image based on selection mode
    final ImageSource source = (selection.mode == OcrScanMode.localPhoto || selection.mode == OcrScanMode.gemmaPhoto)
        ? ImageSource.camera
        : ImageSource.gallery;

    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 640,
      maxHeight: 640,
      imageQuality: 80,
    );
    if (pickedFile == null) return;
    if (!mounted) return;
    imageFile = File(pickedFile.path);

    // 3. Process image based on local or cloud mode
    setState(() {
      _isOcrLoading = true;
      _ocrLoadingMessage = (selection.mode == OcrScanMode.gemmaPhoto || selection.mode == OcrScanMode.gemmaGallery)
          ? 'Gemma AI is analyzing label...'
          : 'Local AI is parsing label...';
    });
    
    final messenger = ScaffoldMessenger.of(context);

    try {
      BatchOcrResult? ocrResult;
      if (selection.mode == OcrScanMode.gemmaPhoto || selection.mode == OcrScanMode.gemmaGallery) {
        // Run Gemma Cloud AI scan
        try {
          ocrResult = await BatchOcrService.scanWithGemmaCloud(imageFile);
        } catch (e) {
          final errorStr = e.toString();
          if (errorStr.contains('QUOTA_EXHAUSTED')) {
            if (mounted) {
              final useFallback = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange),
                      SizedBox(width: 8),
                      Text('AI Cloud Quota Limit'),
                    ],
                  ),
                  content: Text(
                    'The Google AI Studio prepayment credits for this API key are depleted. '
                    'Would you like to run the Offline Local Scanner on this photo instead?',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                      onPressed: () => Navigator.pop(dialogContext, false),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Run Offline Scanner', style: TextStyle(color: Colors.white)),
                      onPressed: () => Navigator.pop(dialogContext, true),
                    ),
                  ],
                ),
              );

              if (useFallback == true) {
                // Update loading state
                setState(() {
                  _ocrLoadingMessage = 'Local AI is parsing label...';
                });
                ocrResult = await BatchOcrService.scanPackagingLabel(imageFile);
              } else {
                return;
              }
            }
          } else {
            rethrow;
          }
        }
      } else {
        // Run Offline local scan
        ocrResult = await BatchOcrService.scanPackagingLabel(imageFile);
      }

      if (ocrResult != null) {
        _applyOcrResult(ocrResult);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Scanning failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOcrLoading = false;
        });
      }
    }
  }

  void _applyOcrResult(BatchOcrResult result) {
    setState(() {
      if (result.batchNumber != null && result.batchNumber!.isNotEmpty) {
        _batchNumberController.text = result.batchNumber!;
      }
      if (result.mrp != null) {
        _purchasePriceController.text = result.mrp!.toStringAsFixed(2);
      }
      if (result.expiryDate != null) {
        _selectedExpiryDate = result.expiryDate;
        _expiryController.text = DateFormat('yyyy-MM-dd').format(result.expiryDate!);
      }
      if (result.mfgDate != null) {
        _selectedMfgDate = result.mfgDate;
        _mfgController.text = DateFormat('yyyy-MM-dd').format(result.mfgDate!);
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Label details applied successfully!'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    }
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final barcode = _barcodeController.text.trim();
      
      if (barcode.isNotEmpty) {
        // 1. Check if the barcode is used by another product as its primary barcode
        final existingResult = await ref.read(databaseServiceProvider).findByBarcode(barcode);
        if (existingResult != null) {
          final existingProduct = existingResult['product'] as Product;
          if (existingProduct.id != widget.product.id) {
            setState(() => _isSubmitting = false);
            if (mounted) {
              _showBarcodeErrorDialog(
                context,
                'The barcode "$barcode" is already assigned to a different product: "${existingProduct.name}".',
              );
            }
            return;
          }
        }

        // 2. Check if the barcode is already used by ANY batch in the product_batches table (including deleted ones)
        final db = ref.read(databaseServiceProvider);
        var existingBatch = await db.getBatchByBarcodeDirect(barcode, includeDeleted: true);
        if (existingBatch != null && existingBatch.deleted) {
          // Automatically free up the barcode from the soft-deleted batch so it can be reused
          await db.freeDeletedBatchBarcode(existingBatch.id!, barcode);
          existingBatch = null;
        }

        if (existingBatch != null) {
          final isDifferentBatch = widget.batch == null || existingBatch.id != widget.batch!.id;
          if (isDifferentBatch) {
            setState(() => _isSubmitting = false);
            if (mounted) {
              String errorMsg = '';
              if (existingBatch.productId != widget.product.id) {
                final otherProduct = await db.getProductById(existingBatch.productId);
                if (!mounted) return;
                final prodName = otherProduct?.name ?? 'another product';
                errorMsg = 'The barcode "$barcode" is already assigned to a batch of product "$prodName".';
              } else {
                errorMsg = 'The barcode "$barcode" is already assigned to another batch (Batch ${existingBatch.batchNumber}) of this product.';
              }
              if (mounted) {
                _showBarcodeErrorDialog(context, errorMsg);
              }
            }
            return;
          }
        }
      }

      if (widget.batch != null) {
        // Update existing batch
        final updatedBatch = widget.batch!.copyWith(
          batchNumber: _batchNumberController.text.trim(),
          barcode: _barcodeController.text.trim(),
          stock: double.parse(_stockController.text),
          purchasePrice: _purchasePriceController.text.isEmpty 
              ? null 
              : double.parse(_purchasePriceController.text),
          expiryDate: _selectedExpiryDate,
          productionDate: _selectedMfgDate,
          factoryLocation: _factoryController.text.isEmpty ? null : _factoryController.text,
        );
        await ref.read(batchActionsProvider).updateBatch(updatedBatch);
      } else {
        // Add new batch
        final batch = ProductBatch(
          productId: widget.product.id!,
          batchNumber: _batchNumberController.text.trim(),
          barcode: _barcodeController.text.trim(),
          stock: double.parse(_stockController.text),
          initialStock: double.parse(_stockController.text),
          purchasePrice: _purchasePriceController.text.isEmpty 
              ? null 
              : double.parse(_purchasePriceController.text),
          expiryDate: _selectedExpiryDate,
          productionDate: _selectedMfgDate,
          factoryLocation: _factoryController.text.isEmpty ? null : _factoryController.text,
        );
        await ref.read(batchActionsProvider).addBatch(batch);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.batch != null 
              ? AppLocalizations.of(context)!.batchUpdatedSuccessfully 
              : AppLocalizations.of(context)!.batchAddedSuccessfully)),
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

  void _showBarcodeErrorDialog(BuildContext context, String errorMsg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Barcode Already Exists',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          errorMsg,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.batch != null 
            ? AppLocalizations.of(context)!.editBatch(widget.product.name) 
            : AppLocalizations.of(context)!.addBatch(widget.product.name),
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: AnimateIn(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Smart Label Scan Button
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      onTap: _isSubmitting ? null : _scanPackagingLabel,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.document_scanner_outlined, color: AppTheme.primaryGreen, size: 24),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scan Packaging Label',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                    fontSize: 14,
                                  ),
                                ),
                                const Text(
                                  'Auto-extract Batch No, Expiry & MRP',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Batch Number (Auto-generated but editable)
                        TextFormField(
                          controller: _batchNumberController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.batchNumberLabel,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _generateBatchNumber,
                              tooltip: AppLocalizations.of(context)!.regenerateTooltip,
                            ),
                          ),
                          validator: (value) => 
                              value == null || value.isEmpty ? AppLocalizations.of(context)!.required : null,
                        ),
                        const SizedBox(height: 16),

                        // Barcode Scanner
                        TextFormField(
                          controller: _barcodeController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.batchBarcodeLabel,
                            hintText: AppLocalizations.of(context)!.batchBarcodeHint,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final localizations = AppLocalizations.of(context);
                                final barcode = await BarcodeScannerService.scanBarcode(context);
                                if (barcode != null) {
                                  setState(() {
                                    _barcodeController.text = barcode;
                                  });
                                  if (localizations != null) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(localizations.barcodeScanned(barcode)),
                                        duration: const Duration(seconds: 1),
                                        backgroundColor: AppTheme.primaryGreen,
                                      ),
                                    );
                                  }
                                } else {
                                  if (localizations != null) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(localizations.barcodeScanCancelled)),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          validator: (value) => 
                              value == null || value.isEmpty ? AppLocalizations.of(context)!.required : null,
                        ),
                        const SizedBox(height: 8),
                        // Auto-generate barcode button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _barcodeController.text = 'B-${_batchNumberController.text}';
                              });
                            },
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: Text(AppLocalizations.of(context)!.generateBarcode),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Stock & Price
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _stockController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!.quantityLabel,
                                  hintText: '0.0',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return AppLocalizations.of(context)!.required;
                                  if (double.tryParse(value) == null) return AppLocalizations.of(context)!.invalidPrice;
                                  if (double.parse(value) <= 0) return AppLocalizations.of(context)!.mustBeGreaterThanZero;
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _purchasePriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!.costPriceLabel,
                                  prefixText: '${globalAppRegion.currencySymbol} ',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Manufacturing Date (MFD)
                        TextFormField(
                          controller: _mfgController,
                          readOnly: true,
                          onTap: () => _selectMfgDate(context),
                          decoration: InputDecoration(
                            labelText: 'Manufacturing Date (MFD)',
                            hintText: 'Select manufacturing date',
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_selectedMfgDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _selectedMfgDate = null;
                                        _mfgController.clear();
                                      });
                                    },
                                  ),
                                const Icon(Icons.calendar_today_outlined),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Expiry Date
                        TextFormField(
                          controller: _expiryController,
                          readOnly: true,
                          onTap: () => _selectDate(context),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.expiryDateLabel,
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_selectedExpiryDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _selectedExpiryDate = null;
                                        _expiryController.clear();
                                      });
                                    },
                                  ),
                                const Icon(Icons.calendar_today),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: // Factory / Supplier
                      TextFormField(
                        controller: _factoryController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.factorySupplierLabel,
                          hintText: AppLocalizations.of(context)!.optionalHint,
                        ),
                      ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  GradientButton(
                    onPressed: _isSubmitting ? null : _saveBatch,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : Text(widget.batch != null 
                            ? AppLocalizations.of(context)!.updateBatch 
                            : AppLocalizations.of(context)!.saveBatch),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      if (_isOcrLoading)
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color ?? const Color(0xFF1A1D27),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.primaryGreen),
                        const SizedBox(height: 16),
                        Text(
                          _ocrLoadingMessage,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please hold on a moment',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  }
}

enum OcrScanMode {
  localLive,
  localPhoto,
  localGallery,
  gemmaPhoto,
  gemmaGallery,
}

class OcrSelectionResult {
  final OcrScanMode mode;
  final File? file;

  OcrSelectionResult({required this.mode, this.file});
}

class _OcrSelectionSheet extends StatefulWidget {
  const _OcrSelectionSheet();

  @override
  State<_OcrSelectionSheet> createState() => _OcrSelectionSheetState();
}

class _OcrSelectionSheetState extends State<_OcrSelectionSheet> {
  bool _showCloudSources = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            firstCurve: Curves.easeInOut,
            secondCurve: Curves.easeInOut,
            crossFadeState: _showCloudSources 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            firstChild: _buildMainMenu(),
            secondChild: _buildCloudSourcesMenu(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 40),
            Text(
              'Batch Label Scanner',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Gemma Cloud AI Scan Card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryPurple.withValues(alpha: 0.15),
                AppTheme.primaryPurple.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.4), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _showCloudSources = true;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppTheme.primaryPurple,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Gemma Cloud AI Scan',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'AI',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ultra-accurate cloud model. Best for challenging, small, or dot-matrix labels.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  'OFFLINE LOCAL SCANNERS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
        ),
        
        // Option 1: Live camera
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam, color: AppTheme.primaryGreen, size: 22),
            ),
            title: Text(
              'Live Camera Scanner',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              'Point camera to scan details in real-time',
              style: GoogleFonts.plusJakartaSans(fontSize: 11),
            ),
            onTap: () {
              Navigator.pop(context, OcrSelectionResult(mode: OcrScanMode.localLive));
            },
          ),
        ),
        
        // Option 2: Take Photo Offline
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: AppTheme.primaryGreen, size: 22),
            ),
            title: Text(
              'Take Photo Offline',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              'Capture a photo to parse locally offline',
              style: GoogleFonts.plusJakartaSans(fontSize: 11),
            ),
            onTap: () {
              Navigator.pop(context, OcrSelectionResult(mode: OcrScanMode.localPhoto));
            },
          ),
        ),
        
        // Option 3: Choose Gallery Offline
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_library, color: Colors.blue, size: 22),
            ),
            title: Text(
              'Choose Gallery Offline',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              'Select an existing image to parse offline',
              style: GoogleFonts.plusJakartaSans(fontSize: 11),
            ),
            onTap: () {
              Navigator.pop(context, OcrSelectionResult(mode: OcrScanMode.localGallery));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCloudSourcesMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _showCloudSources = false;
                });
              },
            ),
            Text(
              'Gemma Cloud AI',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 16),
        
        Text(
          'Choose an option to capture/select the packaging label. Gemma Cloud will analyze the image to parse batch details.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context, OcrSelectionResult(mode: OcrScanMode.gemmaPhoto));
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: AppTheme.primaryPurple, size: 24),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Take Photo',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context, OcrSelectionResult(mode: OcrScanMode.gemmaGallery));
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo_library, color: Colors.blue, size: 24),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'From Gallery',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
