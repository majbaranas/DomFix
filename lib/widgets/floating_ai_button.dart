import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_colors.dart';
import '../screens/ai_chat_screen.dart';

class FloatingAIButton extends StatefulWidget {
  const FloatingAIButton({super.key});
  @override
  State<FloatingAIButton> createState() => _FloatingAIButtonState();
}

class _FloatingAIButtonState extends State<FloatingAIButton>
    with TickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 104,
      right: 24,
      child: AnimatedBuilder(
        animation: Listenable.merge([_floatCtrl, _glowCtrl]),
        builder: (context, child) {
          final floatY = sin(_floatCtrl.value * 2 * pi) * 6;
          final glowOpacity = 0.3 + (_glowCtrl.value * 0.2);
          final scale = 1.0 + (_glowCtrl.value * 0.02);

          return Transform.translate(
            offset: Offset(0, floatY),
            child: Transform.scale(
              scale: scale,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AIChatScreen()),
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF101419).withValues(alpha: 0.7),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppColors.primaryFixed.withValues(alpha: glowOpacity * 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: ClipOval(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Lottie.asset(
                              'assets/images/Welcome Animation.json',
                              fit: BoxFit.contain,
                              repeat: true,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text(
                            'AI',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF181E00),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
