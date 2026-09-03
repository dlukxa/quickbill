import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../providers/preference_provider.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'si', 'name': 'Sinhala', 'native': 'සිංහල'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা'},
    {'code': 'dv', 'name': 'Dhivehi', 'native': 'ދިވެހި'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final currentLang = _languages.firstWhere(
      (lang) => lang['code'] == settings.languageCode,
      orElse: () => _languages.first,
    );

    return PopupMenuButton<String>(
      onSelected: (code) => notifier.updateLanguage(code),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: context.cardColor,
      position: PopupMenuPosition.under,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language_rounded, size: 18, color: context.onSurface),
            const SizedBox(width: 6),
            Text(
              currentLang['native']!,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: context.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: context.subText),
          ],
        ),
      ),
      itemBuilder: (context) {
        return _languages.map((lang) {
          final isSelected = settings.languageCode == lang['code'];
          return PopupMenuItem<String>(
            value: lang['code'],
            child: Row(
              children: [
                Text(
                  lang['native']!,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryGreen : context.onSurface,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  const Icon(Icons.check_rounded, size: 18, color: AppTheme.primaryGreen),
                ],
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
