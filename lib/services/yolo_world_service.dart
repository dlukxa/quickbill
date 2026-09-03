import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'category_detection_service.dart';

class YoloWorldDetection {
  final String productName;
  final String category;
  final double confidence;
  final Rect boundingBox; // Normalized coordinates (0.0 to 1.0)
  final bool isDetected;

  YoloWorldDetection({
    required this.productName,
    required this.category,
    required this.confidence,
    required this.boundingBox,
    this.isDetected = true,
  });
}

class YoloWorldService {
  static final YoloWorldService instance = YoloWorldService._internal();
  YoloWorldService._internal();

  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Runs OCR on the image, extracts the most prominent text as product name,
  /// and auto-detects the category using keyword matching.
  Future<YoloWorldDetection> detectProduct(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _textRecognizer.processImage(inputImage);

    // Collect all text blocks with their bounding boxes and area
    final blocks = <_ScoredBlock>[];
    for (final block in recognized.blocks) {
      final box = block.boundingBox;
      final area = box.width * box.height;
      blocks.add(_ScoredBlock(
        text: block.text.trim(),
        rect: box,
        area: area,
      ));
    }

    String productName;
    Rect normalizedBox;
    double confidence;

    if (blocks.isEmpty) {
      // No text found
      productName = '';
      normalizedBox = const Rect.fromLTWH(0.15, 0.15, 0.7, 0.7);
      confidence = 0.0;
    } else {
      // Sort blocks by area descending — largest text is usually the product name
      blocks.sort((a, b) => b.area.compareTo(a.area));

      // Take the top blocks (up to 3) and combine them as the product name
      // Filter out very short single-char noise
      final meaningful = blocks
          .where((b) => b.text.length > 1)
          .take(3)
          .toList();

      if (meaningful.isEmpty) {
        productName = blocks.first.text;
      } else {
        // Use the largest block as primary name
        productName = _buildProductName(meaningful);
      }

      // Get the image dimensions to normalize the bounding box
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = await decodeImageFromList(imageBytes);
      final imgWidth = decodedImage.width.toDouble();
      final imgHeight = decodedImage.height.toDouble();

      // Union all meaningful bounding boxes for the overlay
      Rect union = meaningful.isNotEmpty
          ? meaningful.first.rect
          : blocks.first.rect;
      for (final b in meaningful.skip(1)) {
        union = union.expandToInclude(b.rect);
      }

      // Normalize to 0.0-1.0
      normalizedBox = Rect.fromLTWH(
        (union.left / imgWidth).clamp(0.0, 1.0),
        (union.top / imgHeight).clamp(0.0, 1.0),
        (union.width / imgWidth).clamp(0.0, 1.0),
        (union.height / imgHeight).clamp(0.0, 1.0),
      );

      // Confidence based on how much text we found
      confidence = min(0.95, 0.70 + (meaningful.length * 0.08));
    }

    // Clean up the product name
    productName = _cleanProductName(productName);

    final bool isDetected = productName.isNotEmpty && productName.toLowerCase() != 'unknown product';

    // Detect category from the extracted name
    final detectedCategory =
        CategoryDetectionService.detectCategory(productName) ?? 'Other';

    return YoloWorldDetection(
      productName: isDetected ? productName : '',
      category: detectedCategory,
      confidence: confidence,
      boundingBox: normalizedBox,
      isDetected: isDetected,
    );
  }

  /// Builds a product name from the top scored blocks.
  /// Uses the largest block as primary, and appends smaller ones if they
  /// look like size/variant info (e.g. "500ml", "1L", "Pack of 6").
  String _buildProductName(List<_ScoredBlock> blocks) {
    if (blocks.length == 1) return blocks.first.text;

    final primary = blocks.first.text;
    final secondary = blocks
        .skip(1)
        .map((b) => b.text)
        .where((t) => t.length <= 30) // skip overly long text
        .join(' ');

    if (secondary.isEmpty) return primary;

    // If secondary looks like a continuation, combine
    return '$primary $secondary'.trim();
  }

  /// Clean up OCR artifacts: extra whitespace, line breaks, etc.
  String _cleanProductName(String raw) {
    // Replace newlines with spaces
    var clean = raw.replaceAll(RegExp(r'[\n\r]+'), ' ');
    // Collapse multiple spaces
    clean = clean.replaceAll(RegExp(r'\s{2,}'), ' ');
    // Title case each word
    clean = clean.split(' ').map((word) {
      if (word.isEmpty) return word;
      // Keep all-caps words as-is if short (brand names like "MEMO")
      if (word.length <= 5 && word == word.toUpperCase()) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    // Trim to reasonable length
    if (clean.length > 60) {
      clean = clean.substring(0, 60).trim();
    }
    return clean.trim();
  }

  void dispose() {
    _textRecognizer.close();
  }
}

class _ScoredBlock {
  final String text;
  final Rect rect;
  final double area;

  _ScoredBlock({
    required this.text,
    required this.rect,
    required this.area,
  });
}
