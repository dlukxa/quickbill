import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

class StorageService {
  static final StorageService instance = StorageService._init();
  StorageService._init();

  FirebaseStorage? get _storage {
    try {
      if (Platform.isWindows || Platform.isLinux) return null;
      if (Firebase.apps.isEmpty) return null;
      return FirebaseStorage.instance;
    } catch (_) {
      return null;
    }
  }

  /// Uploads a file to Firebase Storage.
  /// [path] is the relative path in the bucket (e.g. 'products/123.jpg')
  Future<String?> uploadImage({
    required String path,
    required File imageFile,
    int? maxWidth, // Kept for API compatibility but ignored as we rely on native picker
  }) async {
    final storage = _storage;
    if (storage == null) return null;

    try {
      // Upload directly - UI should handle resizing via ImagePicker for better memory performance
      final ref = storage.ref().child(path);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      
      final uploadTask = ref.putFile(imageFile, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Storage Upload Error: $e');
      return null;
    }
  }

  Future<void> deleteImage(String url) async {
    final storage = _storage;
    if (storage == null) return;

    try {
      final ref = storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Storage Delete Error: $e');
    }
  }
}
