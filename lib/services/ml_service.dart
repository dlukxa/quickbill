import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class MLService {
  late final BarcodeScanner _barcodeScanner;
  ObjectDetector? _objectDetector;
  bool _isCustomModelLoaded = false;
  String _currentMode = 'generic'; // generic, custom

  MLService() {
    _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
    _initializeDetector();
  }

  Future<void> _initializeDetector() async {
    // Start with generic object detection
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);
    _currentMode = 'generic';
  }

  Future<bool> loadCustomModel(String assetPath) async {
    try {
      final modelPath = await _getModelPath(assetPath);
      final options = LocalObjectDetectorOptions(
        mode: DetectionMode.stream,
        modelPath: modelPath,
        classifyObjects: true,
        multipleObjects: true,
      );
      
      await _objectDetector?.close();
      _objectDetector = ObjectDetector(options: options);
      _isCustomModelLoaded = true;
      _currentMode = 'custom';
      return true;
    } catch (e) {
      debugPrint('Error loading custom model: $e');
      return false;
    }
  }

  Future<String> _getModelPath(String asset) async {
    final path = '${(await getApplicationSupportDirectory()).path}/$asset';
    await Directory(dirname(path)).create(recursive: true);
    final file = File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(asset);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }

  Future<List<Barcode>> scanBarcodes(InputImage inputImage) async {
    try {
      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        debugPrint('MLService: Found ${barcodes.length} barcodes');
      }
      return barcodes;
    } catch (e) {
      debugPrint('MLService: Barcode scan error: $e');
      return [];
    }
  }

  Future<List<DetectedObject>> detectObjects(InputImage inputImage) async {
    if (_objectDetector == null) return [];
    try {
      return await _objectDetector!.processImage(inputImage);
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _barcodeScanner.close();
    _objectDetector?.close();
  }

  Future<void> resetToGenericDetector() async {
    await _objectDetector?.close();
    await _initializeDetector();
    _isCustomModelLoaded = false;
    _currentMode = 'generic';
  }
  
  bool get isCustomModelLoaded => _isCustomModelLoaded;
  String get currentMode => _currentMode;
}
