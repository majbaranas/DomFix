import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              _buildAnimation(),
              const Spacer(flex: 1),
              _buildContent(),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    return SizedBox(
      height: 250,
      child: Center(
        child: Lottie.asset(
          'assets/images/Live chatbot.json',
          fit: BoxFit.contain,
          repeat: true,
          animate: true,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 250,
              alignment: Alignment.center,
              child: Icon(
                Icons.psychology_outlined,
                size: 100,
                color: AppColors.primaryContainer,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            children: [
              const TextSpan(text: 'AI-Powered '),
              TextSpan(
                text: 'Diagnosis',
                style: TextStyle(color: AppColors.primaryContainer),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Describe your home issue and let our intelligence find the fix.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
