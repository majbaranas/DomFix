import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Service for uploading media files to Firebase Storage
/// Handles audio, images, and files with progress tracking
class MediaUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload audio file to Firebase Storage
  /// Returns download URL
  Future<String> uploadAudio({
    required File audioFile,
    required String chatId,
    required String messageId,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('[MediaUpload] 🎤 Uploading audio...');
      debugPrint('[MediaUpload] Chat ID: $chatId');
      debugPrint('[MediaUpload] Message ID: $messageId');

      final fileName = '$messageId.aac';
      final ref = _storage.ref().child('chats/$chatId/audio/$fileName');

      final uploadTask = ref.putFile(audioFile);

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('[MediaUpload] 📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('[MediaUpload] ✅ Audio uploaded successfully');
      debugPrint('[MediaUpload] URL: $downloadUrl');

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('[MediaUpload] ❌ Error uploading audio: $e');
      debugPrint('[MediaUpload] StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Upload image file to Firebase Storage
  /// Returns download URL
  Future<String> uploadImage({
    required File imageFile,
    required String chatId,
    required String messageId,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('[MediaUpload] 🖼️ Uploading image...');
      debugPrint('[MediaUpload] Chat ID: $chatId');
      debugPrint('[MediaUpload] Message ID: $messageId');

      final extension = path.extension(imageFile.path);
      final fileName = '$messageId$extension';
      final ref = _storage.ref().child('chats/$chatId/images/$fileName');

      final uploadTask = ref.putFile(imageFile);

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('[MediaUpload] 📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('[MediaUpload] ✅ Image uploaded successfully');
      debugPrint('[MediaUpload] URL: $downloadUrl');

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('[MediaUpload] ❌ Error uploading image: $e');
      debugPrint('[MediaUpload] StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Upload file to Firebase Storage
  /// Returns download URL
  Future<String> uploadFile({
    required File file,
    required String chatId,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('[MediaUpload] 📎 Uploading file...');
      debugPrint('[MediaUpload] Chat ID: $chatId');
      debugPrint('[MediaUpload] File name: $fileName');

      final ref = _storage.ref().child('chats/$chatId/files/$fileName');

      final uploadTask = ref.putFile(file);

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('[MediaUpload] 📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('[MediaUpload] ✅ File uploaded successfully');
      debugPrint('[MediaUpload] URL: $downloadUrl');

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('[MediaUpload] ❌ Error uploading file: $e');
      debugPrint('[MediaUpload] StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Delete file from Firebase Storage
  Future<void> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
      debugPrint('[MediaUpload] ✅ File deleted: $fileUrl');
    } catch (e) {
      debugPrint('[MediaUpload] ❌ Error deleting file: $e');
      rethrow;
    }
  }
}
