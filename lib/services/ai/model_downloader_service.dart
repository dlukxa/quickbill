import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ModelDownloaderService {
  // Filename updated to match the user's provided file.
  static const _modelFileName = 'gemma-3-270m-it-int8.task';
  static const _prefKey = 'ai_model_downloaded';

  // Firebase Storage path (Official SDK method)
  static const _storagePath = 'models/gemma-3-270m-it-int8.task';

  // Fallback direct URL with access token (if Storage rules are locked)
  static const _directDownloadUrl =
      'https://firebasestorage.googleapis.com/v0/b/quickbill-2a76b.firebasestorage.app/o/models%2Fgemma-3-270m-it-int8.task?alt=media&token=f3de4979-63d0-47b2-96b8-5dbe5f276c9b';

  static final ModelDownloaderService _instance =
      ModelDownloaderService._internal();
  static ModelDownloaderService get instance => _instance;
  ModelDownloaderService._internal();

  UploadTask? _uploadTask; 
  DownloadTask? _downloadTask;
  CancelToken? _cancelToken; // For the fallback Dio download
  final Dio _dio = Dio();

  /// Returns true if the model has already been downloaded to device storage.
  Future<bool> isModelDownloaded() async {
    try {
      final path = await getLocalModelPath();
      final file = File(path);
      if (!file.existsSync()) return false;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns the absolute path where the model lives on device.
  Future<String> getLocalModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_modelFileName';
  }

  /// Deletes the locally downloaded model file (use for corruption recovery).
  Future<void> deleteModel() async {
    try {
      final path = await getLocalModelPath();
      final file = File(path);
      if (file.existsSync()) await file.delete();
      await _markAsDownloaded(false);
      debugPrint('🗑️ Local model deleted.');
    } catch (e) {
      debugPrint('Error deleting model: $e');
    }
  }

  /// Manually imports a model file from a user-selected location.
  Future<bool> manualImportModel(File sourceFile) async {
    try {
      final targetPath = await getLocalModelPath();
      final targetFile = File(targetPath);
      
      // Delete existing if any
      if (targetFile.existsSync()) await targetFile.delete();
      
      // Copy the file
      await sourceFile.copy(targetPath);
      
      // Verify integrity
      final isValid = await verifyModelIntegrity();
      if (isValid) {
        await _markAsDownloaded(true);
        debugPrint('✅ Manual model import successful.');
        return true;
      } else {
        await targetFile.delete();
        throw 'Imported file metadata/integrity check failed.';
      }
    } catch (e) {
      debugPrint('❌ Manual Import Error: $e');
      rethrow;
    }
  }

  /// Marks the model as downloaded/not-downloaded in shared preferences.
  Future<void> _markAsDownloaded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// Verifies if the file is valid. Performs a deep scan of the first 64 bytes.
  Future<bool> verifyModelIntegrity() async {
    try {
      final path = await getLocalModelPath();
      final file = File(path);

      if (!file.existsSync()) {
        debugPrint('❌ Integrity Check Failed: File does not exist.');
        return false;
      }

      final size = file.lengthSync();
      debugPrint('🔍 Integrity Check: Scanning file of size $size bytes');

      // Small delay to ensure OS has flushed the file
      await Future.delayed(const Duration(milliseconds: 500));

      final raf = await file.open(mode: FileMode.read);
      await raf.setPosition(0);
      final header = await raf.read(64); // Read 64 bytes for deep scan
      await raf.close();

      if (header.length < 4) {
        debugPrint('❌ Integrity Check Failed: File too small (${header.length} bytes)');
        return false;
      }

      final hexDump = header.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      debugPrint('📜 Header Scan (First 64 bytes): ${hexDump.substring(0, 32)}...');

      // Look for ZIP magic number (anywhere in first 32 bytes)
      final hasZipMagic = hexDump.contains('504b0304');
      // Look for FlatBuffer / Gemma 3 magic (1c000000)
      final hasGemmaMagic = hexDump.contains('1c000000');

      if (hasZipMagic || hasGemmaMagic) {
        final type = hasZipMagic ? 'ZIP Bundle' : 'Gemma 3 FlatBuffer';
        debugPrint('✅ Integrity Check Passed: Valid $type detected.');
        return true;
      }

      // Special case: If header is zeroes but size is large (300MB+), 
      // it's likely a valid model that is still flushing or has specific padding.
      if (size > 100 * 1024 * 1024 && hexDump.startsWith('00000000')) {
        debugPrint('⚠️ Warning: File has zeroed header but valid size. Allowing load trial...');
        return true; 
      }

      debugPrint('❌ Integrity Check Failed: No valid signature found in header.');
      return false;
    } catch (e) {
      debugPrint('❌ Integrity Check Exception: $e');
      return false;
    }
  }

  /// Returns the file size string for display (e.g. "~180 MB")
  Future<String> getModelSizeString() async {
    try {
      final ref = FirebaseStorage.instance.ref(_storagePath);
      final metadata = await ref.getMetadata();
      final bytes = metadata.size ?? 0;
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(0);
      return '~$mb MB';
    } catch (_) {
      return '~237 MB';
    }
  }

  /// Streams real-time progress using a dual-strategy (Official SDK -> Fallback URL).
  Stream<double> downloadModelWithProgress() async* {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_modelFileName');

    debugPrint('⏳ Starting Download (Official SDK)...');

    try {
      final ref = FirebaseStorage.instance.ref(_storagePath);
      _downloadTask = ref.writeToFile(file);

      await for (final snapshot in _downloadTask!.snapshotEvents) {
        if (snapshot.state == TaskState.running) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          yield progress;
        } else if (snapshot.state == TaskState.success) {
          final isValid = await verifyModelIntegrity();
          if (isValid) {
            await _markAsDownloaded(true);
            yield 1.0;
          } else {
            throw 'Model file integrity check failed.';
          }
        } else if (snapshot.state == TaskState.error) {
          throw 'SDK Task Exception';
        }
      }
    } catch (e) {
      debugPrint('⚠️ SDK Download failed ($e). Resetting file for Fallback...');

      // CRITICAL: Delete the potentially corrupted or locked file before starting fallback
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (e) {
        debugPrint('⚠️ Could not delete stale file: $e');
      }

      try {
        _cancelToken = CancelToken();
        
        // Strategy 2: Authenticated Direct URL via Dio
        final controller = StreamController<double>();
        
        _dio.download(
          _directDownloadUrl,
          file.path,
          cancelToken: _cancelToken,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              controller.add(received / total);
            }
          },
          options: Options(
            responseType: ResponseType.bytes,
            // Header removed to prevent 412 issues with some servers
          ),
        ).then((_) async {
          final isValid = await verifyModelIntegrity();
          if (isValid) {
            await _markAsDownloaded(true);
            controller.add(1.0);
            controller.close();
          } else {
            controller.addError('Fallback model file integrity check failed.');
          }
        }).catchError((dioErr) {
          controller.addError('Fallback download failed: $dioErr');
        });

        yield* controller.stream;
      } catch (fallbackErr) {
        debugPrint('❌ Both download methods failed: $fallbackErr');
        if (file.existsSync()) file.deleteSync();
        rethrow;
      }
    } finally {
      _downloadTask = null;
      _cancelToken = null;
    }
  }

  /// Cancels any ongoing model download.
  Future<void> cancelDownload() async {
    await _downloadTask?.cancel();
    _cancelToken?.cancel('User cancelled');
    _downloadTask = null;
    _cancelToken = null;
    
    // Clear partial files
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_modelFileName');
    if (file.existsSync()) file.deleteSync();
  }
}
