import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../screens/ai_assistant_chat_screen.dart';

/// Premium floating AI orb that overlays the Dashboard.
///
/// Entirely self-contained — it manages its own animations,
/// position persistence, and navigation. It never triggers
/// rebuilds on the Dashboard widgets beneath it.
class PremiumAIAssistantOrb extends StatefulWidget {
  const PremiumAIAssistantOrb({super.key});

  @override
  State<PremiumAIAssistantOrb> createState() => _PremiumAIAssistantOrbState();
}

class _PremiumAIAssistantOrbState extends State<PremiumAIAssistantOrb>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────
  static const double _orbSize = 64.0;
  static const String _yPosKey = 'ai_orb_y_position';
  static const String _tooltipKey = 'has_seen_ai_tooltip';
  static const String _heroTag = 'domfix_ai_orb_hero';

  // ── Animation controllers ─────────────────────────────────
  late final AnimationController _breatheCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _breatheScale;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _floatOffset;
  late final Animation<double> _pulseGlow;

  // ── State ─────────────────────────────────────────────────
  double _yPosition = -1;
  bool _isDragging = false;
  bool _isInitialized = false;
  bool _showTooltip = false;

  @override
  void initState() {
    super.initState();

    // Slow breathing: scale 1.0 → 1.04 over 3s
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _breatheScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );

    _glowOpacity = Tween<double>(begin: 0.35, end: 0.65).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );

    // Tiny vertical float: ±1.5 px over 4s (different period = organic feel)
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    _floatOffset = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // Neon pulse: subtle glow burst every 5s
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();

    _pulseGlow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 70),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_pulseCtrl);

    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedY = prefs.getDouble(_yPosKey);
    final hasSeenTooltip = prefs.getBool(_tooltipKey) ?? false;

    if (!mounted) return;
    setState(() {
      _yPosition = savedY ?? -1;

      if (!hasSeenTooltip) {
        _showTooltip = true;
        prefs.setBool(_tooltipKey, true);
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showTooltip = false);
        });
      }

      _isInitialized = true;
    });
  }

  Future<void> _saveYPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_yPosKey, _yPosition);
  }

  // ── Tap → Navigate ────────────────────────────────────────
  void _handleTap() {
    if (_showTooltip) {
      setState(() => _showTooltip = false);
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const AiAssistantChatScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 24;

    // First build: default to lower-right
    if (_yPosition < 0) {
      _yPosition = screenHeight - bottomPad - _orbSize - 28;
    }

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      right: 20.0,
      top: _yPosition,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── First-launch tooltip ──────────────────────────
          if (_showTooltip) _buildTooltip(),

          // ── The Orb ──────────────────────────────────────
          GestureDetector(
            onVerticalDragStart: (_) {
              setState(() {
                _isDragging = true;
                if (_showTooltip) _showTooltip = false;
              });
            },
            onVerticalDragUpdate: (d) {
              setState(() {
                _yPosition += d.delta.dy;
                final minY = topPad + 20;
                final maxY = screenHeight - bottomPad - _orbSize;
                _yPosition = _yPosition.clamp(minY, maxY);
              });
            },
            onVerticalDragEnd: (_) {
              setState(() => _isDragging = false);
              _saveYPosition();
            },
            onTap: _handleTap,
            child: AnimatedBuilder(
              animation: Listenable.merge([_breatheCtrl, _floatCtrl, _pulseCtrl]),
              builder: (context, _) {
                final pulseExtra = _pulseGlow.value * 0.25;

                return Transform.translate(
                  offset: Offset(0, _floatOffset.value),
                  child: Transform.scale(
                    scale: _breatheScale.value,
                    child: Hero(
                      tag: _heroTag,
                      flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) {
                        return _buildOrbVisual(
                          glowOpacity: 0.5,
                          pulseExtra: 0,
                        );
                      },
                      child: _buildOrbVisual(
                        glowOpacity: _glowOpacity.value,
                        pulseExtra: pulseExtra,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Orb visual ──────────────────────────────────────────
  Widget _buildOrbVisual({
    required double glowOpacity,
    required double pulseExtra,
  }) {
    return Container(
      width: _orbSize,
      height: _orbSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // Primary neon glow
          BoxShadow(
            color: AppColors.neonAccent.withValues(alpha: glowOpacity * 0.6),
            blurRadius: 18 + (pulseExtra * 12),
            spreadRadius: 1 + (pulseExtra * 4),
          ),
          // Deep shadow for depth
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          // Inner-glow halo (subtle)
          BoxShadow(
            color: AppColors.neonAccent.withValues(alpha: 0.08 + pulseExtra * 0.1),
            blurRadius: 30,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surface.withValues(alpha: 0.65),
                  AppColors.surface.withValues(alpha: 0.35),
                ],
              ),
              border: Border.all(
                width: 1.5,
                color: AppColors.neonAccent.withValues(alpha: 0.30 + pulseExtra * 0.15),
              ),
            ),
            child: Center(
              child: ClipOval(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Lottie.asset(
                    'assets/images/Welcome Animation.json',
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tooltip ──────────────────────────────────────────────
  Widget _buildTooltip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (context, val, child) {
          return Transform.scale(
            scale: val,
            alignment: Alignment.bottomRight,
            child: Opacity(opacity: val, child: child),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(maxWidth: 220),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonAccent.withValues(alpha: 0.12),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(
                "👋 Hi! I'm DomFix AI.\nNeed help? Tap me anytime.",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
