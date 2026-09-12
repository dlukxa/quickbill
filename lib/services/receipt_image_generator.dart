import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../providers/preference_provider.dart';
import '../utils/receipt_theme.dart';
import '../widgets/receipt/receipt_widget.dart';

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
    final double targetWidth = ReceiptTheme.getReceiptWidth(is58mm);

    final widget = ReceiptWidget(
      sale: sale,
      items: items,
      settings: settings,
      cashReceived: cashReceived,
      change: change,
      overridePaperSize: overridePaperSize,
      overrideLanguage: overrideLanguage,
      overrideTemplate: overrideTemplate,
    );

    return renderWidgetToImage(
      widget,
      targetWidth: targetWidth,
      pixelRatio: pixelRatio,
    );
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
