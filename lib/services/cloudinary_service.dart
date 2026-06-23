import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:crypto/crypto.dart';

/// Cloudinary service for uploading media files
/// Handles images, audio, video, and files
/// Uses SIGNED uploads (no preset required)
class CloudinaryService {
  static const String _cloudName = 'dmksbfd7h';
  static const String _apiKey = '834875583628169';
  static const String _apiSecret = 'IlQroLgR-jmGzC4WC6l-Vgj9gQ0';
  static const String _uploadPreset = 'chat_upload';
  
  // Upload endpoints
  static const String _imageUploadUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';
  static const String _videoUploadUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/video/upload';
  static const String _rawUploadUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/raw/upload';
  
  // File size limits (in bytes)
  static const int _maxImageSize = 10 * 1024 * 1024; // 10 MB
  static const int _maxAudioSize = 20 * 1024 * 1024; // 20 MB
  static const int _maxVideoSize = 100 * 1024 * 1024; // 100 MB
  static const int _maxFileSize = 50 * 1024 * 1024; // 50 MB

  /// Upload image to Cloudinary
  /// Returns secure URL
  Future<String> uploadImage({
    required File imageFile,
    required String chatId,
    bool compress = true,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] 📷 IMAGE UPLOAD STARTED');
      debugPrint('[Cloudinary] Chat ID: $chatId');
      debugPrint('[Cloudinary] File path: ${imageFile.path}');
      
      // Verify file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }
      
      File fileToUpload = imageFile;
      
      // Compress image if needed
      if (compress) {
        debugPrint('[Cloudinary] Compressing image...');
        final compressedFile = await _compressImage(imageFile);
        if (compressedFile != null) {
          fileToUpload = compressedFile;
          final originalSize = await imageFile.length();
          final compressedSize = await compressedFile.length();
          debugPrint('[Cloudinary] Original: ${originalSize} bytes');
          debugPrint('[Cloudinary] Compressed: ${compressedSize} bytes');
        }
      }
      
      // Check file size
      final fileSize = await fileToUpload.length();
      debugPrint('[Cloudinary] File size: $fileSize bytes');
      
      if (fileSize > _maxImageSize) {
        throw Exception('Image size exceeds ${_maxImageSize ~/ (1024 * 1024)} MB limit');
      }
      
      // Upload to Cloudinary
      final url = await _uploadToCloudinary(
        file: fileToUpload,
        uploadUrl: _imageUploadUrl,
        folder: 'chat_images/$chatId',
        resourceType: 'image',
        onProgress: onProgress,
      );
      
      debugPrint('[Cloudinary] ✅ SUCCESS!');
      debugPrint('[Cloudinary] URL: $url');
      debugPrint('═══════════════════════════════════════');
      
      return url;
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] ❌ IMAGE UPLOAD FAILED');
      debugPrint('[Cloudinary] Error: $e');
      debugPrint('[Cloudinary] StackTrace: $stackTrace');
      debugPrint('═══════════════════════════════════════');
      rethrow;
    }
  }

  /// Upload audio to Cloudinary
  /// Returns secure URL
  Future<String> uploadAudio({
    required File audioFile,
    required String chatId,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] 🎤 AUDIO UPLOAD STARTED');
      debugPrint('[Cloudinary] Chat ID: $chatId');
      debugPrint('[Cloudinary] File path: ${audioFile.path}');
      
      // Verify file exists
      if (!await audioFile.exists()) {
        throw Exception('Audio file does not exist');
      }
      
      // Check file size
      final fileSize = await audioFile.length();
      debugPrint('[Cloudinary] File size: $fileSize bytes');
      
      if (fileSize > _maxAudioSize) {
        throw Exception('Audio size exceeds ${_maxAudioSize ~/ (1024 * 1024)} MB limit');
      }
      
      // Upload to Cloudinary
      final url = await _uploadToCloudinary(
        file: audioFile,
        uploadUrl: _videoUploadUrl, // Audio uses video endpoint
        folder: 'chat_audio/$chatId',
        resourceType: 'video',
        onProgress: onProgress,
      );
      
      debugPrint('[Cloudinary] ✅ SUCCESS!');
      debugPrint('[Cloudinary] URL: $url');
      debugPrint('═══════════════════════════════════════');
      
      return url;
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] ❌ AUDIO UPLOAD FAILED');
      debugPrint('[Cloudinary] Error: $e');
      debugPrint('[Cloudinary] StackTrace: $stackTrace');
      debugPrint('═══════════════════════════════════════');
      rethrow;
    }
  }

  /// Upload video to Cloudinary
  /// Returns secure URL
  Future<String> uploadVideo({
    required File videoFile,
    required String chatId,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] 🎥 VIDEO UPLOAD STARTED');
      debugPrint('[Cloudinary] Chat ID: $chatId');
      debugPrint('[Cloudinary] File path: ${videoFile.path}');
      
      // Verify file exists
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist');
      }
      
      // Check file size
      final fileSize = await videoFile.length();
      debugPrint('[Cloudinary] File size: $fileSize bytes');
      
      if (fileSize > _maxVideoSize) {
        throw Exception('Video size exceeds ${_maxVideoSize ~/ (1024 * 1024)} MB limit');
      }
      
      // Upload to Cloudinary
      final url = await _uploadToCloudinary(
        file: videoFile,
        uploadUrl: _videoUploadUrl,
        folder: 'chat_videos/$chatId',
        resourceType: 'video',
        onProgress: onProgress,
      );
      
      debugPrint('[Cloudinary] ✅ SUCCESS!');
      debugPrint('[Cloudinary] URL: $url');
      debugPrint('═══════════════════════════════════════');
      
      return url;
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] ❌ VIDEO UPLOAD FAILED');
      debugPrint('[Cloudinary] Error: $e');
      debugPrint('[Cloudinary] StackTrace: $stackTrace');
      debugPrint('═══════════════════════════════════════');
      rethrow;
    }
  }

  /// Upload file (PDF, DOC, etc.) to Cloudinary
  /// Returns secure URL
  Future<String> uploadFile({
    required File file,
    required String chatId,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] 📎 FILE UPLOAD STARTED');
      debugPrint('[Cloudinary] Chat ID: $chatId');
      debugPrint('[Cloudinary] File name: $fileName');
      debugPrint('[Cloudinary] File path: ${file.path}');
      
      // Verify file exists
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }
      
      // Check file size
      final fileSize = await file.length();
      debugPrint('[Cloudinary] File size: $fileSize bytes');
      
      if (fileSize > _maxFileSize) {
        throw Exception('File size exceeds ${_maxFileSize ~/ (1024 * 1024)} MB limit');
      }
      
      // Upload to Cloudinary
      final url = await _uploadToCloudinary(
        file: file,
        uploadUrl: _rawUploadUrl,
        folder: 'chat_files/$chatId',
        resourceType: 'raw',
        publicId: fileName,
        onProgress: onProgress,
      );
      
      debugPrint('[Cloudinary] ✅ SUCCESS!');
      debugPrint('[Cloudinary] URL: $url');
      debugPrint('═══════════════════════════════════════');
      
      return url;
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] ❌ FILE UPLOAD FAILED');
      debugPrint('[Cloudinary] Error: $e');
      debugPrint('[Cloudinary] StackTrace: $stackTrace');
      debugPrint('═══════════════════════════════════════');
      rethrow;
    }
  }

  /// Upload a booking image to Cloudinary
  Future<String> uploadBookingImage({
    required String bookingId,
    required File imageFile,
    bool compress = true,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] 🧾 BOOKING IMAGE UPLOAD STARTED');
      debugPrint('[Cloudinary] Booking ID: $bookingId');
      debugPrint('[Cloudinary] File path: ${imageFile.path}');
      
      // Verify file exists
      if (!await imageFile.exists()) {
        throw Exception('Booking image file does not exist');
      }
      
      File fileToUpload = imageFile;
      
      // Compress image if needed
      if (compress) {
        debugPrint('[Cloudinary] Compressing image...');
        final compressedFile = await _compressImage(imageFile);
        if (compressedFile != null) {
          fileToUpload = compressedFile;
          final originalSize = await imageFile.length();
          final compressedSize = await compressedFile.length();
          debugPrint('[Cloudinary] Original: ${originalSize} bytes');
          debugPrint('[Cloudinary] Compressed: ${compressedSize} bytes');
        }
      }
      
      // Check file size
      final fileSize = await fileToUpload.length();
      debugPrint('[Cloudinary] File size: $fileSize bytes');
      
      if (fileSize > _maxImageSize) {
        throw Exception('Image size exceeds ${_maxImageSize ~/ (1024 * 1024)} MB limit');
      }
      
      // Upload to Cloudinary
      final url = await _uploadToCloudinary(
        file: fileToUpload,
        uploadUrl: _imageUploadUrl,
        folder: 'booking_images/$bookingId',
        resourceType: 'image',
        onProgress: onProgress,
      );
      
      debugPrint('[Cloudinary] ✅ SUCCESS!');
      debugPrint('[Cloudinary] URL: $url');
      debugPrint('═══════════════════════════════════════');
      
      return url;
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] ❌ BOOKING IMAGE UPLOAD FAILED');
      debugPrint('[Cloudinary] Error: $e');
      debugPrint('[Cloudinary] StackTrace: $stackTrace');
      debugPrint('═══════════════════════════════════════');
      rethrow;
    }
  }

  /// Upload a user profile photo to Cloudinary
  Future<String> uploadProfilePhoto({
    required String uid,
    required File imageFile,
    bool compress = true,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] 👤 PROFILE PHOTO UPLOAD STARTED');
      debugPrint('[Cloudinary] UID: $uid');
      
      if (!await imageFile.exists()) {
        throw Exception('Profile photo file does not exist');
      }
      
      File fileToUpload = imageFile;
      
      if (compress) {
        final compressedFile = await _compressImage(imageFile);
        if (compressedFile != null) fileToUpload = compressedFile;
      }
      
      final fileSize = await fileToUpload.length();
      if (fileSize > _maxImageSize) {
        throw Exception('Image size exceeds limit');
      }
      
      final url = await _uploadToCloudinary(
        file: fileToUpload,
        uploadUrl: _imageUploadUrl,
        folder: 'profile_photos/$uid',
        resourceType: 'image',
        onProgress: onProgress,
      );
      
      debugPrint('[Cloudinary] ✅ SUCCESS! URL: $url');
      debugPrint('═══════════════════════════════════════');
      return url;
    } catch (e) {
      debugPrint('[Cloudinary] ❌ PROFILE PHOTO UPLOAD FAILED: $e');
      rethrow;
    }
  }

  /// Upload a portfolio photo to Cloudinary
  Future<String> uploadPortfolioPhoto({
    required String uid,
    required File imageFile,
    bool compress = true,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[Cloudinary] 📸 PORTFOLIO PHOTO UPLOAD STARTED');
      debugPrint('[Cloudinary] UID: $uid');
      
      if (!await imageFile.exists()) {
        throw Exception('Portfolio photo file does not exist');
      }
      
      File fileToUpload = imageFile;
      
      if (compress) {
        final compressedFile = await _compressImage(imageFile);
        if (compressedFile != null) fileToUpload = compressedFile;
      }
      
      final fileSize = await fileToUpload.length();
      if (fileSize > _maxImageSize) {
        throw Exception('Image size exceeds limit');
      }
      
      final url = await _uploadToCloudinary(
        file: fileToUpload,
        uploadUrl: _imageUploadUrl,
        folder: 'portfolio_photos/$uid',
        resourceType: 'image',
        onProgress: onProgress,
      );
      
      debugPrint('[Cloudinary] ✅ SUCCESS! URL: $url');
      debugPrint('═══════════════════════════════════════');
      return url;
    } catch (e) {
      debugPrint('[Cloudinary] ❌ PORTFOLIO PHOTO UPLOAD FAILED: $e');
      rethrow;
    }
  }

  /// Core upload method to Cloudinary
  /// Uses SIGNED uploads (no preset required)
  Future<String> _uploadToCloudinary({
    required File file,
    required String uploadUrl,
    required String folder,
    required String resourceType,
    String? publicId,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('[Cloudinary] Preparing upload...');
      debugPrint('[Cloudinary] Upload URL: $uploadUrl');
      debugPrint('[Cloudinary] Folder: $folder');
      debugPrint('[Cloudinary] Resource type: $resourceType');
      
      // Generate timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Create parameters for signature
      final params = {
        'timestamp': timestamp.toString(),
        'folder': folder,
      };
      
      if (publicId != null) {
        params['public_id'] = publicId;
      }
      
      // Generate signature
      final signature = _generateSignature(params, _apiSecret);
      
      debugPrint('[Cloudinary] Using SIGNED upload');
      debugPrint('[Cloudinary] Timestamp: $timestamp');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      
      // Add file
      final fileBytes = await file.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: publicId ?? file.path.split('/').last,
      );
      request.files.add(multipartFile);
      
      // Add signed parameters
      request.fields['api_key'] = _apiKey;
      request.fields['timestamp'] = timestamp.toString();
      request.fields['signature'] = signature;
      request.fields['folder'] = folder;
      
      if (publicId != null) {
        request.fields['public_id'] = publicId;
      }
      
      debugPrint('[Cloudinary] Uploading ${fileBytes.length} bytes...');
      
      // Send request
      final streamedResponse = await request.send();
      
      // Track progress (simplified)
      if (onProgress != null) {
        onProgress(0.5); // 50% when upload starts
      }
      
      // Get response
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('[Cloudinary] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final secureUrl = jsonResponse['secure_url'] as String;
        
        if (onProgress != null) {
          onProgress(1.0); // 100% complete
        }
        
        debugPrint('[Cloudinary] Upload successful');
        return secureUrl;
      } else {
        debugPrint('[Cloudinary] Upload failed: ${response.body}');
        throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[Cloudinary] Upload error: $e');
      rethrow;
    }
  }
  
  /// Generate signature for signed uploads
  String _generateSignature(Map<String, String> params, String apiSecret) {
    // Sort parameters alphabetically
    final sortedKeys = params.keys.toList()..sort();
    
    // Create string to sign
    final stringToSign = sortedKeys
        .map((key) => '$key=${params[key]}')
        .join('&');
    
    // Add API secret
    final fullString = stringToSign + apiSecret;
    
    // Generate SHA-1 hash
    final bytes = utf8.encode(fullString);
    final digest = sha1.convert(bytes);
    
    return digest.toString();
  }

  /// Compress image to reduce file size
  Future<File?> _compressImage(File file) async {
    try {
      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf('.');
      final outPath = '${filePath.substring(0, lastIndex)}_compressed${filePath.substring(lastIndex)}';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );
      
      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint('[Cloudinary] Compression error: $e');
      return null;
    }
  }

  /// Get file size limits
  static Map<String, int> getFileSizeLimits() {
    return {
      'image': _maxImageSize,
      'audio': _maxAudioSize,
      'video': _maxVideoSize,
      'file': _maxFileSize,
    };
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
