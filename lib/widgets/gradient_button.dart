import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double? width;
  final double height;
  final List<Color>? colors;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.width,
    this.height = 56,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: isDisabled 
            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
            : (colors != null 
                ? LinearGradient(colors: colors!, begin: Alignment.topLeft, end: Alignment.bottomRight)
                : AppTheme.primaryGradient),
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDisabled ? [] : [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Center(
            child: DefaultTextStyle(
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
