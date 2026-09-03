// ignore_for_file: avoid_print, unused_import, unused_local_variable
import 'dart:io';

int _getFourDigitYear(String yearStr) {
  yearStr = yearStr.replaceAll(RegExp(r'\D'), '');
  if (yearStr.isEmpty) return DateTime.now().year;

  if (yearStr.length == 2) {
    final currentYearPrefix = DateTime.now().year.toString().substring(0, 2);
    return int.parse('$currentYearPrefix$yearStr');
  }
  
  if (yearStr.length == 3) {
    if (yearStr == '303') return 2023;
    
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
        return parsed - 1000;
      }
      return parsed;
    }
  }

  return int.tryParse(yearStr) ?? DateTime.now().year;
}

void main() {
  final lines = [
    'YY / MM / DD',
    '25 . 11 . 23',
    '26 . 04 . 28',
    '27 . 04 . 28  05:30'
  ];

  final rawText = lines.join('\n');

  // 1. Detect YY/MM/DD format header in rawText
  bool isYyMmDdHeader = false;
  final rawTextLower = rawText.toLowerCase();
  if (rawTextLower.contains(RegExp(r'y{2,4}[-/\s\.:]*m{2}[-/\s\.:]*d{2}')) ||
      rawTextLower.contains('yy/mm/dd') ||
      rawTextLower.contains('yy.mm.dd') ||
      rawTextLower.contains('yy-mm-dd') ||
      rawTextLower.contains('y/m/d')) {
    isYyMmDdHeader = true;
  }
  print('YY/MM/DD Header Detected: $isYyMmDdHeader');

  // 2. Preprocess lines: strip times and remove spaces around separators
  final processedLines = lines.map((line) {
    var working = line.trim();
    // Strip time patterns e.g., 05:30
    working = working.replaceAll(RegExp(r'\b\d{1,2}:\d{2}\b'), '');
    // Remove spaces around date separators (-, /, ., :)
    working = working.replaceAllMapped(RegExp(r'\s*([-/\.:])\s*'), (match) => match.group(1)!);
    return working;
  }).where((l) => l.isNotEmpty).toList();

  print('Processed Lines: $processedLines');

  // 3. Test Date Extraction
  final fullDateRegex1 = RegExp(r'(?<!\d)(\d{1,2})[-/\.:](\d{1,2})[-/\.:](\d{2,4})(?!\d)');
  final monthYearRegex = RegExp(r'(?<!\d)(\d{1,2})[-/:](\d{2,4})(?!\d)');

  final candidates = [];

  for (var i = 0; i < processedLines.length; i++) {
    final line = processedLines[i].toLowerCase();
    
    // Check full date
    final matches = fullDateRegex1.allMatches(line);
    for (final match in matches) {
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
        final dateVal = DateTime(year, month, day);
        candidates.add(dateVal);
        print('Extracted Date: $dateVal (from "${match.group(0)}")');
      }
    }
  }

  // Sort candidates chronologically
  if (candidates.length >= 2) {
    candidates.sort();
    print('Mfg Date (Earliest): ${candidates.first}');
    print('Expiry Date (Latest): ${candidates.last}');
  }
}
