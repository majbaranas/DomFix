import 'package:cloud_firestore/cloud_firestore.dart';

/// Message model for chat messages
/// Supports text, audio, image, video, and file message types
/// Uses Cloudinary for media storage
class MessageModel {
  final String id;
  final String senderId;
  final String type; // "text", "audio", "image", "video", "file"
  final String? text;
  final String? mediaUrl; // Cloudinary URL for all media types
  final String? fileName; // Original file name
  final int? duration; // Audio/video duration in seconds
  final DateTime createdAt;
  final bool isSeen;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaUrl,
    this.fileName,
    this.duration,
    required this.createdAt,
    this.isSeen = false,
  });

  /// Create MessageModel from Firestore document
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      type: data['type'] ?? 'text',
      text: data['text'],
      mediaUrl: data['mediaUrl'],
      fileName: data['fileName'],
      duration: data['duration'] as int?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSeen: data['isSeen'] ?? false,
    );
  }

  /// Convert MessageModel to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'type': type,
      'text': text,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'duration': duration,
      'createdAt': FieldValue.serverTimestamp(),
      'isSeen': isSeen,
    };
  }

  /// Check if message is from current user
  bool isFromUser(String currentUserId) {
    return senderId == currentUserId;
  }

  /// Get formatted time (e.g., "09:41 AM")
  String getFormattedTime() {
    final hour = createdAt.hour > 12 ? createdAt.hour - 12 : (createdAt.hour == 0 ? 12 : createdAt.hour);
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Get formatted duration for audio/video messages
  String getFormattedDuration() {
    if (duration == null) return '0:00';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get file extension from fileName
  String? getFileExtension() {
    if (fileName == null) return null;
    final parts = fileName!.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : null;
  }

  /// Check if message has media
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
}
