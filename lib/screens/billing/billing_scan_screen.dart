import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/theme.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../models/scan_result.dart';
import '../../providers/cart_provider.dart';
import '../../services/scan_service.dart';
import '../../widgets/scan/scan_overlay.dart';
import '../../widgets/scan/scan_result_toast.dart';
import '../../utils/formatters.dart';
import '../../services/weight_service.dart';
import '../../generated/l10n/app_localizations.dart';
import 'batch_selection_sheet.dart';

class BillingScanScreen extends ConsumerStatefulWidget {
  const BillingScanScreen({super.key});

  @override
  ConsumerState<BillingScanScreen> createState() => _BillingScanScreenState();
}

class _BillingScanScreenState extends ConsumerState<BillingScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final ScanService _scanService = ScanService();
  
  bool _isCameraInitialized = false;
  bool _isSimulationMode = true; 
  
  // Weight Integration
  final WeightService _weightService = WeightService();
  double _scaleWeight = 0.0;
  StreamSubscription<double>? _weightSubscription;
  
  Product? _detectedProduct;
  DateTime? _lastDetectionTime;

  final List<ScanResult> _recentScans = [];
  ScanResult? _currentResult;
  bool _isScanProcessing = false;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _setupWeightListener();
    _isCameraInitialized = true; // MobileScanner handles its own init
  }

  void _setupWeightListener() {
    _weightSubscription = _weightService.weightStream.listen((weight) {
      if (mounted) {
        setState(() => _scaleWeight = weight);
      }
    });
    // Enable simulation by default if _isSimulationMode is true
    _weightService.setSimulationMode(_isSimulationMode);
  }


  @override
  void dispose() {
    _weightSubscription?.cancel();
    _weightService.setSimulationMode(false);
    _scannerController.dispose();
    _scanService.reset();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(String? barcodeValue) async {
    if (_isScanProcessing || barcodeValue == null) return;
    
    _isScanProcessing = true;
    final result = await _scanService.handleScan(barcodeValue);

    if (result.status == ScanStatus.duplicate) {
      _isScanProcessing = false;
      return;
    }

    if (result.status == ScanStatus.batchRequired) {
      HapticFeedback.mediumImpact();
      try {
        await _scannerController.stop();
      } catch (e) {
        // Ignore camera toggle errors
      }

      if (mounted) {
        final selectedBatch = await BatchSelectionSheet.show(context, result.product!);
        
        if (selectedBatch != null && mounted) {
          HapticFeedback.mediumImpact();
          ref.read(cartProvider.notifier).addProduct(
            result.product!,
            batch: selectedBatch,
          );
          
          final successResult = ScanResult(
            status: ScanStatus.added,
            product: result.product,
            batch: selectedBatch,
            message: '${result.product!.name} added',
            barcode: barcodeValue,
          );
          
          setState(() {
            _currentResult = successResult;
            _recentScans.insert(0, successResult);
            if (_recentScans.length > 5) _recentScans.removeLast();
          });
          
          // Clear the toast after 1.5 seconds
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              setState(() => _currentResult = null);
            }
          });
        }
      }
      
      try {
        await _scannerController.start();
      } catch (e) {
        // Ignore
      }
      
      await Future.delayed(const Duration(seconds: 1));
      _isScanProcessing = false;
      return;
    }

    if (mounted) {
      if (result.status == ScanStatus.added || result.status == ScanStatus.addedWithWarning) {
        HapticFeedback.mediumImpact();
        ref.read(cartProvider.notifier).addProduct(
          result.product!,
          batch: result.batch,
        );
      } else {
        HapticFeedback.heavyImpact();
      }

      setState(() {
        _currentResult = result;
        _recentScans.insert(0, result);
        if (_recentScans.length > 5) _recentScans.removeLast();
      });

      // Clear the toast after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _currentResult = null);
        }
      });
    }

    // Delay slightly to prevent rapid multiple scans of same barcode
    await Future.delayed(const Duration(seconds: 1));
    _isScanProcessing = false;
  }

  Future<void> _addDetectedProduct(Product product) async {
    if (product.unit != 'pcs') {
      // Use scale weight if available and above zero
      if (_scaleWeight > 0.1) {
        ref.read(cartProvider.notifier).addProduct(product, quantity: _scaleWeight);
        _onSuccessAdd(product);
        return;
      }
      
      // Show weight dialog if no scale weight
      double weight = 1.0;
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.addWeightToBill(product.name)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.enterWeightHint(product.unit)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (weight > 0.1) setDialogState(() => weight -= 0.1);
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      weight.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => setDialogState(() => weight += 0.1),
                      icon: const Icon(Icons.add_circle),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
              ElevatedButton(
                onPressed: () {
                  ref.read(cartProvider.notifier).addProduct(product, quantity: weight);
                  Navigator.pop(context);
                },
                child: Text(AppLocalizations.of(context)!.addToBill),
              ),
            ],
          ),
        ),
      );
    } else {
      ref.read(cartProvider.notifier).addProduct(product);
      _onSuccessAdd(product);
    }
  }

  void _onSuccessAdd(Product product) {
    HapticFeedback.mediumImpact();
    setState(() => _detectedProduct = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.addedToCart(product.name)),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final cartTotal = ref.watch(cartTotalProvider);
    final cartItemsCount = ref.watch(cartProvider).length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Camera Section
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      _onBarcodeDetected(barcodes.first.rawValue);
                    }
                  },
                ),

                // Targeting Frame
                const ScanOverlay(),
                
                // Smart Suggestion Overlay
                // Smart Suggestion Overlay (Simplified for MobileScanner)
                if (_detectedProduct != null)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppTheme.primaryBlue,
                            child: Icon(Icons.inventory_2, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _detectedProduct!.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _addDetectedProduct(_detectedProduct!),
                            child: Text(AppLocalizations.of(context)!.add),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _detectedProduct = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Done Button (Top Left)
                Positioned(
                  top: 50,
                  left: 16,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

                // Flash Toggle (Top Right)
                Positioned(
                  top: 50,
                  right: 16,
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: ValueListenableBuilder(
                            valueListenable: _scannerController,
                            builder: (context, state, child) {
                              final torchState = state.torchState;
                              return Icon(
                                torchState == TorchState.off ? Icons.flash_off : Icons.flash_on,
                                color: Colors.white,
                              );
                            },
                          ),
                          onPressed: () => _scannerController.toggleTorch(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CircleAvatar(
                        backgroundColor: _isSimulationMode ? Colors.blueAccent : Colors.black54,
                        child: IconButton(
                          icon: Icon(
                            _isSimulationMode ? Icons.auto_fix_high : Icons.auto_fix_off,
                            color: Colors.white,
                          ),
                          tooltip: AppLocalizations.of(context)!.toggleSimulation,
                          onPressed: () {
                            setState(() {
                              _isSimulationMode = !_isSimulationMode;
                              _weightService.setSimulationMode(_isSimulationMode);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Success/Error Toast
                if (_currentResult != null)
                  Positioned(
                    top: 120,
                    left: 20,
                    right: 20,
                    child: Center(child: ScanResultToast(result: _currentResult!)),
                  ),

                // (Redundant hint removed, already in ScanOverlay)
              ],
            ),
          ),

          // Bottom History & Summary
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.recentScans,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.2),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.itemsCount(cartItemsCount.toString()),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // History List
                  Expanded(
                    child: _recentScans.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_scanner, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 8),
                                Text(AppLocalizations.of(context)!.scanToBuildBill, style: TextStyle(color: Colors.grey[400])),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _recentScans.length,
                            itemBuilder: (context, index) {
                              final item = _recentScans[index];
                              return _HistoryItem(result: item, isNewest: index == 0);
                            },
                          ),
                  ),
                  
                  const Divider(),
                  
                  // Summary Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)!.total, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        Formatters.currency(cartTotal),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.doneScanning, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final ScanResult result;
  final bool isNewest;

  const _HistoryItem({required this.result, required this.isNewest});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (result.status) {
      case ScanStatus.added:
      case ScanStatus.addedWithWarning:
        color = AppTheme.primaryGreen;
        icon = Icons.add_circle_outline;
        break;
      case ScanStatus.notFound:
        color = AppTheme.primaryBlue;
        icon = Icons.help_outline;
        break;
      default:
        color = AppTheme.errorRed;
        icon = Icons.block_flipped;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isNewest ? FontWeight.bold : FontWeight.normal,
                color: isNewest ? Colors.black : Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            result.barcode.substring(result.barcode.length > 5 ? result.barcode.length - 5 : 0),
            style: TextStyle(fontSize: 10, color: Colors.grey[400], fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
