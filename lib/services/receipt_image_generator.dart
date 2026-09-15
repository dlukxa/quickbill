import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../providers/preference_provider.dart';
import '../utils/receipt_theme.dart';
import '../widgets/receipt/receipt_widget.dart';
import 'local_media_storage_service.dart';

/// High-performance Flutter receipt rendering engine.
/// Renders the Flutter [ReceiptWidget] directly into an image using Flutter's
/// native text shaping (HarfBuzz) and layout engine, guaranteeing 100% correct
/// Sinhala Unicode rendering with zero reliance on thermal printer fonts.
class ReceiptImageGenerator {
  ReceiptImageGenerator._();
  static final ReceiptImageGenerator instance = ReceiptImageGenerator._();

  /// Captures an on-screen receipt widget identified by [globalKey] to PNG bytes.
  Future<Uint8List> captureFromKey(
    GlobalKey globalKey, {
    double pixelRatio = 1.0,
  }) async {
    final boundary = globalKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception(
          'Could not find RenderRepaintBoundary for receipt GlobalKey');
    }

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode captured receipt to PNG');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// Offscreen receipt rasterization pipeline.
  /// Renders [ReceiptWidget] completely offscreen without mounting to UI,
  /// suitable for background auto-printing or background thermal slips.
  Future<Uint8List> generateReceiptImage({
    required Sale sale,
    required List<SaleItem> items,
    required AppSettings settings,
    double? cashReceived,
    double? change,
    String? overridePaperSize,
    String? overrideLanguage,
    String? overrideTemplate,
    double pixelRatio = 1.0,
  }) async {
    final bool is58mm = overridePaperSize == '58mm' ||
        (overridePaperSize == null && settings.is58mm);
    final double targetWidth = ReceiptTheme.getReceiptWidth(is58mm, settings: settings);

    ui.Image? logoUiImage;
    if (settings.showReceiptLogo) {
      final logoBytes = await _loadLogoBytes(settings.shopLogoUrl);
      if (logoBytes != null && logoBytes.isNotEmpty) {
        try {
          final codec = await ui.instantiateImageCodec(logoBytes);
          final frame = await codec.getNextFrame();
          logoUiImage = frame.image;
        } catch (e) {
          debugPrint('ReceiptImageGenerator: Failed to decode logo image: $e');
        }
      }
    }

    final widget = ReceiptWidget(
      sale: sale,
      items: items,
      settings: settings,
      cashReceived: cashReceived,
      change: change,
      overridePaperSize: overridePaperSize,
      overrideLanguage: overrideLanguage,
      overrideTemplate: overrideTemplate,
      logoUiImage: logoUiImage,
    );

    try {
      return await renderWidgetToImage(
        widget,
        targetWidth: targetWidth,
        pixelRatio: pixelRatio,
      );
    } finally {
      logoUiImage?.dispose();
    }
  }

  Future<Uint8List?> _loadLogoBytes(String? shopLogoUrl) async {
    if (shopLogoUrl != null && shopLogoUrl.trim().isNotEmpty) {
      final trimmed = shopLogoUrl.trim();
      // 1. If local file
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        try {
          final file = File(trimmed);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) return bytes;
          }
        } catch (_) {}
      } else {
        // 2. If remote URL, check cached file or download
        try {
          final file = await LocalMediaStorageService.instance.getOrDownloadImage(trimmed);
          if (file != null && await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) return bytes;
          }
        } catch (_) {}
      }
    }

    // 3. Fallback to default asset logo
    try {
      final byteData = await rootBundle.load('assets/images/logo.png');
      return byteData.buffer.asUint8List();
    } catch (_) {
      // If rootBundle fails (e.g. in test environment), try direct file read
      try {
        final fallbackFile = File('assets/images/logo.png');
        if (fallbackFile.existsSync()) {
          return fallbackFile.readAsBytesSync();
        }
      } catch (_) {}
      return null;
    }
  }


  /// Low-level offscreen widget-to-image rasterizer using Flutter's [PipelineOwner].
  Future<Uint8List> renderWidgetToImage(
    Widget widget, {
    required double targetWidth,
    double pixelRatio = 1.0,
  }) async {
    final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;

    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());

    final renderView = RenderView(
      view: view,
      child: RenderPositionedBox(
        alignment: Alignment.topLeft,
        child: repaintBoundary,
      ),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tightFor(width: targetWidth),
        devicePixelRatio: pixelRatio,
      ),
    );

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.white,
          child: widget,
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final ui.Image image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
    try {
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode rasterized receipt image to PNG');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
