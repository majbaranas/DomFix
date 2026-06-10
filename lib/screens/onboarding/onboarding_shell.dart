import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

class OnboardingShell extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String stepLabel;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool nextEnabled;
  final bool isNextLoading;

  const OnboardingShell({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabel,
    required this.child,
    this.onBack,
    this.onNext,
    this.nextLabel = 'NEXT',
    this.nextEnabled = true,
    this.isNextLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DOMFIX_CORE',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${((currentStep / totalSteps) * 100).toInt()}% COMPLETE',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.primaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: List.generate(totalSteps, (index) {
              final stepNumber = index + 1;
              final isCompleted = stepNumber < currentStep;
              final isActive = stepNumber == currentStep;
              
              return Expanded(
                child: Row(
                  children: [
                    // Dot
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isActive ? 24 : 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isCompleted || isActive 
                            ? AppColors.primaryContainer 
                            : const Color(0xFF31353B),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: isActive ? [
                          BoxShadow(
                            color: AppColors.primaryContainer.withOpacity(0.4),
                            blurRadius: 8,
                          )
                        ] : [],
                      ),
                    ),
                    // Line separator (if not last)
                    if (index < totalSteps - 1)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: isCompleted 
                              ? AppColors.primaryContainer.withOpacity(0.5) 
                              : const Color(0xFF31353B),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          Text(
            'Step $currentStep of $totalSteps',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurfaceVariant.withOpacity(0.6),
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stepLabel,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.85),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onBack?.call();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_left,
                    color: Colors.white.withOpacity(0.6),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'BACK',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 40), // Placeholder to keep NEXT aligned properly

          const Spacer(),
          
          if (onNext != null)
            GestureDetector(
              onTap: nextEnabled && !isNextLoading ? () {
                HapticFeedback.mediumImpact();
                onNext?.call();
              } : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                decoration: BoxDecoration(
                  color: (nextEnabled && !isNextLoading)
                      ? AppColors.primaryContainer
                      : AppColors.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: (nextEnabled && !isNextLoading) ? [
                    BoxShadow(
                      color: AppColors.primaryContainer.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ] : [],
                ),
                child: isNextLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.onPrimaryContainer,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentStep == totalSteps ? Icons.check : Icons.bolt,
                            color: AppColors.onPrimaryContainer,
                            size: 18,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nextLabel,
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
