import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/smart_device.dart';
import '../services/iot_service.dart';
import '../theme/app_colors.dart';

class AIChatScreenContent extends StatefulWidget {
  const AIChatScreenContent({super.key});

  @override
  State<AIChatScreenContent> createState() => _AIChatScreenContentState();
}

class _AIChatScreenContentState extends State<AIChatScreenContent>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  late AnimationController _typingAnimationController;
  StreamSubscription<List<SmartDevice>>? _iotSubscription;
  bool _hasWarnedTemp = false;
  bool _hasWarnedLight = false;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadInitialMessages();
    _listenToSmartHome();
  }
  
  void _listenToSmartHome() {
    // Disabled for simplified flow
  }

  void _addAiRecommendation(String text, String actionText, VoidCallback action) {
    if (!mounted) return;
    _simulateTyping();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: text,
          isUser: false,
          timestamp: _getCurrentTime(),
          hasProTip: true,
          proTipText: actionText,
          onProTipTap: action,
        ));
      });
      _scrollToBottom();
    });
  }

  Future<void> _turnOnDevice(List<SmartDevice> devices, SmartDeviceType type) async {
    final target = devices.where((d) => d.type == type).firstOrNull;
    if (target != null) {
      // await IoTService.instance.toggleDevice(target.id, true);
      setState(() {
        _messages.add(ChatMessage(
          text: "I have turned on the ${target.name} for you.",
          isUser: false,
          timestamp: _getCurrentTime(),
        ));
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _iotSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  void _loadInitialMessages() {
    setState(() {
      _messages.addAll([
        ChatMessage(
          text: "Hello! I'm your DomFix Diagnostician. You can describe a home issue or upload a photo, and I'll help you identify the cause and find the right pro.",
          isUser: false,
          timestamp: '09:41 AM',
        ),
        ChatMessage(
          text: "There's a damp spot appearing on my ceiling in the hallway. It's about the size of a dinner plate.",
          isUser: true,
          timestamp: '09:42 AM',
        ),
        ChatMessage(
          text: "Based on the size and location, this sounds like a potential slow leak from an upstairs pipe or a roof penetration issue. Could you please upload a photo of the spot?",
          isUser: false,
          timestamp: '09:42 AM',
          hasProTip: true,
          proTipText: 'Check if the spot feels soft or is actively dripping.',
        ),
        ChatMessage(
          text: '',
          isUser: true,
          timestamp: '09:42 AM',
          hasImage: true,
        ),
      ]);
    });
    _simulateTyping();
  }

  void _simulateTyping() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isTyping = true);
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: _messageController.text.trim(),
        isUser: true,
        timestamp: _getCurrentTime(),
      ));
      _messageController.clear();
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildTitle(),
          Expanded(
            child: _buildChatArea(),
          ),
          _buildInputSection(),
          const SizedBox(height: 80), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                child: ClipOval(
                  child: Icon(
                    Icons.person,
                    color: AppColors.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'DOMFIX',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppColors.primaryContainer,
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Text(
            'AI Home Diagnostician',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'SYSTEM READY FOR ANALYSIS',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: message.isUser
                  ? const Color(0xFF1A1F2B)
                  : const Color(0xFF2A3040),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft:
                    message.isUser ? const Radius.circular(16) : Radius.zero,
                bottomRight:
                    message.isUser ? Radius.zero : const Radius.circular(16),
              ),
              border: message.isUser
                  ? null
                  : Border(
                      left: BorderSide(
                        color: AppColors.primaryContainer,
                        width: 2,
                      ),
                    ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.onSurface,
                    ),
                  ),
                if (message.hasProTip) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: message.onProTipTap,
                    child: _buildProTipCard(message.proTipText),
                  ),
                ],
                if (message.hasImage) ...[
                  _buildImagePreview(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message.isUser
                ? 'YOU • ${message.timestamp}'
                : 'AI ASSISTANT • ${message.timestamp}',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProTipCard(String tipText) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.emergency_outlined,
              color: AppColors.primaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRO TIP',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tipText,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 200,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  color: AppColors.primaryContainer.withValues(alpha: 0.5),
                  size: 48,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.image,
                color: AppColors.background,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 20),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _typingAnimationController,
            builder: (context, child) {
              return Row(
                children: List.generate(3, (index) {
                  final delay = index * 0.2;
                  final value =
                      (_typingAnimationController.value + delay) % 1.0;
                  final opacity =
                      (value < 0.5 ? value * 2 : (1 - value) * 2);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer
                          .withValues(alpha: 0.3 + opacity * 0.7),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            'TYPING...',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildIconButton(Icons.add_circle_outline, () {}),
          const SizedBox(width: 4),
          _buildIconButton(Icons.photo_camera_outlined, () {}),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Describe your issue...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.send_rounded,
                color: AppColors.background,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          size: 24,
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String timestamp;
  final bool hasProTip;
  final String proTipText;
  final bool hasImage;
  final VoidCallback? onProTipTap;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.hasProTip = false,
    this.proTipText = '',
    this.hasImage = false,
    this.onProTipTap,
  });
}
