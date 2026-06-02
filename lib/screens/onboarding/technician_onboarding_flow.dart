import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/technician_onboarding_data.dart';
import 'professional_identity_screen.dart';
import 'specialties_screen.dart';
import 'experience_portfolio_screen.dart';
import 'availability_screen.dart';
import 'trust_verification_screen.dart';
import 'profile_audit_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Technician Onboarding Flow
//
// Central controller that manages navigation between all 6 onboarding steps.
// Each step receives the shared [TechnicianOnboardingData] and mutates it.
// ─────────────────────────────────────────────────────────────────────────────

class TechnicianOnboardingFlow extends StatefulWidget {
  /// Fired when the flow is complete; awaited so Firestore + navigation can finish.
  final Future<void> Function(TechnicianOnboardingData data)? onComplete;

  const TechnicianOnboardingFlow({super.key, this.onComplete});

  @override
  State<TechnicianOnboardingFlow> createState() =>
      _TechnicianOnboardingFlowState();
}

class _TechnicianOnboardingFlowState extends State<TechnicianOnboardingFlow> {
  final _pageController = PageController();
  final _data = TechnicianOnboardingData();
  int _currentStep = 0;

  static const int _totalSteps = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentStep < _totalSteps - 1) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      HapticFeedback.mediumImpact();
      unawaited(_invokeComplete(_data));
    }
  }

  Future<void> _invokeComplete(TechnicianOnboardingData data) async {
    final cb = widget.onComplete;
    if (cb != null) await cb(data);
  }

  void _goBack() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(), // controlled programmatically
      children: [
        // ── Step 1 ────────────────────────────────────────────────────────────
        ProfessionalIdentityScreen(
          onboardingData: _data,
          onNext: _goNext,
          onBack: _goBack,
        ),

        // ── Step 2 – Specialties ──────────────────────────────────────────────
        SpecialtiesScreen(
          onboardingData: _data,
          onNext: _goNext,
          onBack: _goBack,
        ),

        // ── Step 3 – Experience & Portfolio
        ExperiencePortfolioScreen(
          onboardingData: _data,
          onNext: _goNext,
          onBack: _goBack,
        ),

        // ── Step 4 – Availability
        AvailabilityScreen(
          onboardingData: _data,
          onNext: _goNext,
          onBack: _goBack,
        ),

        // ── Step 5 – Trust & Verification
        TrustVerificationScreen(
          onboardingData: _data,
          onNext: _goNext,
          onBack: _goBack,
        ),

        // ── Step 6 – Profile Audit Complete (final)
        ProfileAuditScreen(
          onboardingData: _data,
          onBack: _goBack,
          onFinish: () {
            HapticFeedback.mediumImpact();
            unawaited(_invokeComplete(_data));
          },
        ),
      ],
    );
  }
}

