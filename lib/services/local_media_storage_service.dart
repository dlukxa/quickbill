import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';

final localMediaStorageServiceProvider = Provider<LocalMediaStorageService>((ref) {
  return LocalMediaStorageService.instance;
});

/// Manages offline caching and persistent device storage for product images,
/// shop logos, receipts, and media assets across Mobile & Desktop.
class LocalMediaStorageService {
  static final LocalMediaStorageService instance = LocalMediaStorageService._init();
  LocalMediaStorageService._init();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  Directory? _mediaDirectory;
  bool _isPrefetching = false;

  /// Returns the persistent local media directory for the app.
  Future<Directory> getMediaDirectory() async {
    if (_mediaDirectory != null && await _mediaDirectory!.exists()) {
      return _mediaDirectory!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'product_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _mediaDirectory = dir;
    return dir;
  }

  /// Calculates a stable local file path based on MD5 hash of the remote URL.
  Future<String> getLocalPathForUrl(String url) async {
    final dir = await getMediaDirectory();
    final hash = md5.convert(utf8.encode(url.trim())).toString();
    return p.join(dir.path, '$hash.jpg');
  }

  /// Returns the local File if it exists, or downloads and caches it locally.
  Future<File?> getOrDownloadImage(String urlOrPath) async {
    final trimmed = urlOrPath.trim();
    if (trimmed.isEmpty) return null;

    // If it's already a local file path
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      final localFile = File(trimmed);
      return (await localFile.exists()) ? localFile : null;
    }

    // It's a remote URL: check if local cached file exists
    try {
      final localPath = await getLocalPathForUrl(trimmed);
      final localFile = File(localPath);
      if (await localFile.exists()) {
        final length = await localFile.length();
        if (length > 0) return localFile;
      }

      // Download from remote URL and save to local storage
      final response = await _dio.download(
        trimmed,
        localPath,
        deleteOnError: true,
      );

      if (response.statusCode == 200 && await localFile.exists()) {
        return localFile;
      }
      return null;
    } catch (e) {
      debugPrint('LocalMediaStorageService: Error caching image ($trimmed): $e');
      return null;
    }
  }

  /// Synchronously checks if an image URL already has a cached local file.
  Future<File?> getCachedFile(String urlOrPath) async {
    final trimmed = urlOrPath.trim();
    if (trimmed.isEmpty) return null;

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      final file = File(trimmed);
      return (await file.exists()) ? file : null;
    }

    final localPath = await getLocalPathForUrl(trimmed);
    final file = File(localPath);
    if (await file.exists() && (await file.length()) > 0) {
      return file;
    }
    return null;
  }

  /// Permanently copies a user-picked or camera image to the app's persistent storage.
  Future<String> saveLocalImagePermanently(File sourceFile, {String? customPrefix}) async {
    final dir = await getMediaDirectory();
    final ext = p.extension(sourceFile.path).isNotEmpty ? p.extension(sourceFile.path) : '.jpg';
    final prefix = customPrefix ?? 'product';
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destinationPath = p.join(dir.path, fileName);
    
    await sourceFile.copy(destinationPath);
    return destinationPath;
  }

  /// Immediately associates and caches an uploaded local file under its remote URL hash,
  /// so this device never has to re-download the file after uploading to cloud.
  Future<void> saveLocalUploadedImage({required File localFile, required String remoteUrl}) async {
    try {
      if (!await localFile.exists()) return;
      final localPath = await getLocalPathForUrl(remoteUrl);
      if (localPath != localFile.path) {
        await localFile.copy(localPath);
      }
    } catch (e) {
      debugPrint('LocalMediaStorageService: Error associating uploaded image: $e');
    }
  }

  /// Proactively downloads and stores all product images onto the device in the background.
  /// Runs with concurrency limit to prevent freezing network or CPU.
  Future<void> prefetchAllProductImages(
    List<Product> products, {
    void Function(int current, int total)? onProgress,
  }) async {
    if (_isPrefetching) return;
    _isPrefetching = true;

    try {
      final remoteUrls = products
          .map((p) => p.imageUrl?.trim())
          .where((url) => url != null && (url.startsWith('http://') || url.startsWith('https://')))
          .cast<String>()
          .toSet()
          .toList();

      if (remoteUrls.isEmpty) {
        _isPrefetching = false;
        onProgress?.call(0, 0);
        return;
      }

      int completed = 0;
      final total = remoteUrls.length;

      // Download in batches of 4
      const concurrency = 4;
      for (int i = 0; i < remoteUrls.length; i += concurrency) {
        final end = (i + concurrency < remoteUrls.length) ? i + concurrency : remoteUrls.length;
        final batch = remoteUrls.sublist(i, end);

        await Future.wait(
          batch.map((url) async {
            try {
              final cached = await getCachedFile(url);
              if (cached == null) {
                await getOrDownloadImage(url);
              }
            } catch (_) {}
            completed++;
            onProgress?.call(completed, total);
          }),
        );
      }
    } catch (e) {
      debugPrint('LocalMediaStorageService: Error during prefetch: $e');
    } finally {
      _isPrefetching = false;
    }
  }

  /// Downloads and caches the shop logo locally for offline receipt printing.
  Future<File?> cacheShopLogo(String logoUrl) async {
    final trimmed = logoUrl.trim();
    if (trimmed.isEmpty) return null;
    return await getOrDownloadImage(trimmed);
  }

  /// Returns storage statistics for cached media (count and total size in MB).
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final dir = await getMediaDirectory();
      final entities = await dir.list().toList();
      int totalBytes = 0;
      int imageCount = 0;

      for (final entity in entities) {
        if (entity is File) {
          imageCount++;
          totalBytes += await entity.length();
        }
      }

      final mb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
      return {
        'count': imageCount,
        'bytes': totalBytes,
        'formattedSize': '$mb MB',
      };
    } catch (e) {
      return {'count': 0, 'bytes': 0, 'formattedSize': '0 MB'};
    }
  }

  /// Deletes all cached product images from local storage.
  Future<void> clearImageCache() async {
    try {
      final dir = await getMediaDirectory();
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        for (final entity in entities) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('LocalMediaStorageService: Error clearing image cache: $e');
    }
  }
}
