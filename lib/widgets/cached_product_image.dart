import 'dart:io';
import 'package:flutter/material.dart';
import '../services/local_media_storage_service.dart';

/// Fast, offline-first image widget that stores and reads product images
/// directly from local device storage with seamless fallback.
class CachedProductImage extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget placeholder;

  const CachedProductImage({
    super.key,
    required this.imageUrl,
    this.width = 40,
    this.height = 40,
    this.fit = BoxFit.cover,
    required this.placeholder,
  });

  @override
  State<CachedProductImage> createState() => _CachedProductImageState();
}

class _CachedProductImageState extends State<CachedProductImage> {
  File? _localFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant CachedProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) {
      if (mounted) setState(() => _localFile = null);
      return;
    }

    // Check if local file is already cached without network
    final cached = await LocalMediaStorageService.instance.getCachedFile(url);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _localFile = cached;
          _isLoading = false;
        });
      }
      return;
    }

    // If it's a local file that does not exist
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (mounted) {
        setState(() {
          _localFile = null;
          _isLoading = false;
        });
      }
      return;
    }

    // Asynchronously download and store to device storage
    if (mounted) setState(() => _isLoading = true);

    final file = await LocalMediaStorageService.instance.getOrDownloadImage(url);
    if (mounted) {
      setState(() {
        _localFile = file;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_localFile != null && _localFile!.existsSync()) {
      return Image.file(
        _localFile!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => widget.placeholder,
      );
    }

    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    // Fallback: if download hasn't finished or failed, attempt direct network load
    if (widget.imageUrl.startsWith('http://') || widget.imageUrl.startsWith('https://')) {
      return Image.network(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => widget.placeholder,
      );
    }

    return widget.placeholder;
  }
}
