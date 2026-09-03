import 'dart:math';
import '../models/product.dart';

class ParsedSearchQuery {
  final String originalQuery;
  final String productQuery;
  final double? quantity;
  final String? unit;
  final bool hasQuantitySpec;

  const ParsedSearchQuery({
    required this.originalQuery,
    required this.productQuery,
    this.quantity,
    this.unit,
    this.hasQuantitySpec = false,
  });

  /// Inferred selling mode from the unit specified in the query.
  String? get sellingMode {
    if (unit == null) return null;
    final u = unit!.toLowerCase();
    if (u == 'pack' || u == 'packs' || u == 'packet' || u == 'packets' || u == 'box' || u == 'boxes' || u == 'bottle' || u == 'bottles' || u == 'can' || u == 'cans') {
      return 'pack';
    }
    if (u == 'kg' || u == 'g' || u == 'gram' || u == 'grams') {
      return 'weight';
    }
    if (u == 'l' || u == 'ltr' || u == 'liter' || u == 'liters' || u == 'litre' || u == 'litres' || u == 'ml') {
      return 'liquid';
    }
    if (u == 'pcs' || u == 'pc' || u == 'piece' || u == 'pieces' || u == 'dozen' || u == 'doz') {
      return 'piece';
    }
    return null;
  }
}

/// Sinhala and Singlish Smart Search Service
/// Specially optimized for Sri Lankan POS environments.
class SinhalaSearchService {
  SinhalaSearchService._();
  static final SinhalaSearchService instance = SinhalaSearchService._();

  // --------------------------------------------------------------------------
  // SINHALA & SINGLISH TRANSLITERATION TABLES
  // --------------------------------------------------------------------------

  // Common Sri Lankan POS / Grocery word dictionary for instant exact mapping
  static const Map<String, String> _commonSinglishToSinhala = {
    'kiri': 'කිරි',
    'the': 'තේ',
    'thee': 'තේ',
    'tea': 'තේ',
    'bath': 'බත්',
    'baath': 'බත්',
    'kiribath': 'කිරිබත්',
    'kiri bath': 'කිරිබත්',
    'seeni': 'සීනි',
    'sini': 'සීනි',
    'sugar': 'සීනි',
    'paan': 'පාන්',
    'pan': 'පාන්',
    'bread': 'පාන්',
    'piti': 'පිටි',
    'flour': 'පිටි',
    'pol': 'පොල්',
    'coconut': 'පොල්',
    'thel': 'තෙල්',
    'oil': 'තෙල්',
    'kopi': 'කෝපි',
    'coffee': 'කෝපි',
    'kottu': 'කොත්තු',
    'kotthu': 'කොත්තු',
    'roti': 'රොටි',
    'parippu': 'පරිප්පු',
    'dhal': 'පරිප්පු',
    'dahl': 'පරිප්පු',
    'haal': 'හාල්',
    'hal': 'හාල්',
    'rice': 'සහල්',
    'samba': 'සම්බා',
    'kekulu': 'කැකුළු',
    'kakulu': 'කැකුළු',
    'keeri': 'කීරි',
    'elawalu': 'එළවළු',
    'elavalu': 'එළවළු',
    'vegetables': 'එළවළු',
    'malu': 'මාළු',
    'maalu': 'මාළු',
    'fish': 'මාළු',
    'mas': 'මස්',
    'meat': 'මස්',
    'kukul': 'කුකුල්',
    'chicken': 'කුකුල් මස්',
    'biththara': 'බිත්තර',
    'bittara': 'බිත්තර',
    'egg': 'බිත්තර',
    'eggs': 'බිත්තර',
    'biscuit': 'බිස්කට්',
    'biscuits': 'බිස්කට්',
    'wathura': 'වතුර',
    'water': 'වතුර',
    'sos': 'සෝස්',
    'sauce': 'සෝස්',
    'kek': 'කේක්',
    'cake': 'කේක්',
    'sudu': 'සුදු',
    'white': 'සුදු',
    'rathu': 'රතු',
    'red': 'රතු',
    'lunu': 'ලූණු',
    'onion': 'ලූණු',
    'thakkali': 'තක්කාලි',
    'tomato': 'තක්කාලි',
    'aluwa': 'අලුව',
    'dodol': 'දොදොල්',
    'ala': 'අල',
    'potato': 'අල',
    'miris': 'මිරිස්',
    'chilli': 'මිරිස්',
    'kaha': 'කහ',
    'turmeric': 'කහ',
    'sudulunu': 'සුදුලූණු',
    'garlic': 'සුදුලූණු',
    'inguru': 'ඉඟුරු',
    'ginger': 'ඉඟුරු',
    'karapincha': 'කරපිංචා',
    'goraka': 'ගොරකා',
    'asamodagam': 'අසමෝදගම්',
    'siddhalepa': 'සිද්ධාලේප',
    'samahan': 'සමහන්',
    'pas': 'පස්',
    'panguwa': 'පංගුව',
    'sup': 'සුප්',
    'soup': 'සුප්',
    'noodles': 'නූඩ්ල්ස්',
    'noodls': 'නූඩ්ල්ස්',
  };

  // Reverse mapping for common Sinhala words to primary Singlish
  static final Map<String, String> _commonSinhalaToSinglish = {
    for (var entry in _commonSinglishToSinhala.entries) entry.value: entry.key,
  };

  // Independent Vowels
  static const Map<String, String> _independentVowels = {
    'aa': 'ආ',
    'a': 'අ',
    'aae': 'ඈ',
    'ae': 'ඇ',
    'ii': 'ඊ',
    'ee': 'ඊ',
    'i': 'ඉ',
    'uu': 'ඌ',
    'oo': 'ඌ',
    'u': 'උ',
    'ea': 'ඒ',
    'ei': 'ඒ',
    'ey': 'ඒ',
    'e': 'එ',
    'ai': 'ඓ',
    'oe': 'ඕ',
    'o': 'ඔ',
    'au': 'ඖ',
    'ou': 'ඖ',
  };

  // Dependent Vowel Signs (Pili)
  static const Map<String, String> _vowelStrokes = {
    'aae': 'ෑ',
    'ae': 'ැ',
    'aa': 'ා',
    'ii': 'ී',
    'ee': 'ී',
    'i': 'ි',
    'uu': 'ූ',
    'oo': 'ූ',
    'u': 'ු',
    'ea': 'ේ',
    'ei': 'ේ',
    'ey': 'ේ',
    'e': 'ෙ',
    'ai': 'ෛ',
    'oe': 'ෝ',
    'o': 'ො',
    'au': 'ෞ',
    'ou': 'ෞ',
  };

  // Consonants ordered from longest token to shortest
  static const List<MapEntry<String, String>> _consonantsList = [
    MapEntry('nndh', 'ඳ'),
    MapEntry('nnd', 'ඬ'),
    MapEntry('nng', 'ඟ'),
    MapEntry('mmb', 'ඹ'),
    MapEntry('chh', 'ඡ'),
    MapEntry('kh', 'ඛ'),
    MapEntry('gh', 'ඝ'),
    MapEntry('ng', 'ඞ'),
    MapEntry('ch', 'ච'),
    MapEntry('jh', 'ඣ'),
    MapEntry('gn', 'ඤ'),
    MapEntry('ny', 'ඤ'),
    MapEntry('th', 'ත'),
    MapEntry('dh', 'ද'),
    MapEntry('ph', 'ප'),
    MapEntry('bh', 'භ'),
    MapEntry('sh', 'ශ'),
    MapEntry('kn', 'ක්න'),
    MapEntry('k', 'ක'),
    MapEntry('g', 'ග'),
    MapEntry('c', 'ච'),
    MapEntry('j', 'ජ'),
    MapEntry('t', 'ට'),
    MapEntry('d', 'ඩ'),
    MapEntry('n', 'න'),
    MapEntry('p', 'ප'),
    MapEntry('b', 'බ'),
    MapEntry('m', 'ම'),
    MapEntry('y', 'ය'),
    MapEntry('r', 'ර'),
    MapEntry('l', 'ල'),
    MapEntry('v', 'ව'),
    MapEntry('w', 'ව'),
    MapEntry('s', 'ස'),
    MapEntry('h', 'හ'),
    MapEntry('f', 'ෆ'),
  ];

  // --------------------------------------------------------------------------
  // TRANSLITERATION LOGIC
  // --------------------------------------------------------------------------

  /// Converts Singlish (romanized Sinhala) into Sinhala Unicode script.
  /// Example: "kiri the" -> "කිරි තේ", "kiri bath" -> "කිරිබත්"
  static String singlishToSinhala(String input) {
    final clean = input.toLowerCase().trim();
    if (clean.isEmpty) return '';
    if (_commonSinglishToSinhala.containsKey(clean)) {
      return _commonSinglishToSinhala[clean]!;
    }
    final words = clean.split(RegExp(r'\s+'));
    final convertedWords = <String>[];

    for (final word in words) {
      // 1. Check direct dictionary first
      if (_commonSinglishToSinhala.containsKey(word)) {
        convertedWords.add(_commonSinglishToSinhala[word]!);
        continue;
      }

      // 2. Fall back to phonetic parser
      convertedWords.add(_transliterateWord(word));
    }

    return convertedWords.join(' ');
  }

  static String _transliterateWord(String word) {
    if (word.isEmpty) return '';
    final buffer = StringBuffer();
    int i = 0;
    final len = word.length;

    while (i < len) {
      final char = word[i];

      // Non-alphabet characters
      if (char.codeUnitAt(0) < 97 || char.codeUnitAt(0) > 122) {
        buffer.write(char);
        i++;
        continue;
      }

      // Check if starting with a consonant
      MapEntry<String, String>? matchedConsonant;
      for (final entry in _consonantsList) {
        if (word.startsWith(entry.key, i)) {
          matchedConsonant = entry;
          break;
        }
      }

      if (matchedConsonant != null) {
        final cKey = matchedConsonant.key;
        final cSinhala = matchedConsonant.value;
        i += cKey.length;

        // Look for vowel after consonant
        String? matchedVowel;
        // Check 3-char vowels, 2-char vowels, 1-char vowels
        for (final vLen in [3, 2, 1]) {
          if (i + vLen <= len) {
            final candidate = word.substring(i, i + vLen);
            if (_vowelStrokes.containsKey(candidate) || candidate == 'a') {
              matchedVowel = candidate;
              i += vLen;
              break;
            }
          }
        }

        if (matchedVowel != null) {
          if (matchedVowel == 'a') {
            // Inherent vowel, write base consonant
            buffer.write(cSinhala);
          } else if (matchedVowel == 'e' || matchedVowel == 'ea' || matchedVowel == 'ei' || matchedVowel == 'ey') {
            // Kombuva character
            buffer.write('$cSinhala${_vowelStrokes[matchedVowel] ?? ""}');
          } else if (matchedVowel == 'o' || matchedVowel == 'oe') {
            buffer.write('$cSinhala${_vowelStrokes[matchedVowel] ?? "ො"}');
          } else {
            buffer.write('$cSinhala${_vowelStrokes[matchedVowel] ?? ""}');
          }
        } else {
          // No vowel following consonant: apply Al-lakuna (hal-kirima)
          buffer.write('$cSinhala\u0DCA');
        }
      } else {
        // Starts with an independent vowel
        String? matchedIndepVowel;
        for (final vLen in [3, 2, 1]) {
          if (i + vLen <= len) {
            final candidate = word.substring(i, i + vLen);
            if (_independentVowels.containsKey(candidate)) {
              matchedIndepVowel = candidate;
              buffer.write(_independentVowels[candidate]);
              i += vLen;
              break;
            }
          }
        }

        if (matchedIndepVowel == null) {
          buffer.write(char);
          i++;
        }
      }
    }

    return buffer.toString();
  }

  /// Converts Sinhala Unicode to simplified Singlish representations.
  /// Example: "කිරි තේ" -> ["kiri the", "kiri thee", "kirithe"]
  static List<String> sinhalaToSinglish(String sinhalaText) {
    if (sinhalaText.trim().isEmpty) return [];

    final normalized = normalizeSinhala(sinhalaText);
    final results = <String>{};

    // 1. Direct dictionary check
    final words = normalized.split(RegExp(r'\s+'));
    final singlishWords = <String>[];
    for (final w in words) {
      if (_commonSinhalaToSinglish.containsKey(w)) {
        singlishWords.add(_commonSinhalaToSinglish[w]!);
      }
    }
    if (singlishWords.length == words.length && singlishWords.isNotEmpty) {
      final joined = singlishWords.join(' ');
      results.add(joined);
      results.add(joined.replaceAll(' ', ''));
    }

    // 2. Character-by-character phonetic mapping
    final phonetic = _sinhalaToPhoneticLatin(normalized);
    if (phonetic.isNotEmpty) {
      results.add(phonetic);
      results.add(phonetic.replaceAll(' ', ''));
      // Add common spelling variants: aa/a, ee/i, oo/u, th/t
      results.add(phonetic.replaceAll('ee', 'i').replaceAll('oo', 'u').replaceAll('aa', 'a'));
      results.add(phonetic.replaceAll('th', 't'));
    }

    return results.toList();
  }

  static String _sinhalaToPhoneticLatin(String text) {
    final buffer = StringBuffer();
    final chars = text.split('');
    int i = 0;

    const sinhalaToLatinConsonants = {
      'ක': 'k', 'ඛ': 'kh', 'ග': 'g', 'ඝ': 'gh', 'ඞ': 'ng', 'ඟ': 'nng',
      'ච': 'ch', 'ඡ': 'chh', 'ජ': 'j', 'ඣ': 'jh', 'ඤ': 'ny',
      'ට': 't', 'ඨ': 'th', 'ඩ': 'd', 'ඪ': 'dh', 'ණ': 'n', 'ඬ': 'nnd',
      'ත': 'th', 'ථ': 'th', 'ද': 'd', 'ධ': 'dh', 'න': 'n', 'ඳ': 'nndh',
      'ප': 'p', 'ඵ': 'ph', 'බ': 'b', 'භ': 'bh', 'ම': 'm', 'ඹ': 'mmb',
      'ය': 'y', 'ර': 'r', 'ල': 'l', 'ව': 'w', 'ශ': 'sh', 'ෂ': 'sh', 'ස': 's', 'හ': 'h', 'ළ': 'l', 'ෆ': 'f',
    };

    const sinhalaToLatinVowels = {
      'අ': 'a', 'ආ': 'aa', 'ඇ': 'ae', 'ඈ': 'aae', 'ඉ': 'i', 'ඊ': 'ee',
      'උ': 'u', 'ඌ': 'oo', 'එ': 'e', 'ඒ': 'ee', 'ඓ': 'ai', 'ඔ': 'o', 'ඕ': 'oo', 'ඖ': 'au',
    };

    const piliToLatin = {
      'ා': 'aa', 'ැ': 'ae', 'ෑ': 'aae', 'ි': 'i', 'ී': 'ee',
      'ු': 'u', 'ූ': 'oo', 'ෘ': 'ru', 'ෲ': 'ruu',
      'ෙ': 'e', 'ේ': 'ee', 'ෛ': 'ai', 'ො': 'o', 'ෝ': 'oo', 'ෞ': 'au',
    };

    while (i < chars.length) {
      final c = chars[i];

      if (sinhalaToLatinVowels.containsKey(c)) {
        buffer.write(sinhalaToLatinVowels[c]);
        i++;
        continue;
      }

      if (sinhalaToLatinConsonants.containsKey(c)) {
        final cLatin = sinhalaToLatinConsonants[c]!;
        // Check next char for Pili or Hal-lakuna
        if (i + 1 < chars.length) {
          final nextC = chars[i + 1];
          if (nextC == '\u0DCA') { // Al-lakuna (Hal)
            buffer.write(cLatin);
            i += 2;
            continue;
          } else if (piliToLatin.containsKey(nextC)) {
            buffer.write('$cLatin${piliToLatin[nextC]}');
            i += 2;
            continue;
          }
        }
        // Default inherent 'a'
        buffer.write('${cLatin}a');
        i++;
        continue;
      }

      buffer.write(c);
      i++;
    }

    return buffer.toString().toLowerCase();
  }

  // --------------------------------------------------------------------------
  // NORMALIZATION & TOKENIZATION
  // --------------------------------------------------------------------------

  /// Normalizes Sinhala text by standardizing vowel sequences and removing zero-width joiners.
  static String normalizeSinhala(String input) {
    if (input.isEmpty) return '';
    return input
        // Remove Zero Width Joiner / Non-Joiner
        .replaceAll('\u200D', '')
        .replaceAll('\u200C', '')
        // Standardize composite kombuva + aela-pilla -> o-pilla
        .replaceAll('\u0DD9\u0DCF', '\u0DDC')
        .replaceAll('\u0DDA\u0DCF', '\u0DDD')
        .trim();
  }

  /// Removes punctuation, collapses multiple spaces, and converts Latin to lowercase.
  static String normalizeGeneral(String input) {
    if (input.isEmpty) return '';
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0D80-\u0DFF]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Checks if a string contains Sinhala Unicode characters (U+0D80 to U+0DFF).
  static bool isSinhala(String text) {
    final sinhalaRegex = RegExp(r'[\u0D80-\u0DFF]');
    return sinhalaRegex.hasMatch(text);
  }

  /// Generates a comprehensive set of normalized search tokens for a product.
  static List<String> generateSearchTokens({
    required String name,
    String? nameSinhala,
    String? nameEnglish,
    String? searchAliases,
    String? baseBarcode,
  }) {
    final tokens = <String>{};

    void addTextVariants(String text) {
      if (text.trim().isEmpty) return;
      final clean = normalizeGeneral(text);
      tokens.add(clean);
      tokens.add(clean.replaceAll(' ', ''));

      // Split into words
      final words = clean.split(' ');
      for (final w in words) {
        if (w.isNotEmpty) tokens.add(w);
      }

      // If text is Sinhala, generate Singlish equivalents
      if (isSinhala(text)) {
        final singlishVariants = sinhalaToSinglish(text);
        for (final s in singlishVariants) {
          tokens.add(s);
          tokens.add(s.replaceAll(' ', ''));
        }
      } else {
        // If text is Singlish / English, generate Sinhala equivalents
        final sinhalaVariant = singlishToSinhala(text);
        if (sinhalaVariant.isNotEmpty && isSinhala(sinhalaVariant)) {
          tokens.add(sinhalaVariant);
          tokens.add(sinhalaVariant.replaceAll(' ', ''));
        }
      }
    }

    addTextVariants(name);
    if (nameSinhala != null) addTextVariants(nameSinhala);
    if (nameEnglish != null) addTextVariants(nameEnglish);
    if (searchAliases != null) {
      final aliases = searchAliases.split(RegExp(r'[,;|\n]'));
      for (final a in aliases) {
        addTextVariants(a);
      }
    }
    if (baseBarcode != null && baseBarcode.trim().isNotEmpty) {
      tokens.add(baseBarcode.trim());
    }

    return tokens.where((t) => t.isNotEmpty).toList();
  }

  // --------------------------------------------------------------------------
  // SMART QUERY PARSER (Extracts Product Name + Quantity + Unit)
  // --------------------------------------------------------------------------

  /// Parses a cashier query like "sini 500g", "කිරි 500ml", "rice 2kg", "1 dozen eggs".
  static ParsedSearchQuery parseSearchQuery(String query) {
    final raw = query.trim();
    if (raw.isEmpty) {
      return ParsedSearchQuery(originalQuery: raw, productQuery: raw);
    }

    // 1. Check Trailing Quantity Pattern: "sini 500g", "sugar 1.5kg", "sini 1 pack", "kiri 500ml", "eggs 12pcs"
    final trailingRegex = RegExp(
      r'^(.*?)\s+(\d+(?:\.\d+)?)\s*(kg|g|gram|grams|l|ltr|liter|liters|litre|litres|ml|pcs|pc|piece|pieces|dozen|doz|pack|packs|packet|packets|box|boxes|bottle|bottles|can|cans|m|cm|mm)$',
      caseSensitive: false,
    );
    final trailingMatch = trailingRegex.firstMatch(raw);
    if (trailingMatch != null) {
      final pName = trailingMatch.group(1)!.trim();
      final qty = double.tryParse(trailingMatch.group(2)!);
      final rawUnit = trailingMatch.group(3)!;
      if (pName.isNotEmpty && qty != null && qty > 0) {
        return ParsedSearchQuery(
          originalQuery: raw,
          productQuery: pName,
          quantity: qty,
          unit: rawUnit.toLowerCase(),
          hasQuantitySpec: true,
        );
      }
    }

    // 2. Check Attached Trailing Pattern: "sini500g", "rice2kg", "kiri250ml", "sini1pack"
    final attachedRegex = RegExp(
      r'^(.*?)(\d+(?:\.\d+)?)(kg|g|l|ml|pcs|m|cm|pack|bottle|box)$',
      caseSensitive: false,
    );
    final attachedMatch = attachedRegex.firstMatch(raw);
    if (attachedMatch != null) {
      final pName = attachedMatch.group(1)!.trim();
      final qty = double.tryParse(attachedMatch.group(2)!);
      final rawUnit = attachedMatch.group(3)!;
      if (pName.isNotEmpty && qty != null && qty > 0) {
        return ParsedSearchQuery(
          originalQuery: raw,
          productQuery: pName,
          quantity: qty,
          unit: rawUnit.toLowerCase(),
          hasQuantitySpec: true,
        );
      }
    }

    // 3. Check Leading Quantity Pattern: "500g sini", "2kg rice", "1 pack sini", "1 dozen eggs"
    final leadingRegex = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(kg|g|gram|grams|l|ltr|liter|liters|ml|pcs|piece|pieces|dozen|doz|pack|packs|packet|packets|box|boxes|bottle|bottles)\s+(.*?)$',
      caseSensitive: false,
    );
    final leadingMatch = leadingRegex.firstMatch(raw);
    if (leadingMatch != null) {
      final qty = double.tryParse(leadingMatch.group(1)!);
      final rawUnit = leadingMatch.group(2)!;
      final pName = leadingMatch.group(3)!.trim();
      if (pName.isNotEmpty && qty != null && qty > 0) {
        return ParsedSearchQuery(
          originalQuery: raw,
          productQuery: pName,
          quantity: qty,
          unit: rawUnit.toLowerCase(),
          hasQuantitySpec: true,
        );
      }
    }

    return ParsedSearchQuery(originalQuery: raw, productQuery: raw);
  }

  // --------------------------------------------------------------------------
  // RANKED MULTI-TIER SEARCH ALGORITHM
  // --------------------------------------------------------------------------

  /// Filters and ranks products based on Sinhala, Singlish, English, Aliases, and Barcodes.
  static List<Product> filterAndRank(List<Product> products, String query) {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) return products;

    // Use parsed product query (cleans off "500g", "2kg", etc. so product matches accurately)
    final parsed = parseSearchQuery(rawQuery);
    final targetQuery = parsed.productQuery.isNotEmpty ? parsed.productQuery : rawQuery;

    final queryNorm = normalizeGeneral(targetQuery);
    final queryNoSpace = queryNorm.replaceAll(' ', '');
    final queryIsSinhala = isSinhala(targetQuery);

    // If query is Singlish, generate Sinhala equivalent
    final transliteratedSinhala = !queryIsSinhala ? singlishToSinhala(targetQuery) : '';
    final transliteratedNoSpace = transliteratedSinhala.replaceAll(' ', '');

    final scoredProducts = <MapEntry<Product, int>>[];

    for (final p in products) {
      if (p.deleted) continue;

      final pName = p.name;
      final pNameNorm = normalizeGeneral(pName);
      final pNameNoSpace = pNameNorm.replaceAll(' ', '');
      final pBarcode = p.baseBarcode?.trim() ?? '';
      final pSinhala = p.nameSinhala != null ? normalizeGeneral(p.nameSinhala!) : '';
      final pEnglish = p.nameEnglish != null ? normalizeGeneral(p.nameEnglish!) : '';
      final pAliases = p.searchAliases != null ? normalizeGeneral(p.searchAliases!) : '';
      final pTokens = p.normalizedTerms != null
          ? p.normalizedTerms!.split(',')
          : generateSearchTokens(
              name: p.name,
              nameSinhala: p.nameSinhala,
              nameEnglish: p.nameEnglish,
              searchAliases: p.searchAliases,
              baseBarcode: p.baseBarcode,
            );

      int score = 0;

      // 1. Exact Barcode match
      if (pBarcode.isNotEmpty && (pBarcode == rawQuery || pBarcode.contains(rawQuery))) {
        score = max(score, pBarcode == rawQuery ? 1000 : 900);
      }

      // 2. Exact Name / Sinhala / English match
      if (pNameNorm == queryNorm || pSinhala == queryNorm || pEnglish == queryNorm) {
        score = max(score, 500);
      }

      // 3. Name Prefix Match
      if (pNameNorm.startsWith(queryNorm) || pSinhala.startsWith(queryNorm) || pEnglish.startsWith(queryNorm)) {
        score = max(score, 400);
      }

      // 4. Word-boundary Prefix Match
      if (pNameNorm.contains(' $queryNorm') || pSinhala.contains(' $queryNorm') || pEnglish.contains(' $queryNorm')) {
        score = max(score, 350);
      }

      // 5. Singlish Transliteration Match (when user typed Singlish, e.g. "kiri the")
      if (transliteratedSinhala.isNotEmpty) {
        if (pNameNorm == transliteratedSinhala || pSinhala == transliteratedSinhala) {
          score = max(score, 320);
        } else if (pNameNorm.startsWith(transliteratedSinhala) || pSinhala.startsWith(transliteratedSinhala)) {
          score = max(score, 300);
        } else if (pNameNorm.contains(transliteratedSinhala) || pSinhala.contains(transliteratedSinhala)) {
          score = max(score, 250);
        } else if (pNameNoSpace.contains(transliteratedNoSpace)) {
          score = max(score, 230);
        }
      }

      // 6. Token Match (precomputed Aliases / Romanized words)
      for (final token in pTokens) {
        final tNorm = normalizeGeneral(token);
        if (tNorm.isEmpty) continue;

        if (tNorm == queryNorm || tNorm == queryNoSpace) {
          score = max(score, 200);
        } else if (tNorm.startsWith(queryNorm)) {
          score = max(score, 180);
        } else if (tNorm.contains(queryNorm)) {
          score = max(score, 150);
        }
      }

      // 7. Substring Contains Match
      if (pNameNorm.contains(queryNorm) || pSinhala.contains(queryNorm) || pEnglish.contains(queryNorm) || pAliases.contains(queryNorm)) {
        score = max(score, 120);
      }

      // 8. No-space match (e.g. "kiribath" matching "kiri bath" or vice-versa)
      if (pNameNoSpace.contains(queryNoSpace) || (queryNoSpace.isNotEmpty && queryNoSpace.contains(pNameNoSpace))) {
        score = max(score, 100);
      }

      // 9. Fuzzy matching for small typos (1-2 edits)
      if (score == 0 && queryNorm.length >= 3) {
        final dist = _levenshtein(queryNorm, pNameNorm.length >= queryNorm.length ? pNameNorm.substring(0, queryNorm.length) : pNameNorm);
        if (dist <= 1) {
          score = 50;
        } else if (dist == 2 && queryNorm.length >= 5) {
          score = 30;
        }
      }

      if (score > 0) {
        scoredProducts.add(MapEntry(p, score));
      }
    }

    // Sort descending by score, then alphabetically by name
    scoredProducts.sort((a, b) {
      final scoreCmp = b.value.compareTo(a.value);
      if (scoreCmp != 0) return scoreCmp;
      return a.key.name.compareTo(b.key.name);
    });

    return scoredProducts.map((e) => e.key).toList();
  }

  // Fast Levenshtein distance for fuzzy matching
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[b.length];
  }
}
