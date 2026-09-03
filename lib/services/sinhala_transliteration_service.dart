/// Representation of a Sinhala transliteration suggestion with confidence score.
class SinhalaSuggestion {
  final String original;
  final String converted;
  final bool isExactDictionary;
  final double confidence; // 0.0 to 1.0

  const SinhalaSuggestion({
    required this.original,
    required this.converted,
    this.isExactDictionary = false,
    this.confidence = 1.0,
  });

  bool get hasChange => original.trim().toLowerCase() != converted.trim().toLowerCase();
}

/// Standalone, reusable Sri Lankan Singlish -> Sinhala Transliteration Engine.
/// Designed for Quick Entry, Product Creation, Editing, Billing, and Search.
class SinhalaTransliterationService {
  SinhalaTransliterationService._();
  static final SinhalaTransliterationService instance = SinhalaTransliterationService._();

  // ---------------------------------------------------------------------------
  // DICTIONARY: Common Sri Lankan POS / Grocery / Retail Words & Phrases
  // ---------------------------------------------------------------------------
  static const Map<String, String> _dictionary = {
    // Multi-word phrases
    'kiri samba': 'කිරි සම්බා',
    'kirisamba': 'කිරි සම්බා',
    'keeri samba': 'කීරි සම්බා',
    'keerisamba': 'කීරි සම්බා',
    'sudu seeni': 'සුදු සීනි',
    'suduseeni': 'සුදු සීනි',
    'rathu seeni': 'රතු සීනි',
    'rathuseeni': 'රතු සීනි',
    'sudu kekulu': 'සුදු කැකුළු',
    'rathu kekulu': 'රතු කැකුළු',
    'sudu kakulu': 'සුදු කැකුළු',
    'rathu kakulu': 'රතු කැකුළු',
    'kiri bath': 'කිරිබත්',
    'kukul mas': 'කුකුල් මස්',
    'kukulmas': 'කුකුල් මස්',
    'soya meat': 'සෝයා මීට්',
    'mun ata': 'මුං ඇට',
    'sudu kek': 'සුදු කේක්',
    'sudu cake': 'සුදු කේක්',
    'pol thel': 'පොල් තෙල්',
    'pol tel': 'පොල් තෙල්',
    'eliya thel': 'එළිය තෙල්',
    'ela kiri': 'එළකිරි',
    'elakiri': 'එළකිරි',
    'rathu hal': 'රතු හාල්',
    'sudu hal': 'සුදු හාල්',

    // Core staple food & groceries
    'kiri': 'කිරි',
    'the': 'තේ',
    'thee': 'තේ',
    'tea': 'තේ',
    'bath': 'බත්',
    'baath': 'බත්',
    'kiribath': 'කිරිබත්',
    'seeni': 'සීනි',
    'sini': 'සීනි',
    'sugar': 'සීනි',
    'paan': 'පාන්',
    'paen': 'පාන්',
    'pan': 'පාන්',
    'bread': 'පාන්',
    'piti': 'පිටි',
    'flour': 'පිටි',
    'pol': 'පොල්',
    'coconut': 'පොල්',
    'thel': 'තෙල්',
    'tel': 'තෙල්',
    'oil': 'තෙල්',
    'kopi': 'කෝපි',
    'coffee': 'කෝපි',
    'kottu': 'කොත්තු',
    'kotthu': 'කොත්තු',
    'roti': 'රොටි',
    'rotie': 'රොටි',
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
    'dehi': 'දෙහි',
    'lime': 'දෙහි',
    'kurundu': 'කුරුඳු',
    'cinnamon': 'කුරුඳු',
    'gammaris': 'ගම්මිරිස්',
    'gammiris': 'ගම්මිරිස්',
    'pepper': 'ගම්මිරිස්',
    'uluhaal': 'උළුහාල්',
    'ulu hal': 'උළුහාල්',
    'kadala': 'කඩල',
    'gram': 'කඩල',
    'kollu': 'කොල්ලු',
    'kesel': 'කෙසෙල්',
    'banana': 'කෙසෙල්',
    'papol': 'පැපොල්',
    'papaya': 'පැපොල්',
    'amba': 'අඹ',
    'mango': 'අඹ',
    'annasi': 'අන්නාසි',
    'pineapple': 'අන්නාසි',
    'dodan': 'දොඩම්',
    'orange': 'දොඩම්',
    'pera': 'පේර',
    'guava': 'පේර',
    'apple': 'ඇපල්',
    'midi': 'මිදි',
    'grapes': 'මිදි',
    'saban': 'සබන්',
    'sabang': 'සබන්',
    'soap': 'සබන්',
    'shampoo': 'ෂැම්පු',
    'datbeheth': 'දත් බෙහෙත්',
    'toothpaste': 'දත් බෙහෙත්',
    'brush': 'බුරුසුව',
    'panchi': 'පැකට්',
    'packet': 'පැකට්',
    'botle': 'බෝතල්',
    'bottle': 'බෝතල්',
    'tikiri': 'ටිකිරි',
    'munchee': 'මන්චි',
    'maliban': 'මැලිබන්',
    'anchor': 'ඇන්කර්',
    'raththi': 'රත්ථි',
    'rathi': 'රත්ථි',
    'highland': 'හයිලන්ඩ්',
    'kotmale': 'කොත්මලේ',
    'pelwatte': 'පැල්වත්ත',
    'md': 'එම්.ඩී',
    'knorr': 'නෝර්',
    'maggi': 'මැගී',
    'sunlight': 'සන්ලයිට්',
    'vim': 'විම්',
    'harpic': 'හාපික්',
    'lifebuoy': 'ලයිෆ්බෝයි',
    'signal': 'සිග්නල්',
    'clogard': 'ක්ලෝගාඩ්',
    'special': 'ස්පෙෂල්',
  };

  // ---------------------------------------------------------------------------
  // PHONETIC ENGINE TABLES
  // ---------------------------------------------------------------------------
  static const Map<String, String> _independentVowels = {
    'aa': 'ආ',
    'aae': 'ඈ',
    'ae': 'ඇ',
    'a': 'අ',
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

  /// Checks whether a string contains Sinhala Unicode characters (\u0D80 - \u0DFF).
  static bool isSinhala(String text) {
    return RegExp(r'[\u0D80-\u0DFF]').hasMatch(text);
  }

  /// Converts Singlish / Romanized text to Sinhala Unicode.
  /// Preserves numbers, units (`1kg`, `400g`, `500ml`), prices, and punctuation.
  static String transliterate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // If whole string is in dictionary (e.g. "kiri samba")
    final lower = trimmed.toLowerCase();
    if (_dictionary.containsKey(lower)) {
      return _dictionary[lower]!;
    }

    // Process tokens while preserving whitespace, punctuation, numbers, and units
    final tokens = _tokenize(trimmed);
    final buffer = StringBuffer();

    for (final token in tokens) {
      if (token.isWhitespaceOrPunctuation || token.isNumberOrUnit) {
        buffer.write(token.raw);
      } else {
        final tokenLower = token.raw.toLowerCase();
        if (_dictionary.containsKey(tokenLower)) {
          buffer.write(_dictionary[tokenLower]);
        } else {
          buffer.write(_transliterateWord(tokenLower));
        }
      }
    }

    return buffer.toString();
  }

  /// Produces a suggestion for the user to review.
  /// Returns `null` if the input is empty or already in Sinhala Unicode.
  static SinhalaSuggestion? getSuggestion(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // If input already contains Sinhala characters, no conversion needed
    if (isSinhala(trimmed)) return null;

    // Check exact dictionary match for whole input
    final lower = trimmed.toLowerCase();
    if (_dictionary.containsKey(lower)) {
      return SinhalaSuggestion(
        original: input,
        converted: _dictionary[lower]!,
        isExactDictionary: true,
        confidence: 1.0,
      );
    }

    // Perform transliteration
    final converted = transliterate(input);
    if (converted.isEmpty || converted.toLowerCase() == lower) {
      return null;
    }

    final isDictWord = _dictionary.containsKey(lower);
    return SinhalaSuggestion(
      original: input,
      converted: converted,
      isExactDictionary: isDictWord,
      confidence: isDictWord ? 1.0 : 0.9,
    );
  }

  /// Transliterates an individual word phonetically.
  static String _transliterateWord(String word) {
    if (word.isEmpty) return '';
    final buffer = StringBuffer();
    int i = 0;
    final len = word.length;

    while (i < len) {
      final char = word[i];

      // Non-lowercase ASCII alphabet
      if (char.codeUnitAt(0) < 97 || char.codeUnitAt(0) > 122) {
        buffer.write(char);
        i++;
        continue;
      }

      // 1. Check for consonant matches
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

        // Look for vowel stroke after consonant
        String? matchedVowel;
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
            buffer.write(cSinhala);
          } else {
            buffer.write('$cSinhala${_vowelStrokes[matchedVowel] ?? ""}');
          }
        } else {
          // No vowel: write consonant with Hal-kirima (Al-lakuna)
          buffer.write('$cSinhala\u0DCA');
        }
      } else {
        // 2. Starts with an independent vowel
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

  /// Tokenizes string into words, numbers with units (e.g. 1kg, 500ml), and punctuation.
  static List<_InputToken> _tokenize(String text) {
    final tokens = <_InputToken>[];
    final regex = RegExp(
      r'(rs\.?|lkr\.?|\d+(?:\.\d+)?(?:kg|g|l|ml|pcs|pack|pk|m|cm|mm|rs|lkr)?)|([a-zA-Z]+)|([^\s\w]+)|(\s+)',
      caseSensitive: false,
    );
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final raw = match.group(0)!;
      final isNumUnit = match.group(1) != null;
      final isWord = match.group(2) != null;
      final isPunct = match.group(3) != null;
      final isSpace = match.group(4) != null;

      tokens.add(_InputToken(
        raw: raw,
        isNumberOrUnit: isNumUnit,
        isWord: isWord,
        isWhitespaceOrPunctuation: isPunct || isSpace,
      ));
    }

    return tokens;
  }
}

class _InputToken {
  final String raw;
  final bool isNumberOrUnit;
  final bool isWord;
  final bool isWhitespaceOrPunctuation;

  const _InputToken({
    required this.raw,
    required this.isNumberOrUnit,
    required this.isWord,
    required this.isWhitespaceOrPunctuation,
  });
}
