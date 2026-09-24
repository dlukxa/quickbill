import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/sinhala_transliteration_service.dart';

/// Interactive suggestion banner that displays below an Item Name / Product input field.
/// Example:
/// ✨ Sinhala suggestion: කිරි සම්බා   [Use]
class SinhalaSuggestionBanner extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback? onApplied;
  final bool isDark;

  const SinhalaSuggestionBanner({
    super.key,
    required this.controller,
    this.focusNode,
    this.onApplied,
    this.isDark = false,
  });

  @override
  State<SinhalaSuggestionBanner> createState() => _SinhalaSuggestionBannerState();
}

class _SinhalaSuggestionBannerState extends State<SinhalaSuggestionBanner> {
  SinhalaSuggestion? _suggestion;
  String? _appliedText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  @override
  void didUpdateWidget(covariant SinhalaSuggestionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _onTextChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || text == _appliedText) {
      if (_suggestion != null && mounted) {
        setState(() => _suggestion = null);
      }
      return;
    }

    final newSuggestion = SinhalaTransliterationService.getSuggestion(text);
    if (mounted) {
      setState(() {
        _suggestion = newSuggestion;
      });
    }
  }

  void _applySuggestion() {
    if (_suggestion == null) return;
    final converted = _suggestion!.converted;
    _appliedText = converted;

    widget.controller.text = converted;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: converted.length),
    );

    if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
      widget.focusNode!.requestFocus();
    }

    setState(() => _suggestion = null);
    widget.onApplied?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_suggestion == null || !_suggestion!.hasChange) {
      return const SizedBox.shrink();
    }

    final isDark = widget.isDark;
    final bgColor = isDark
        ? AppTheme.primaryGreen.withValues(alpha: 0.15)
        : const Color(0xFFE8F5E9);
    final borderColor = isDark
        ? AppTheme.primaryGreen.withValues(alpha: 0.35)
        : const Color(0xFFA5D6A7);
    final textColor = isDark ? Colors.white : const Color(0xFF1B5E20);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 13, color: textColor),
                children: [
                  TextSpan(
                    text: 'Sinhala suggestion: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF2E7D32),
                    ),
                  ),
                  TextSpan(
                    text: _suggestion!.converted,
                    style: GoogleFonts.notoSansSinhala(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _applySuggestion,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Use',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact `[සිං]` suffix conversion button to place inside `InputDecoration.suffixIcon`.
class SinhalaConvertSuffix extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onConverted;
  final bool isDark;

  const SinhalaConvertSuffix({
    super.key,
    required this.controller,
    this.onConverted,
    this.isDark = false,
  });

  void _convert() {
    final text = controller.text;
    if (text.trim().isEmpty) return;

    final converted = SinhalaTransliterationService.transliterate(text);
    if (converted.isNotEmpty && converted != text) {
      controller.text = converted;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: converted.length),
      );
      onConverted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Tooltip(
        message: 'Convert Singlish to Sinhala Unicode',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _convert,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'සිං',
                style: GoogleFonts.notoSansSinhala(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension on [InputDecoration] to seamlessly inject Singlish conversion support.
extension SinglishInputDecorationExtension on InputDecoration {
  InputDecoration withSinglishSuffix({
    required TextEditingController controller,
    VoidCallback? onConverted,
    bool isDark = false,
  }) {
    final badge = SinhalaConvertSuffix(
      controller: controller,
      onConverted: onConverted,
      isDark: isDark,
    );
    if (suffixIcon != null) {
      return copyWith(
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            suffixIcon!,
          ],
        ),
      );
    }
    return copyWith(suffixIcon: badge);
  }
}

/// Universal TextField with integrated Singlish-to-Sinhala Unicode support.
/// Automatically injects a `[සිං]` conversion badge and an optional inline
/// suggestion banner below the field.
class SinglishTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final TextStyle? style;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final bool showSuggestionBanner;
  final bool showConvertBadge;
  final VoidCallback? onConverted;

  const SinglishTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.style,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
    this.showSuggestionBanner = true,
    this.showConvertBadge = true,
    this.onConverted,
  });

  @override
  State<SinglishTextField> createState() => _SinglishTextFieldState();
}

class _SinglishTextFieldState extends State<SinglishTextField> {
  late FocusNode _focusNode;
  bool _internalFocusNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _internalFocusNode = true;
    }
  }

  @override
  void didUpdateWidget(covariant SinglishTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (_internalFocusNode) {
        _focusNode.dispose();
        _internalFocusNode = false;
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
      } else {
        _focusNode = FocusNode();
        _internalFocusNode = true;
      }
    }
  }

  @override
  void dispose() {
    if (_internalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget? effectiveSuffix = widget.decoration.suffixIcon;
    if (widget.showConvertBadge && widget.enabled && !widget.readOnly) {
      final badge = SinhalaConvertSuffix(
        controller: widget.controller,
        onConverted: widget.onConverted,
        isDark: isDark,
      );
      if (effectiveSuffix != null) {
        effectiveSuffix = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              badge,
              effectiveSuffix,
            ],
          ),
        );
      } else {
        effectiveSuffix = badge;
      }
    }

    final textField = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: widget.decoration.copyWith(
        suffixIcon: effectiveSuffix,
        suffixIconConstraints: widget.decoration.suffixIconConstraints ??
            const BoxConstraints(minWidth: 40, maxWidth: 240, minHeight: 36, maxHeight: 48),
      ),
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      style: widget.style,
      textAlign: widget.textAlign,
      inputFormatters: widget.inputFormatters,
    );

    if (!widget.showSuggestionBanner || !widget.enabled || widget.readOnly) {
      return textField;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        textField,
        SinhalaSuggestionBanner(
          controller: widget.controller,
          focusNode: _focusNode,
          onApplied: widget.onConverted,
          isDark: isDark,
        ),
      ],
    );
  }
}

/// Universal TextFormField with integrated Singlish-to-Sinhala Unicode support
/// and Form validation.
class SinglishTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final TextStyle? style;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final bool showSuggestionBanner;
  final bool showConvertBadge;
  final VoidCallback? onConverted;
  final AutovalidateMode? autovalidateMode;

  const SinglishTextFormField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.validator,
    this.onSaved,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.style,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
    this.showSuggestionBanner = true,
    this.showConvertBadge = true,
    this.onConverted,
    this.autovalidateMode,
  });

  @override
  State<SinglishTextFormField> createState() => _SinglishTextFormFieldState();
}

class _SinglishTextFormFieldState extends State<SinglishTextFormField> {
  late FocusNode _focusNode;
  bool _internalFocusNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _internalFocusNode = true;
    }
  }

  @override
  void didUpdateWidget(covariant SinglishTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (_internalFocusNode) {
        _focusNode.dispose();
        _internalFocusNode = false;
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
      } else {
        _focusNode = FocusNode();
        _internalFocusNode = true;
      }
    }
  }

  @override
  void dispose() {
    if (_internalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget? effectiveSuffix = widget.decoration.suffixIcon;
    if (widget.showConvertBadge && widget.enabled && !widget.readOnly) {
      final badge = SinhalaConvertSuffix(
        controller: widget.controller,
        onConverted: widget.onConverted,
        isDark: isDark,
      );
      if (effectiveSuffix != null) {
        effectiveSuffix = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            effectiveSuffix,
          ],
        );
      } else {
        effectiveSuffix = badge;
      }
    }

    final formField = TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: widget.decoration.copyWith(suffixIcon: effectiveSuffix),
      validator: widget.validator,
      onSaved: widget.onSaved,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      style: widget.style,
      textAlign: widget.textAlign,
      inputFormatters: widget.inputFormatters,
      autovalidateMode: widget.autovalidateMode,
    );

    if (!widget.showSuggestionBanner || !widget.enabled || widget.readOnly) {
      return formField;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        formField,
        SinhalaSuggestionBanner(
          controller: widget.controller,
          focusNode: _focusNode,
          onApplied: widget.onConverted,
          isDark: isDark,
        ),
      ],
    );
  }
}
