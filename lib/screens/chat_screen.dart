import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_colors.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_service.dart';
import '../models/message_model.dart';
import '../widgets/audio_recorder_widget.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/image_message_widget.dart';
import '../widgets/file_message_widget.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserRole;
  const ChatScreen({super.key, required this.otherUserId, required this.otherUserName, this.otherUserRole});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _imagePicker = ImagePicker();

  late String _chatId;
  late Stream<List<MessageModel>> _messagesStream;
  bool _isSending = false;
  bool _isRecording = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    final currentUserId = _chatService.currentUserId;
    final otherUserId = widget.otherUserId;
    if (currentUserId.isEmpty || otherUserId.isEmpty) return;
    _chatId = ChatService.generateChatId(currentUserId, otherUserId);
    _messagesStream = _chatService.getMessagesStream(_chatId);
    _messageController.addListener(() { setState(() {}); });
    _markMessagesAsSeenAndResetCount();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _chatService.diagnosticChatAccess(_chatId);
    });
  }

  @override
  void dispose() { _messageController.dispose(); _scrollController.dispose(); super.dispose(); }

  Future<void> _markMessagesAsSeenAndResetCount() async {
    try {
      await _chatService.markMessagesAsSeen(chatId: _chatId, otherUserId: widget.otherUserId);
      await _chatService.resetUnreadCount(_chatId);
    } catch (e) { debugPrint('[ChatScreen] Error marking seen: $e'); }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;
    final messageText = _messageController.text.trim();
    _messageController.clear();
    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(receiverId: widget.otherUserId, text: messageText);
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e'), backgroundColor: AppColors.error));
      _messageController.text = messageText;
    } finally { if (mounted) setState(() => _isSending = false); }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildChatArea()),
          _buildInputSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 4, 8, 10),
      decoration: BoxDecoration(color: AppColors.background, border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: AppColors.onSurface, size: 22)),
          const SizedBox(width: 4),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
            child: Icon(widget.otherUserRole == 'technician' ? Icons.engineering_rounded : Icons.person_rounded, color: AppColors.onSurfaceVariant, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUserName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                if (widget.otherUserRole != null)
                  Text(widget.otherUserRole!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return StreamBuilder<List<MessageModel>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: AppColors.neonAccent));
        if (snapshot.hasError) return Center(child: Text('Error loading messages', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)));
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline_rounded, color: AppColors.onSurfaceVariant.withValues(alpha: 0.2), size: 48),
            const SizedBox(height: 12),
            Text('No messages yet', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5))),
            const SizedBox(height: 4),
            Text('Start the conversation!', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3))),
          ]));
        }
        final messages = snapshot.data!;
        return ListView.builder(
          controller: _scrollController, reverse: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isCurrentUser = message.isFromUser(_chatService.currentUserId);
            return _buildMessageBubble(message, isCurrentUser);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isCurrentUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrentUser ? AppColors.neonAccent.withValues(alpha: 0.15) : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
              ),
              border: isCurrentUser ? Border.all(color: AppColors.neonAccent.withValues(alpha: 0.2)) : null,
            ),
            child: _buildMessageContent(message),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message.getFormattedTime(), style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4))),
              if (isCurrentUser) ...[
                const SizedBox(width: 4),
                Icon(Icons.done_all, size: 13, color: message.isSeen ? const Color(0xFF007AFF) : AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message) {
    switch (message.type) {
      case 'text': return Text(message.text ?? '', style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: AppColors.onSurface));
      case 'audio': return AudioPlayerWidget(audioUrl: message.mediaUrl ?? '', duration: message.duration, isCurrentUser: message.isFromUser(_chatService.currentUserId));
      case 'image': return ImageMessageWidget(imageUrl: message.mediaUrl ?? '', isCurrentUser: message.isFromUser(_chatService.currentUserId));
      case 'file': return FileMessageWidget(fileUrl: message.mediaUrl ?? '', fileName: message.fileName ?? 'File', isCurrentUser: message.isFromUser(_chatService.currentUserId));
      default: return Text('Unsupported message', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.onSurfaceVariant));
    }
  }

  Widget _buildInputSection() {
    if (_isRecording) return Padding(padding: const EdgeInsets.all(12), child: AudioRecorderWidget(onAudioRecorded: _handleAudioRecorded, onCancel: () => setState(() => _isRecording = false)));
    if (_isUploading) return Container(
      margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        CircularProgressIndicator(value: _uploadProgress, color: AppColors.neonAccent, strokeWidth: 2),
        const SizedBox(width: 12),
        Text('Uploading... ${(_uploadProgress * 100).toInt()}%', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface)),
      ]),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          GestureDetector(onTap: _showMediaOptions, child: Icon(Icons.add_circle_outline_rounded, color: AppColors.onSurfaceVariant, size: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Type a message...', hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
                  border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                maxLines: null, textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _messageController.text.trim().isEmpty ? () => setState(() => _isRecording = true) : (_isSending ? null : _sendMessage),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.neonAccent, borderRadius: BorderRadius.circular(20)),
              child: Icon(_messageController.text.trim().isEmpty ? Icons.mic_rounded : Icons.send_rounded, color: AppColors.onPrimary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaOptions() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _mediaOption(Icons.photo_library_rounded, 'Photo', Colors.purple, () { Navigator.pop(context); _pickImage(); }),
        const SizedBox(height: 8),
        _mediaOption(Icons.camera_alt_rounded, 'Camera', Colors.blue, () { Navigator.pop(context); _takePhoto(); }),
        const SizedBox(height: 8),
        _mediaOption(Icons.insert_drive_file_rounded, 'File', Colors.orange, () { Navigator.pop(context); _pickFile(); }),
      ]),
    ));
  }

  Widget _mediaOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 14),
        Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
      ]),
    ));
  }

  // ─── Media handlers (logic unchanged) ─────────────────
  Future<void> _handleAudioRecorded(File audioFile, int duration) async {
    setState(() { _isRecording = false; _isUploading = true; _uploadProgress = 0.0; });
    try {
      if (!await audioFile.exists()) throw Exception('Audio file does not exist');
      if (await audioFile.length() == 0) throw Exception('Audio file is empty');
      final audioUrl = await _cloudinaryService.uploadAudio(chatId: _chatId, audioFile: audioFile);
      await _chatService.sendMediaMessage(receiverId: widget.otherUserId, type: 'audio', mediaUrl: audioUrl, duration: duration);
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send audio: $e'), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _isUploading = false); }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) await _sendImageMessage(File(image.path), image.name);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (photo != null) await _sendImageMessage(File(photo.path), photo.name);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'zip']);
      if (result != null && result.files.single.path != null) await _sendFileMessage(File(result.files.single.path!), result.files.single.name);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); }
  }

  Future<void> _sendImageMessage(File imageFile, String fileName) async {
    setState(() { _isUploading = true; _uploadProgress = 0.0; });
    try {
      if (!await imageFile.exists()) throw Exception('Image file does not exist');
      final imageUrl = await _cloudinaryService.uploadImage(chatId: _chatId, imageFile: imageFile, compress: true);
      await _chatService.sendMediaMessage(receiverId: widget.otherUserId, type: 'image', mediaUrl: imageUrl, fileName: fileName);
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send image: $e'), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _isUploading = false); }
  }

  Future<void> _sendFileMessage(File file, String fileName) async {
    setState(() { _isUploading = true; _uploadProgress = 0.0; });
    try {
      if (!await file.exists()) throw Exception('File does not exist');
      final fileUrl = await _cloudinaryService.uploadFile(chatId: _chatId, file: file, fileName: fileName);
      await _chatService.sendMediaMessage(receiverId: widget.otherUserId, type: 'file', mediaUrl: fileUrl, fileName: fileName);
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send file: $e'), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _isUploading = false); }
  }
}
