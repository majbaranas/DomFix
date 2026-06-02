import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../widgets/logo_painter.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_navigation_service.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;

    // Check if first launch (for app onboarding)
    final isFirstLaunch = await LocalStorageService.isFirstLaunch();
    
    if (isFirstLaunch) {
      // Show app onboarding first time
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // Check Firebase authentication status
    final user = FirebaseAuth.instance.currentUser;
    
    if (!mounted) return;

    if (user == null) {
      // Not logged in - go to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // Logged in - use Firebase navigation service
      await NavigationService.navigateBasedOnAuth(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildAmbientBackground(),
          _buildCornerDecorations(),
          _buildMainContent(),
          _buildBottomStatus(),
        ],
      ),
    );
  }

  Widget _buildAmbientBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.6 * _pulseAnimation.value,
                colors: [
                  AppColors.primaryContainer.withValues(alpha: 0.03),
                  AppColors.background.withValues(alpha: 0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLogo(),
          const SizedBox(height: 48),
          _buildBranding(),
          const SizedBox(height: 48),
          _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer
                          .withValues(alpha: 0.05 * _pulseAnimation.value),
                      blurRadius: 80,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              );
            },
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonAccent.withValues(alpha: 0.15),
                  blurRadius: 40,
                ),
              ],
            ),
            child: CustomPaint(
              painter: LogoPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        Text(
          'DOMFIX',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            letterSpacing: 6.8,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'INTELLIGENCE • CONTROL • TRUST',
          style: GoogleFonts.inter(
            fontSize: 10,
            letterSpacing: 4,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 192,
      height: 1,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 1,
            color: AppColors.surfaceContainerHighest,
          ),
          AnimatedBuilder(
            animation: _loadingAnimation,
            builder: (context, child) {
              return Positioned(
                left: (192 - 64) * _loadingAnimation.value - 32,
                child: Container(
                  width: 64,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryContainer.withValues(alpha: 0),
                        AppColors.primaryContainer,
                        AppColors.primaryContainer.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStatus() {
    return Positioned(
      bottom: 48,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Text(
            'INITIALIZING CORE PROTOCOLS',
            style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 4,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer.withValues(alpha: 0.2 + index * 0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerDecorations() {
    return Stack(
      children: [
        Positioned(
          top: 32,
          left: 32,
          child: _buildCorner(top: true, left: true),
        ),
        Positioned(
          top: 32,
          right: 32,
          child: _buildCorner(top: true, right: true),
        ),
        Positioned(
          bottom: 32,
          left: 32,
          child: _buildCorner(bottom: true, left: true),
        ),
        Positioned(
          bottom: 32,
          right: 32,
          child: _buildCorner(bottom: true, right: true),
        ),
      ],
    );
  }

  Widget _buildCorner({
    bool top = false,
    bool bottom = false,
    bool left = false,
    bool right = false,
  }) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? BorderSide(color: AppColors.onSurface.withValues(alpha: 0.1))
              : BorderSide.none,
          bottom: bottom
              ? BorderSide(color: AppColors.onSurface.withValues(alpha: 0.1))
              : BorderSide.none,
          left: left
              ? BorderSide(color: AppColors.onSurface.withValues(alpha: 0.1))
              : BorderSide.none,
          right: right
              ? BorderSide(color: AppColors.onSurface.withValues(alpha: 0.1))
              : BorderSide.none,
        ),
      ),
    );
  }
}
