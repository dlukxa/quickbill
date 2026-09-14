import 'dart:io';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Reusable store branding logo widget supporting custom store logos (network or local file)
/// with seamless fallback to the default QuickBill logo asset and icon fallback.
class StoreLogoWidget extends StatelessWidget {
  final String? logoUrl;
  final double? size;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final BoxFit fit;
  final EdgeInsetsGeometry? padding;
  final Widget? fallback;

  const StoreLogoWidget({
    super.key,
    this.logoUrl,
    this.size,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.backgroundColor,
    this.border,
    this.fit = BoxFit.contain,
    this.padding,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size ?? 36.0;
    final effectiveHeight = height ?? size ?? 36.0;

    Widget imageContent = _buildImage(effectiveWidth, effectiveHeight);

    if (padding != null) {
      imageContent = Padding(
        padding: padding!,
        child: imageContent,
      );
    }

    return Container(
      width: effectiveWidth,
      height: effectiveHeight,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageContent,
      ),
    );
  }

  Widget _buildImage(double w, double h) {
    if (logoUrl != null && logoUrl!.trim().isNotEmpty) {
      final cleanUrl = logoUrl!.trim();
      if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        return Image.network(
          cleanUrl,
          width: w,
          height: h,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(w, h),
        );
      } else {
        try {
          final file = File(cleanUrl);
          if (file.existsSync()) {
            return Image.file(
              file,
              width: w,
              height: h,
              fit: fit,
              errorBuilder: (_, __, ___) => _buildFallback(w, h),
            );
          }
        } catch (_) {}
      }
    }

    return _buildFallback(w, h);
  }

  Widget _buildFallback(double w, double h) {
    if (fallback != null) return fallback!;
    return Image.asset(
      'assets/images/logo.png',
      width: w,
      height: h,
      fit: fit,
      errorBuilder: (_, __, ___) => Center(
        child: Icon(
          Icons.storefront_rounded,
          color: AppTheme.primaryGreen,
          size: (w < h ? w : h) * 0.7,
        ),
      ),
    );
  }
}
