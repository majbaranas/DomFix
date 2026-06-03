import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

/// Service for uploading files to Firebase Storage
class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload audio file to Firebase Storage
  /// Returns download URL
  Future<String> uploadAudio({
    required String chatId,
    required File audioFile,
  }) async {
    try {
      debugPrint('════════════════════════════════════════');
      debugPrint('[UPLOAD] 🎤 AUDIO UPLOAD STARTED');
      debugPrint('[UPLOAD] Chat ID: $chatId');
      debugPrint('[UPLOAD] File path: ${audioFile.path}');

      if (!await audioFile.exists()) {
        debugPrint('[UPLOAD] ❌ ERROR: Audio file does not exist!');
        throw Exception('Audio file does not exist at path: ${audioFile.path}');
      }

      final fileSize = await audioFile.length();
      debugPrint('[UPLOAD] File size: $fileSize bytes');

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
      final storagePath = 'chats/$chatId/audio/$fileName';
      final ref = _storage.ref().child(storagePath);

      debugPrint('[UPLOAD] Storage path: $storagePath');
      debugPrint('[UPLOAD] Starting upload...');

      final uploadTask = await ref.putFile(audioFile);
      debugPrint('[UPLOAD] ✅ Upload completed');
      debugPrint('[UPLOAD] State: ${uploadTask.state}');

      debugPrint('[UPLOAD] Getting download URL...');
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      debugPrint('[UPLOAD] ✅ SUCCESS!');
      debugPrint('[UPLOAD] Download URL: $downloadUrl');
      debugPrint('════════════════════════════════════════');

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('════════════════════════════════════════');
      debugPrint('[UPLOAD] ❌ AUDIO UPLOAD FAILED');
      debugPrint('[UPLOAD] Error: $e');
      debugPrint('[UPLOAD] StackTrace: $stackTrace');
      debugPrint('════════════════════════════════════════');
      rethrow;
    }
  }

  /// Upload image file to Firebase Storage with compression
  /// Returns download URL
  Future<String> uploadImage({
    required String chatId,
    required File imageFile,
    bool compress = true,
  }) async {
    try {
      debugPrint('════════════════════════════════════════');
      debugPrint('[UPLOAD] 📷 IMAGE UPLOAD STARTED');
      debugPrint('[UPLOAD] Chat ID: $chatId');
      debugPrint('[UPLOAD] File path: ${imageFile.path}');

      if (!await imageFile.exists()) {
        debugPrint('[UPLOAD] ❌ ERROR: Image file does not exist!');
        throw Exception('Image file does not exist at path: ${imageFile.path}');
      }

      File fileToUpload = imageFile;

      if (compress) {
        debugPrint('[UPLOAD] Compressing image...');
        final compressedFile = await _compressImage(imageFile);
        if (compressedFile != null) {
          fileToUpload = compressedFile;
          final originalSize = await imageFile.length();
          final compressedSize = await compressedFile.length();
          debugPrint('[UPLOAD] Original size: $originalSize bytes');
          debugPrint('[UPLOAD] Compressed size: $compressedSize bytes');
          debugPrint('[UPLOAD] Saved: ${originalSize - compressedSize} bytes');
        }
      }

      final fileSize = await fileToUpload.length();
      debugPrint('[UPLOAD] File size: $fileSize bytes');

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final storagePath = 'chats/$chatId/images/$fileName';
      final ref = _storage.ref().child(storagePath);

      debugPrint('[UPLOAD] Storage path: $storagePath');
      debugPrint('[UPLOAD] Starting upload...');

      final uploadTask = await ref.putFile(fileToUpload);
      debugPrint('[UPLOAD] ✅ Upload completed');
      debugPrint('[UPLOAD] State: ${uploadTask.state}');

      debugPrint('[UPLOAD] Getting download URL...');
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      debugPrint('[UPLOAD] ✅ SUCCESS!');
      debugPrint('[UPLOAD] Download URL: $downloadUrl');
      debugPrint('════════════════════════════════════════');

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('════════════════════════════════════════');
      debugPrint('[UPLOAD] ❌ IMAGE UPLOAD FAILED');
      debugPrint('[UPLOAD] Error: $e');
      debugPrint('[UPLOAD] StackTrace: $stackTrace');
      debugPrint('════════════════════════════════════════');
      rethrow;
    }
  }

  /// Upload a booking image to Firebase Storage.
  Future<String> uploadBookingImage({
    required String bookingId,
    required File imageFile,
    bool compress = true,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('════════════════════════════════════════');
      debugPrint('[UPLOAD] 🧾 BOOKING IMAGE UPLOAD STARTED');
      debugPrint('[UPLOAD] Booking ID: $bookingId');
      debugPrint('[UPLOAD] File path: ${imageFile.path}');

      if (!await imageFile.exists()) {
        throw Exception('Booking image file does not exist');
      }

      File fileToUpload = imageFile;
      if (compress) {
        final compressedFile = await _compressImage(imageFile);
        if (compressedFile != null) {
          fileToUpload = compressedFile;
        }
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final ref = _storage.ref().child('bookings/$bookingId/images/$fileName');
      final uploadTask = ref.putFile(fileToUpload);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (onProgress == null) return;
        if (snapshot.totalBytes == 0) return;
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('[UPLOAD] ✅ Booking image uploaded: $downloadUrl');
      debugPrint('════════════════════════════════════════');
      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('════════════════════════════════════════');
      debugPrint('[UPLOAD] ❌ BOOKING IMAGE UPLOAD FAILED');
      debugPrint('[UPLOAD] Error: $e');
      debugPrint('[UPLOAD] StackTrace: $stackTrace');
      debugPrint('════════════════════════════════════════');
      rethrow;
    }
  }

  /// Upload file to Firebase Storage
  /// Returns download URL
  Future<String> uploadFile({
    required String chatId,
    required File file,
    required String fileName,
  }) async {
    try {
      debugPrint('════════════════════════════════════════');
      debugPrint('[UPLOAD] 📎 FILE UPLOAD STARTED');
      debugPrint('[UPLOAD] Chat ID: $chatId');
      debugPrint('[UPLOAD] File name: $fileName');
      debugPrint('[UPLOAD] File path: ${file.path}');

      if (!await file.exists()) {
        debugPrint('[UPLOAD] ❌ ERROR: File does not exist!');
        throw Exception('File does not exist at path: ${file.path}');
      }

      final fileSize = await file.length();
      debugPrint('[UPLOAD] File size: $fileSize bytes');

      final storagePath = 'chats/$chatId/files/$fileName';
      final ref = _storage.ref().child(storagePath);

      debugPrint('[UPLOAD] Storage path: $storagePath');
      debugPrint('[UPLOAD] Starting upload...');

      final uploadTask = await ref.putFile(file);
      debugPrint('[UPLOAD] ✅ Upload completed');
      debugPrint('[UPLOAD] State: ${uploadTask.state}');

      debugPrint('[UPLOAD] Getting download URL...');
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      debugPrint('[UPLOAD] ✅ SUCCESS!');
      debugPrint('[UPLOAD] Download URL: $downloadUrl');
      debugPrint('════════════════════════════════════════');

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('════════════════════════════════════════');
      debugPrint('[UPLOAD] ❌ FILE UPLOAD FAILED');
      debugPrint('[UPLOAD] Error: $e');
      debugPrint('[UPLOAD] StackTrace: $stackTrace');
      debugPrint('════════════════════════════════════════');
      rethrow;
    }
  }

  /// Upload with progress tracking
  Stream<double> uploadWithProgress({
    required String chatId,
    required File file,
    required String type, // 'audio', 'image', 'file'
    String? fileName,
  }) {
    final name =
        fileName ?? '${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';
    final ref = _storage.ref().child('chats/$chatId/$type/$name');

    final uploadTask = ref.putFile(file);

    return uploadTask.snapshotEvents.map((snapshot) {
      return snapshot.bytesTransferred / snapshot.totalBytes;
    });
  }

  /// Compress image to reduce file size
  Future<File?> _compressImage(File file) async {
    try {
      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf('.');
      final outPath =
          '${filePath.substring(0, lastIndex)}_compressed${filePath.substring(lastIndex)}';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint('[Storage] Error compressing image: $e');
      return null;
    }
  }
}
