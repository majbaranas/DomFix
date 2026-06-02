import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// AI Home Diagnostician chat screen.
///
/// Opened via Navigator.push — back navigation is handled by the system.
/// No bottom nav bar: this is a full-screen modal pushed on top of the shell.
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with SingleTickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _messages = <_ChatMessage>[];
  bool _isTyping = false;
  late AnimationController _typingCtrl;

  // Suggestions shown before the user sends a message
  static const _suggestions = [
    'My ceiling has a damp patch',
    'Air conditioner is not cooling',
    'Strange noise from the pipes',
    'Power outlet stopped working',
  ];

  @override
  void initState() {
    super.initState();
    _typingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _addWelcome();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingCtrl.dispose();
    super.dispose();
  }

  void _addWelcome() {
    setState(() {
      _messages.add(_ChatMessage(
        text:
            "Hi! I'm your DomFix AI Diagnostician. Describe a home issue or ask a question — I'll help you identify the cause and connect you with the right professional.",
        isUser: false,
        timestamp: _now(),
      ));
    });
  }

  void _sendMessage([String? prefill]) {
    final text = (prefill ?? _messageController.text).trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, timestamp: _now()));
      _messageController.clear();
      _isTyping = true;
    });
    _scrollToBottom();
    _simulateReply(text);
  }

  void _simulateReply(String userText) {
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          text: _generateReply(userText),
          isUser: false,
          timestamp: _now(),
          proTip: _pickProTip(userText),
        ));
      });
      _scrollToBottom();
    });
  }

  String _generateReply(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('damp') || lower.contains('leak') || lower.contains('water')) {
      return 'A damp patch on the ceiling is usually caused by a slow pipe leak or roof penetration issue. Check whether the affected area is directly below a bathroom or the roof. A plumber or roofer should inspect it as soon as possible to prevent structural damage.';
    }
    if (lower.contains('ac') ||
        lower.contains('air') ||
        lower.contains('cool')) {
      return 'Reduced cooling is often caused by a clogged air filter, low refrigerant level, or a dirty condenser coil. Start by replacing the air filter — if the issue persists, an HVAC technician should inspect the refrigerant charge and coil condition.';
    }
    if (lower.contains('noise') ||
        lower.contains('pipe') ||
        lower.contains('plumb')) {
      return 'Banging or rattling pipes are often caused by water hammer (sudden pressure changes) or loose pipe brackets. Gurgling sounds may indicate a partial blockage. A licensed plumber can diagnose and resolve this quickly.';
    }
    if (lower.contains('electric') ||
        lower.contains('outlet') ||
        lower.contains('power') ||
        lower.contains('light')) {
      return 'A non-working outlet may have tripped its GFCI protection — check for a nearby GFCI outlet with a "Reset" button and press it. If that doesn\'t help, the circuit breaker may have tripped. Do not attempt to open the outlet yourself; contact a certified electrician.';
    }
    return 'Thank you for describing the issue. Based on what you\'ve shared, I recommend having a certified technician assess it in person for an accurate diagnosis. Would you like me to help you find the right professional?';
  }

  String? _pickProTip(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('damp') || lower.contains('leak')) {
      return 'Take a photo of the affected area and note whether it gets worse after rain or after using taps upstairs.';
    }
    if (lower.contains('ac') || lower.contains('cool')) {
      return 'Check that all vents are open and unblocked before calling a technician — this fixes ~20% of AC issues.';
    }
    if (lower.contains('electric') || lower.contains('outlet')) {
      return 'Never use a damaged outlet. Switch off the circuit breaker for that room until a technician arrives.';
    }
    return null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _now() {
    final t = DateTime.now();
    final h = t.hour == 0
        ? 12
        : t.hour > 12
            ? t.hour - 12
            : t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  bool get _isFirstMessage => _messages.length == 1;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Top bar ─────────────────────────────────────────
          _buildTopBar(top, user),
          // ── Chat list ───────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: _focusNode.unfocus,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(16, 12, 16,
                    _isFirstMessage ? 8 : 20),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _messages.length && _isTyping) {
                    return _TypingBubble(controller: _typingCtrl);
                  }
                  return _buildBubble(_messages[i]);
                },
              ),
            ),
          ),
          // ── Suggestions (only before first user message) ────
          if (_isFirstMessage) _buildSuggestions(),
          // ── Input bar ───────────────────────────────────────
          _buildInputBar(bottom),
        ],
      ),
    );
  }

  // ─── Top bar ───────────────────────────────────────────────
  Widget _buildTopBar(double topPad, User? user) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, topPad + 8, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.75),
            border: Border(
              bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: AppColors.onSurface),
                ),
              ),
              const SizedBox(width: 4),
              // AI avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E2A14), Color(0xFF2B3D00)],
                  ),
                  border: Border.all(
                    color: AppColors.neonAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    size: 18, color: AppColors.neonAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'AI Diagnostician',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Ready for analysis',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // User avatar (decorative, non-interactive)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHigh,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: ClipOval(
                  child: user?.photoURL?.isNotEmpty == true
                      ? Image.network(
                          user!.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _userInitial(user),
                        )
                      : _userInitial(user),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userInitial(User? user) {
    final displayName = user?.displayName?.trim();
    final email = user?.email?.trim();
    final letter = (displayName?.isNotEmpty == true
            ? displayName!
            : email?.isNotEmpty == true
                ? email!
                : 'U')[0]
        .toUpperCase();
    return Container(
      color: AppColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.neonAccent,
        ),
      ),
    );
  }

  // ─── Chat bubble ───────────────────────────────────────────
  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E2A14), Color(0xFF2B3D00)],
                    ),
                    border: Border.all(
                        color: AppColors.neonAccent.withValues(alpha: 0.35)),
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 14, color: AppColors.neonAccent),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  constraints: BoxConstraints(
                    maxWidth:
                        MediaQuery.sizeOf(context).width * 0.78,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.neonAccent.withValues(alpha: 0.12)
                        : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: Border.all(
                      color: isUser
                          ? AppColors.neonAccent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Pro tip
          if (msg.proTip != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: _ProTipCard(tip: msg.proTip!),
            ),
          ],
          // Timestamp
          Padding(
            padding: EdgeInsets.only(
                top: 5, left: isUser ? 0 : 36, right: 0),
            child: Text(
              isUser ? 'You • ${msg.timestamp}' : 'AI • ${msg.timestamp}',
              style: GoogleFonts.inter(
                fontSize: 10,
                letterSpacing: 0.5,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Suggestion chips ──────────────────────────────────────
  Widget _buildSuggestions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _suggestions
            .map(
              (s) => GestureDetector(
                onTap: () => _sendMessage(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─── Input bar ─────────────────────────────────────────────
  Widget _buildInputBar(double bottomPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurface,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe your issue…',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (_, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? _sendMessage : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: hasText
                        ? AppColors.neonAccent
                        : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: hasText
                        ? [
                            BoxShadow(
                              color: AppColors.neonAccent
                                  .withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: hasText
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Pro tip card ────────────────────────────────────────────
class _ProTipCard extends StatelessWidget {
  const _ProTipCard({required this.tip});
  final String tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.neonAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.neonAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: AppColors.neonAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Tip',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.neonAccent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tip,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
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
}

// ─── Typing indicator ────────────────────────────────────────
class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2A14), Color(0xFF2B3D00)],
              ),
              border: Border.all(
                  color: AppColors.neonAccent.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppColors.neonAccent),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: AnimatedBuilder(
              animation: controller,
              builder: (_, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final v = (controller.value + i * 0.2) % 1.0;
                    final opacity = v < 0.5 ? v * 2 : (1 - v) * 2;
                    return Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 3),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.neonAccent
                            .withValues(alpha: 0.3 + opacity * 0.7),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data model ──────────────────────────────────────────────
class _ChatMessage {
  final String text;
  final bool isUser;
  final String timestamp;
  final String? proTip;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.proTip,
  });
}
