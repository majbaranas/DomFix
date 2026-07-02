import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../services/ai_service.dart';
import '../theme/app_colors.dart';

/// Premium AI Assistant Chat Screen.
///
/// Displays a welcome home view with Lottie animation, context-aware greeting,
/// and quick suggestion chips. Once the user types or selects a suggestion,
/// it transitions into the live AI chat.
///
/// This screen owns its own AI conversation state and does NOT modify
/// any existing services, navigation, or backend logic.
class AiAssistantChatScreen extends StatefulWidget {
  /// Optional context hint so the greeting can adapt.
  /// Values: 'home', 'smart_home', 'booking', etc.
  final String contextHint;

  const AiAssistantChatScreen({super.key, this.contextHint = 'home'});

  @override
  State<AiAssistantChatScreen> createState() => _AiAssistantChatScreenState();
}

class _AiAssistantChatScreenState extends State<AiAssistantChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isStreaming = false;
  String _streamingText = '';

  late final AnimationController _fadeInCtrl;
  late final Animation<double> _fadeIn;

  final AiService _aiService = AiService();

  @override
  void initState() {
    super.initState();
    _fadeInCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeIn = CurvedAnimation(parent: _fadeInCtrl, curve: Curves.easeOut);

    _inputCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _fadeInCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    _aiService.cancelCurrentRequest();
    super.dispose();
  }

  // ── Context-aware greeting ──────────────────────────────
  String get _greeting {
    final hour = DateTime.now().hour;
    final timeGreet = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return '$timeGreet 👋';
  }

  String get _subtitle {
    switch (widget.contextHint) {
      case 'smart_home':
        return 'Need help controlling your devices?';
      case 'booking':
        return 'Need help understanding your quotation?';
      case 'find_pro':
        return 'Looking for the right technician?';
      default:
        return 'How can I help you today?';
    }
  }

  List<_QuickSuggestion> get _suggestions => const [
        _QuickSuggestion('🔧', 'Diagnose my problem'),
        _QuickSuggestion('👨‍🔧', 'Find a technician'),
        _QuickSuggestion('📦', 'Track my booking'),
        _QuickSuggestion('🏠', 'Control my Smart Home'),
        _QuickSuggestion('💡', 'Energy saving tips'),
      ];

  // ── Send message ────────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    _inputCtrl.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: trimmed));
      _isSending = true;
      _isStreaming = true;
      _streamingText = '';
    });
    _scrollToBottom();

    try {
      final conversationHistory = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => AiConversationTurn(role: m.role, content: m.text))
          .toList();

      final result = await _aiService.sendConversation(
        messages: conversationHistory,
        onStreamDelta: (partial) {
          if (mounted) {
            setState(() => _streamingText = partial);
            _scrollToBottom();
          }
        },
      );

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(role: 'assistant', text: result.reply));
          _isStreaming = false;
          _streamingText = '';
        });
        _scrollToBottom();
      }
    } on AiServiceException catch (e) {
      if (mounted && e.code != 'cancelled') {
        setState(() {
          _messages.add(_ChatMessage(
            role: 'assistant',
            text: "I'm having trouble connecting right now. Please try again in a moment.",
          ));
          _isStreaming = false;
          _streamingText = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            role: 'assistant',
            text: "Something went wrong. Please try again.",
          ));
          _isStreaming = false;
          _streamingText = '';
        });
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get _showWelcome => _messages.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _showWelcome ? _buildWelcomeView() : _buildChatView(),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────
  Widget _buildAppBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            8, MediaQuery.of(context).padding.top + 6, 16, 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
            border: Border(
              bottom: BorderSide(color: AppColors.divider),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.onSurface,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              // Small orb icon in app bar
              Hero(
                tag: 'domfix_ai_orb_hero',
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.neonAccent.withValues(alpha: 0.2),
                        AppColors.neonAccent.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.neonAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppColors.neonAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DomFix AI',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Online',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Welcome View ────────────────────────────────────────
  Widget _buildWelcomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Lottie welcome animation
          SizedBox(
            height: 180,
            child: Lottie.asset(
              'assets/images/Welcome Animation.json',
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
          const SizedBox(height: 24),
          // Greeting
          Text(
            _greeting,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          // Quick suggestions
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _suggestions.map((s) => _buildSuggestionChip(s)).toList(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(_QuickSuggestion suggestion) {
    return GestureDetector(
      onTap: () => _sendMessage(suggestion.label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(suggestion.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              suggestion.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat View ───────────────────────────────────────────
  Widget _buildChatView() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        // Streaming bubble
        if (_isStreaming && index == _messages.length) {
          return _buildBubble(
            _ChatMessage(role: 'assistant', text: _streamingText),
            isStreaming: true,
          );
        }
        return _buildBubble(_messages[index]);
      },
    );
  }

  Widget _buildBubble(_ChatMessage message, {bool isStreaming = false}) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // AI avatar
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonAccent.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.neonAccent.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: AppColors.neonAccent,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                border: isUser
                    ? Border.all(
                        color: AppColors.neonAccent.withValues(alpha: 0.15))
                    : Border.all(color: AppColors.divider),
              ),
              child: message.text.isEmpty && isStreaming
                  ? _buildTypingIndicator()
                  : Text(
                      message.text,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.onSurface,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600 + (i * 200)),
            builder: (context, val, child) {
              return Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.3 + val * 0.3),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  // ── Input Bar ───────────────────────────────────────────
  Widget _buildInputBar() {
    final hasText = _inputCtrl.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 10, 16, MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask DomFix AI anything…',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) {
                  if (hasText) _sendMessage(_inputCtrl.text);
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: hasText && !_isSending
                ? () => _sendMessage(_inputCtrl.text)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasText
                    ? AppColors.neonAccent
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: hasText
                    ? null
                    : Border.all(color: AppColors.divider),
              ),
              child: Icon(
                hasText ? Icons.arrow_upward_rounded : Icons.mic_rounded,
                color: hasText
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Internal models ─────────────────────────────────────────
class _ChatMessage {
  final String role;
  final String text;

  const _ChatMessage({required this.role, required this.text});
}

class _QuickSuggestion {
  final String emoji;
  final String label;

  const _QuickSuggestion(this.emoji, this.label);
}
