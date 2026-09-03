import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

class StorageService {
  static final StorageService instance = StorageService._init();
  StorageService._init();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a file to Firebase Storage.
  /// [path] is the relative path in the bucket (e.g. 'products/123.jpg')
  Future<String?> uploadImage({
    required String path,
    required File imageFile,
    int? maxWidth, // Kept for API compatibility but ignored as we rely on native picker
  }) async {
    try {
      // Upload directly - UI should handle resizing via ImagePicker for better memory performance
      final ref = _storage.ref().child(path);
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
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Storage Delete Error: $e');
    }
  }
}
