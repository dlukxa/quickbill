import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'remote_config_service.dart';

class BatchOcrResult {
  final String? batchNumber;
  final DateTime? expiryDate;
  final DateTime? mfgDate;
  final double? mrp;
  final String rawText;

  BatchOcrResult({
    this.batchNumber,
    this.expiryDate,
    this.mfgDate,
    this.mrp,
    required this.rawText,
  });

  @override
  String toString() {
    return 'BatchOcrResult(batchNumber: $batchNumber, expiryDate: $expiryDate, mfgDate: $mfgDate, mrp: $mrp)';
  }
}

class CandidateDate {
  final DateTime date;
  final String rawMatch;
  final int lineIndex;
  final bool hasDay;

  CandidateDate({
    required this.date,
    required this.rawMatch,
    required this.lineIndex,
    required this.hasDay,
  });
}

class _ParsedDates {
  final DateTime? mfgDate;
  final DateTime? expiryDate;
  _ParsedDates(this.mfgDate, this.expiryDate);
}

class BatchOcrService {
  static final TextRecognizer _textRecognizer = TextRecognizer();

  /// Resize image to max 800px and compress to JPG with contrast boost for cloud upload.
  /// Runs inside compute/isolate to prevent blocking the UI thread.
  static Uint8List? _resizeAndCompressImageForCloud(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // 1. Boost contrast and brightness for OCR text clarity
      var processed = img.adjustColor(
        image,
        contrast: 1.5,
        brightness: 1.1,
      );

      // 2. Resize to max 640px to reduce upload size significantly
      img.Image resized = processed;
      if (processed.width > 640 || processed.height > 640) {
        resized = img.copyResize(
          processed,
          width: processed.width > processed.height ? 640 : null,
          height: processed.height >= processed.width ? 640 : null,
        );
      }
      
      // 3. Compress with quality 70 for highly optimized size
      return Uint8List.fromList(img.encodeJpg(resized, quality: 70));
    } catch (e) {
      debugPrint("Error resizing/compressing image: $e");
      return null;
    }
  }

  /// Premium cloud scan using Gemma 4 multimodal model on Google AI Studio via Remote Config
  static Future<BatchOcrResult> scanWithGemmaCloud(File imageFile) async {
    try {
      final apiKey = RemoteConfigService.instance.geminiApiKey;
      if (apiKey.isEmpty) {
        debugPrint('⚠️ Remote Config gemini_api_key is empty. Falling back to on-device OCR.');
        return scanPackagingLabel(imageFile);
      }

      final bytes = await imageFile.readAsBytes();
      final compressedBytes = await compute(_resizeAndCompressImageForCloud, bytes) ?? bytes;
      
      final base64Image = base64Encode(compressedBytes);
      final dio = Dio();
      
      const prompt = 'Extract from label image to JSON:\n'
          '{\n'
          '  "batchNumber": "string or null",\n'
          '  "expiryDate": "YYYY-MM-DD or null",\n'
          '  "mfgDate": "YYYY-MM-DD or null",\n'
          '  "mrp": number or null\n'
          '}\n'
          'Output JSON only. Do not explain. Reason under 3 words.';

      final response = await dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemma-4-26b-a4b-it:generateContent?key=$apiKey',
        data: {
          'systemInstruction': {
            'parts': [
              {
                'text': 'Extract label OCR to JSON. Output ONLY raw JSON. Thinking must be under 3 words.'
              }
            ]
          },
          'contents': [
            {
              'parts': [
                {
                  'text': prompt
                },
                {
                  'inlineData': {
                    'mimeType': 'image/jpeg',
                    'data': base64Image
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.0,
            'maxOutputTokens': 150
          }
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final data = response.data;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('No candidates returned from Gemma Cloud API.');
      }
      
      final parts = candidates.first['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw Exception('No content parts returned from Gemma Cloud API.');
      }

      String? text;
      for (final p in parts) {
        final isThought = p['thought'] == true;
        if (!isThought) {
          final pText = p['text'] as String?;
          if (pText != null && pText.trim().isNotEmpty) {
            text = pText;
            break;
          }
        }
      }

      if (text == null) {
        for (final p in parts) {
          final pText = p['text'] as String?;
          if (pText != null && pText.trim().isNotEmpty) {
            text = pText;
            break;
          }
        }
      }

      if (text == null || text.trim().isEmpty) {
        throw Exception('Empty content returned from Gemma Cloud API.');
      }

      var jsonText = text.trim();
      if (jsonText.startsWith('```')) {
        final match = RegExp(r'```(?:json)?([\s\S]*?)```').firstMatch(jsonText);
        if (match != null) {
          jsonText = match.group(1)!.trim();
        }
      }

      final parsedJson = jsonDecode(jsonText) as Map<String, dynamic>;
      
      final batchNumber = parsedJson['batchNumber']?.toString();
      final mfgDateStr = parsedJson['mfgDate']?.toString();
      final expiryDateStr = parsedJson['expiryDate']?.toString();
      final mrpValue = parsedJson['mrp'];
      
      double? mrp;
      if (mrpValue is num) {
        mrp = mrpValue.toDouble();
      } else if (mrpValue is String) {
        mrp = double.tryParse(mrpValue.replaceAll(RegExp(r'[^\d.]'), ''));
      }
      
      DateTime? mfgDate;
      if (mfgDateStr != null && mfgDateStr.isNotEmpty) {
        mfgDate = DateTime.tryParse(mfgDateStr);
      }
      
      DateTime? expiryDate;
      if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
        expiryDate = DateTime.tryParse(expiryDateStr);
      }

      return BatchOcrResult(
        batchNumber: batchNumber,
        expiryDate: expiryDate,
        mfgDate: mfgDate,
        mrp: mrp,
        rawText: text,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final errorMsg = e.response?.data?['error']?['message']?.toString() ?? '';
      
      if (status == 429 || errorMsg.contains('prepayment credits') || errorMsg.contains('RESOURCE_EXHAUSTED')) {
        throw Exception('QUOTA_EXHAUSTED: Prepayment credits on your Google AI Studio project are depleted. Please check billing on AI Studio.');
      }
      throw Exception('Gemma Cloud API failed: ${errorMsg.isNotEmpty ? errorMsg : e.message}');
    } catch (e) {
      throw Exception('Failed to run Gemma Cloud OCR: $e');
    }
  }

  /// Process packaging label image to extract MFD, EXP, Batch No, and MRP
  static Future<BatchOcrResult> scanPackagingLabel(File imageFile) async {
    File processingFile = imageFile;
    
    try {
      debugPrint("📸 Optimizing captured image for OCR...");
      final bytes = await imageFile.readAsBytes();
      final optimizedBytes = await compute(_optimizeImageForOcrIsolate, bytes);
      
      if (optimizedBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/optimized_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(optimizedBytes);
        processingFile = tempFile;
        debugPrint("📸 Image optimization complete. Running OCR on optimized file: ${tempFile.path}");
      }
    } catch (e) {
      debugPrint("⚠️ Failed to optimize image for OCR, falling back to raw image: $e");
    }

    final inputImage = InputImage.fromFile(processingFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final rawText = recognizedText.text;

    // Clean up temporary optimized file if we created one
    if (processingFile.path != imageFile.path) {
      try {
        await processingFile.delete();
      } catch (_) {}
    }

    String? batchNumber;
    DateTime? expiryDate;
    DateTime? mfgDate;
    double? mrp;

    // Split text into lines for line-by-line regex parsing
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    debugPrint("--- OCR Raw Lines ---");
    for (var line in lines) {
      debugPrint("OCR Line: '$line'");
    }

    // 1. Parse Batch Number (B/No, B.No, Batch, Lot)
    batchNumber = extractBatchNumber(lines);

    // 2. Parse Dates (MFD & EXP)
    final parsedDates = _extractDates(lines);
    mfgDate = parsedDates.mfgDate;
    expiryDate = parsedDates.expiryDate;

    // 3. Parse MRP / Price
    mrp = extractMRP(lines);

    return BatchOcrResult(
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      mfgDate: mfgDate,
      mrp: mrp,
      rawText: rawText,
    );
  }

  /// Clean batch number text extraction
  static String? extractBatchNumber(List<String> lines) {
    // Look for lines containing batch triggers (BN0, B.N0, B/N0 support)
    final batchRegex = RegExp(
      r'(?:b\.?no\.?|b\.?n0\.?|b/no|b/n0|batch|lot|bno|bn0)[:.,\s-]*([a-z0-9/-]{3,20})',
      caseSensitive: false,
    );

    for (var line in lines) {
      final match = batchRegex.firstMatch(line);
      if (match != null) {
        final val = match.group(1)?.trim();
        if (val != null && val.isNotEmpty) {
          // Clean common OCR noise from batch numbers
          return val.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9/-]'), '');
        }
      }
    }

    // Fallback: If we find a standalone sequence that looks like a batch number in lines containing other text
    final standaloneBatchRegex = RegExp(r'\b[A-Z0-9]{4,12}\b');
    for (var line in lines) {
      if (line.toLowerCase().contains('batch') || 
          line.toLowerCase().contains('b.n') || 
          line.toLowerCase().contains('lot') ||
          line.toLowerCase().contains('bno') ||
          line.toLowerCase().contains('bn0')) {
        final match = standaloneBatchRegex.firstMatch(line);
        if (match != null) {
          return match.group(0);
        }
      }
    }

    return null;
  }

  /// Extract date (MFD or EXP) from lines
  static DateTime? extractDate(List<String> lines, {required bool isExpiry}) {
    final parsed = _extractDates(lines);
    return isExpiry ? parsed.expiryDate : parsed.mfgDate;
  }

  /// Internal date parser running all regex logic
  static _ParsedDates _extractDates(List<String> lines) {
    final mfdTriggers = ['mfd', 'mfg', 'manufactur', 'm.f.d.', 'mfg.d.', 'pkd', 'packed', 'pkg', 'prd', 'prod', 'production', 'pnd', 'mf0', 'mfo', 'pk0', 'pko', 'repacked', 'rpkd', 'repk', 'mkd'];
    final expTriggers = ['exp', 'expiry', 'best before', 'use by', 'bb', 'e.d.', 'exp.d', 'val', 'valid', 'exp.date', 'expiry.date', 'ex0', 'exo', 'exb'];

    // Regex for date patterns (using lookarounds instead of word boundaries to allow no-space labels):
    // Pattern 1: DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY or DD/MM/YY or DD:MM:YYYY
    final fullDateRegex1 = RegExp(r'(?<!\d)(\d{1,2})[-/\.:](\d{1,2})[-/\.:](\d{2,4})(?!\d)');
    // Pattern 2: YYYY/MM/DD or YYYY-MM-DD
    final fullDateRegex2 = RegExp(r'(?<!\d)(\d{4})[-/\.:](\d{1,2})[-/\.:](\d{1,2})(?!\d)');
    // Pattern 3: MM/YYYY or MM-YYYY or MM/YY or MM-YY or MM:YY (no dot to prevent price decimal collisions)
    final monthYearRegex = RegExp(r'(?<!\d)(\d{1,2})[-/:](\d{2,4})(?!\d)');
    // Pattern 4: MM.YYYY (only matches dots if the year is 4 digits to prevent price collisions)
    final monthYearDotRegex = RegExp(r'(?<!\d)(\d{1,2})\.(\d{4})(?!\d)');
    // Pattern 5: Verbal Month Year e.g. JAN 26, JAN 2026, JAN-26
    final verbalDateRegex = RegExp(
      r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[-/\.\s]*(\d{2,4})\b',
      caseSensitive: false,
    );
    // Pattern 6: DD Verbal Month Year e.g. 15 JAN 26, 15-JAN-2026
    final verbalFullDateRegex = RegExp(
      r'\b(\d{1,2})[-/\.\s]+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[-/\.\s]+(\d{2,4})\b',
      caseSensitive: false,
    );

    // Detect YY/MM/DD format header in raw text
    final rawText = lines.join('\n').toLowerCase();
    bool isYyMmDdHeader = false;
    if (rawText.contains(RegExp(r'y{2,4}[-/\s\.:]*m{2}[-/\s\.:]*d{2}')) ||
        rawText.contains('yy/mm/dd') ||
        rawText.contains('yy.mm.dd') ||
        rawText.contains('yy-mm-dd') ||
        rawText.contains('y/m/d')) {
      isYyMmDdHeader = true;
      debugPrint("📅 Detected YY/MM/DD format header in OCR text!");
    }

    // Preprocess lines: strip time patterns and remove spaces around separators
    final processedLines = lines.map((line) {
      var working = _normalizeNumbers(line.toLowerCase()).trim();
      // Strip time patterns like 05:30 or 14:45
      working = working.replaceAll(RegExp(r'\b\d{1,2}:\d{2}\b'), '');
      // Remove spaces around date separators (-, /, ., :)
      working = working.replaceAllMapped(RegExp(r'\s*([-/\.:])\s*'), (match) => match.group(1)!);
      return working;
    }).toList();

    List<CandidateDate> candidates = [];

    for (int i = 0; i < processedLines.length; i++) {
      String workingLine = processedLines[i];

      // 1. Try verbal full date (e.g. 15 Jan 2026)
      final verbalFullMatches = verbalFullDateRegex.allMatches(workingLine);
      for (final match in verbalFullMatches) {
        final day = int.tryParse(match.group(1) ?? '') ?? 1;
        final monthStr = match.group(2)?.toLowerCase();
        final yearStr = match.group(3) ?? '';
        if (monthStr != null) {
          final month = _getMonthIndex(monthStr);
          final year = _getFourDigitYear(yearStr);
          candidates.add(CandidateDate(
            date: DateTime(year, month, day),
            rawMatch: match.group(0)!,
            lineIndex: i,
            hasDay: true,
          ));
        }
      }
      workingLine = workingLine.replaceAll(verbalFullDateRegex, '[DATE]');

      // 2. Try YYYY-MM-DD
      final fullMatches2 = fullDateRegex2.allMatches(workingLine);
      for (final match in fullMatches2) {
        final year = int.tryParse(match.group(1) ?? '') ?? DateTime.now().year;
        final month = int.tryParse(match.group(2) ?? '') ?? 1;
        final day = int.tryParse(match.group(3) ?? '') ?? 1;
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          candidates.add(CandidateDate(
            date: DateTime(year, month, day),
            rawMatch: match.group(0)!,
            lineIndex: i,
            hasDay: true,
          ));
        }
      }
      workingLine = workingLine.replaceAll(fullDateRegex2, '[DATE]');

      // 3. Try DD-MM-YYYY or DD-MM-YY (now also handles YY-MM-DD if isYyMmDdHeader is true)
      final fullMatches1 = fullDateRegex1.allMatches(workingLine);
      for (final match in fullMatches1) {
        final p1 = int.tryParse(match.group(1) ?? '') ?? 1;
        final p2 = int.tryParse(match.group(2) ?? '') ?? 1;
        final yearStr = match.group(3) ?? '';
        
        int year;
        int month = p2;
        int day;

        if (isYyMmDdHeader) {
          year = _getFourDigitYear(match.group(1) ?? '');
          day = int.tryParse(yearStr) ?? 1;
        } else {
          year = _getFourDigitYear(yearStr);
          day = p1;
          if (month > 12 && day <= 12) {
            day = p2;
            month = p1;
          }
        }

        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          candidates.add(CandidateDate(
            date: DateTime(year, month, day),
            rawMatch: match.group(0)!,
            lineIndex: i,
            hasDay: true,
          ));
        }
      }
      workingLine = workingLine.replaceAll(fullDateRegex1, '[DATE]');

      // 4. Try verbal month-year (e.g. JAN 2026 or JAN-26)
      final verbalMatches = verbalDateRegex.allMatches(workingLine);
      for (final match in verbalMatches) {
        final monthStr = match.group(1)?.toLowerCase();
        final yearStr = match.group(2) ?? '';
        if (monthStr != null) {
          final month = _getMonthIndex(monthStr);
          final year = _getFourDigitYear(yearStr);
          candidates.add(CandidateDate(
            date: DateTime(year, month, 1),
            rawMatch: match.group(0)!,
            lineIndex: i,
            hasDay: false,
          ));
        }
      }
      workingLine = workingLine.replaceAll(verbalDateRegex, '[DATE]');

      // 5. Try month-year numeric (e.g. 05/26 or 26/05 if YY/MM/DD header is present)
      final myMatches = monthYearRegex.allMatches(workingLine);
      for (final match in myMatches) {
        final p1 = int.tryParse(match.group(1) ?? '') ?? 1;
        final p2 = int.tryParse(match.group(2) ?? '') ?? 1;
        
        int year;
        int month;
        
        if (isYyMmDdHeader) {
          year = _getFourDigitYear(match.group(1) ?? '');
          month = p2;
        } else {
          year = _getFourDigitYear(match.group(2) ?? '');
          month = p1;
        }
        
        if (month >= 1 && month <= 12) {
          candidates.add(CandidateDate(
            date: DateTime(year, month, 1),
            rawMatch: match.group(0)!,
            lineIndex: i,
            hasDay: false,
          ));
        }
      }
      workingLine = workingLine.replaceAll(monthYearRegex, '[DATE]');

      // 6. Try month-year numeric dot (e.g. 05.2026)
      final myDotMatches = monthYearDotRegex.allMatches(workingLine);
      for (final match in myDotMatches) {
        final month = int.tryParse(match.group(1) ?? '') ?? 1;
        final yearStr = match.group(2) ?? '';
        final year = _getFourDigitYear(yearStr);
        if (month >= 1 && month <= 12) {
          candidates.add(CandidateDate(
            date: DateTime(year, month, 1),
            rawMatch: match.group(0)!,
            lineIndex: i,
            hasDay: false,
          ));
        }
      }
    }

    // Classify candidates based on nearby trigger words
    List<CandidateDate> mfdCandidates = [];
    List<CandidateDate> expCandidates = [];
    List<CandidateDate> unclassifiedCandidates = [];

    for (var candidate in candidates) {
      final lineIdx = candidate.lineIndex;
      final searchLines = <String>[];
      if (lineIdx - 1 >= 0) searchLines.add(lines[lineIdx - 1].toLowerCase());
      searchLines.add(lines[lineIdx].toLowerCase());
      if (lineIdx + 1 < lines.length) searchLines.add(lines[lineIdx + 1].toLowerCase());

      bool isExp = false;
      bool isMfd = false;

      for (var searchLine in searchLines) {
        for (var trigger in expTriggers) {
          if (searchLine.contains(trigger)) {
            isExp = true;
            break;
          }
        }
        if (RegExp(r'\be[:.\s]').hasMatch(searchLine) || searchLine.startsWith('e:')) {
          isExp = true;
        }

        for (var trigger in mfdTriggers) {
          if (searchLine.contains(trigger)) {
            isMfd = true;
            break;
          }
        }
        if (RegExp(r'\bm[:.\s]').hasMatch(searchLine) || searchLine.startsWith('m:')) {
          isMfd = true;
        }
      }

      if (isExp && !isMfd) {
        expCandidates.add(candidate);
      } else if (isMfd && !isExp) {
        mfdCandidates.add(candidate);
      } else {
        unclassifiedCandidates.add(candidate);
      }
    }

    DateTime? mfgDate;
    DateTime? expiryDate;

    if (mfdCandidates.isNotEmpty) {
      mfgDate = mfdCandidates.first.date;
    }
    if (expCandidates.isNotEmpty) {
      final cand = expCandidates.first;
      if (cand.hasDay) {
        expiryDate = cand.date;
      } else {
        expiryDate = DateTime(cand.date.year, cand.date.month, _getLastDayOfMonth(cand.date.year, cand.date.month));
      }
    }

    // Heuristics mapping for unclassified dates
    if (mfgDate == null || expiryDate == null) {
      unclassifiedCandidates.sort((a, b) => a.date.compareTo(b.date));

      if (mfgDate == null && expiryDate == null) {
        if (unclassifiedCandidates.length >= 2) {
          final firstCand = unclassifiedCandidates.first;
          final lastCand = unclassifiedCandidates.last;
          mfgDate = firstCand.date;
          if (lastCand.hasDay) {
            expiryDate = lastCand.date;
          } else {
            expiryDate = DateTime(lastCand.date.year, lastCand.date.month, _getLastDayOfMonth(lastCand.date.year, lastCand.date.month));
          }
        } else if (unclassifiedCandidates.length == 1) {
          final cand = unclassifiedCandidates.first;
          final now = DateTime.now();
          if (cand.date.isAfter(now.add(const Duration(days: 15)))) {
            if (cand.hasDay) {
              expiryDate = cand.date;
            } else {
              expiryDate = DateTime(cand.date.year, cand.date.month, _getLastDayOfMonth(cand.date.year, cand.date.month));
            }
          } else {
            mfgDate = cand.date;
          }
        }
      } else if (mfgDate == null) {
        if (unclassifiedCandidates.isNotEmpty) {
          final candidate = unclassifiedCandidates.firstWhere(
            (c) => c.date.isBefore(expiryDate!),
            orElse: () => unclassifiedCandidates.first,
          );
          mfgDate = candidate.date;
        }
      } else if (expiryDate == null) {
        if (unclassifiedCandidates.isNotEmpty) {
          final candidate = unclassifiedCandidates.lastWhere(
            (c) => c.date.isAfter(mfgDate!),
            orElse: () => unclassifiedCandidates.last,
          );
          if (candidate.hasDay) {
            expiryDate = candidate.date;
          } else {
            expiryDate = DateTime(candidate.date.year, candidate.date.month, _getLastDayOfMonth(candidate.date.year, candidate.date.month));
          }
        }
      }
    }

    return _ParsedDates(mfgDate, expiryDate);
  }

  /// Extract MRP (Maximum Retail Price) / Price from lines (with Sri Lankan support)
  static double? extractMRP(List<String> lines) {
    // 1. Regular expression targeting Rupees / LKR / Rs. / Sinhala and Tamil symbols
    final priceRegex = RegExp(
      r'(?:m\.?r\.?p\.?|rs\.?|lkr|sl\s*rs\.?|slrs|රු\.?|ரூ\.?|price)[:.\s-]*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    for (var line in lines) {
      final normalizedLine = _normalizeNumbers(line);
      final match = priceRegex.firstMatch(normalizedLine);
      if (match != null) {
        final val = match.group(1)?.replaceAll(',', '');
        if (val != null) {
          final price = double.tryParse(val);
          if (price != null && price > 0) {
            return price;
          }
        }
      }
    }

    // 2. Fallback targeting just numbers followed by common retail price suffixes like /= or /-
    final lkSuffixRegex = RegExp(r'(?<!\d)([0-9,]+(?:\.[0-9]{1,2})?)(?:/=|-/|/-)(?!\w)');
    for (var line in lines) {
      final normalizedLine = _normalizeNumbers(line);
      final match = lkSuffixRegex.firstMatch(normalizedLine);
      if (match != null) {
        final val = match.group(1)?.replaceAll(',', '');
        if (val != null) {
          final price = double.tryParse(val);
          if (price != null && price > 0) {
            return price;
          }
        }
      }
    }

    // 3. Last resort fallback scanning lines containing trigger tags and pulling out the first float value
    for (var line in lines) {
      final normalizedLine = _normalizeNumbers(line);
      final lineLower = normalizedLine.toLowerCase();
      if (lineLower.contains('mrp') || 
          lineLower.contains('rs') || 
          lineLower.contains('lkr') || 
          lineLower.contains('price') ||
          lineLower.contains('රු') ||
          lineLower.contains('ரூ')) {
        final priceMatch = RegExp(r'[0-9,]+(?:\.[0-9]{1,2})?').firstMatch(normalizedLine);
        if (priceMatch != null) {
          final val = priceMatch.group(0)!.replaceAll(',', '');
          final price = double.tryParse(val);
          if (price != null && price > 0) {
            return price;
          }
        }
      }
    }

    return null;
  }

  /// Helper to convert 2-digit/3-digit/4-digit years to 4-digit years with OCR noise recovery
  static int _getFourDigitYear(String yearStr) {
    yearStr = yearStr.replaceAll(RegExp(r'\D'), '');
    if (yearStr.isEmpty) return DateTime.now().year;

    if (yearStr.length == 2) {
      final currentYearPrefix = DateTime.now().year.toString().substring(0, 2);
      return int.parse('$currentYearPrefix$yearStr');
    }
    
    if (yearStr.length == 3) {
      if (yearStr == '303') return 2023; // Common for 2023
      
      final lastTwo = int.tryParse(yearStr.substring(1));
      if (lastTwo != null && lastTwo >= 20 && lastTwo <= 35) {
        return 2000 + lastTwo;
      }
      final firstLast = int.tryParse('${yearStr[0]}${yearStr[2]}');
      if (firstLast != null && firstLast >= 20 && firstLast <= 35) {
        return 2000 + firstLast;
      }
      if (lastTwo != null) {
        if (lastTwo < 20) {
          return 2000 + lastTwo + 10;
        }
        return 2000 + lastTwo;
      }
    }

    if (yearStr.length == 4) {
      final parsed = int.tryParse(yearStr);
      if (parsed != null) {
        if (parsed >= 3020 && parsed <= 3035) {
          return parsed - 1000; // Map 3023 -> 2023
        }
        return parsed;
      }
    }

    return int.tryParse(yearStr) ?? DateTime.now().year;
  }

  /// Helper to map month abbreviation to month index (1-12)
  static int _getMonthIndex(String monthStr) {
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final idx = months.indexWhere((m) => monthStr.startsWith(m));
    return idx != -1 ? idx + 1 : 1;
  }

  /// Helper to get the last day of a month
  static int _getLastDayOfMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// Normalize number-like strings that suffer from common OCR swapping (O/o -> 0, I/i/l -> 1)
  static String _normalizeNumbers(String text) {
    final tokens = text.split(RegExp(r'\s+'));
    final cleanedTokens = tokens.map((token) {
      if (token.contains('/') || token.contains('-') || token.contains('.') || token.contains(RegExp(r'\d'))) {
        return token
            .replaceAll(RegExp(r'[oO]'), '0')
            .replaceAll(RegExp(r'[iIl]'), '1');
      }
      return token;
    });
    return cleanedTokens.join(' ');
  }

  /// Optimize image for OCR by decoding, increasing contrast, sharpening, and encoding back to JPEG.
  /// Runs inside compute/isolate to prevent blocking the UI thread.
  static Uint8List? _optimizeImageForOcrIsolate(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // 1. Increase contrast to make text stand out against background
      var processed = img.adjustColor(
        image,
        contrast: 1.6, // Boost contrast significantly
        brightness: 1.1, // Slightly brighten to keep background clean
      );

      // 2. Apply standard 3x3 sharpening convolution kernel
      final List<num> sharpenKernel = [
         0, -1,  0,
        -1,  5, -1,
         0, -1,  0,
      ];
      processed = img.convolution(
        processed,
        filter: sharpenKernel,
        div: 1.0,
        offset: 0.0,
      );

      // 3. Encode back to JPG with high quality (85)
      return Uint8List.fromList(img.encodeJpg(processed, quality: 85));
    } catch (e) {
      debugPrint("Error in image optimization isolate: $e");
      return null;
    }
  }
}
