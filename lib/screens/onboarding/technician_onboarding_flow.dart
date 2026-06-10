import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/technician_onboarding_data.dart';
import 'onboarding_shell.dart';
import 'professional_identity_screen.dart';
import 'specialties_screen.dart';
import 'experience_portfolio_screen.dart';
import 'availability_screen.dart';
import 'review_finish_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Technician Onboarding Flow
//
// Central controller that manages navigation between all 5 onboarding steps.
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
  final _data = TechnicianOnboardingData();
  int _currentStep = 0;
  bool _isSubmitting = false;

  static const int _totalSteps = 5;

  final _identityKey = GlobalKey<ProfessionalIdentityScreenState>();
  final _specialtiesKey = GlobalKey<SpecialtiesScreenState>();
  final _experienceKey = GlobalKey<ExperiencePortfolioScreenState>();
  final _availabilityKey = GlobalKey<AvailabilityScreenState>();
  final _reviewKey = GlobalKey<ReviewFinishScreenState>();

  void _goNext() {
    if (_currentStep == 0) {
      if (_identityKey.currentState?.validate() == false) return;
      _identityKey.currentState?.save();
    } else if (_currentStep == 1) {
      if (_specialtiesKey.currentState?.validate() == false) return;
      _specialtiesKey.currentState?.save();
    } else if (_currentStep == 2) {
      if (_experienceKey.currentState?.validate() == false) return;
      _experienceKey.currentState?.save();
    } else if (_currentStep == 3) {
      if (_availabilityKey.currentState?.validate() == false) return;
      _availabilityKey.currentState?.save();
    }

    if (_currentStep < _totalSteps - 1) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_reviewKey.currentState?.validate() == false) return;
    _reviewKey.currentState?.save();

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);
    await _invokeComplete(_data);
    if (mounted) {
      setState(() => _isSubmitting = false);
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
    } else {
      Navigator.of(context).maybePop();
    }
  }

  String _getStepLabel(int step) {
    switch (step) {
      case 0: return 'Profile Setup';
      case 1: return 'Skills & Expertise';
      case 2: return 'Experience';
      case 3: return 'Availability';
      case 4: return 'Review & Finish';
      default: return '';
    }
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return ProfessionalIdentityScreen(key: _identityKey, onboardingData: _data);
      case 1:
        return SpecialtiesScreen(key: _specialtiesKey, onboardingData: _data);
      case 2:
        return ExperiencePortfolioScreen(key: _experienceKey, onboardingData: _data);
      case 3:
        return AvailabilityScreen(key: _availabilityKey, onboardingData: _data);
      case 4:
        return ReviewFinishScreen(key: _reviewKey, onboardingData: _data);
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      currentStep: _currentStep + 1,
      totalSteps: _totalSteps,
      stepLabel: _getStepLabel(_currentStep),
      onBack: _goBack,
      onNext: _goNext,
      nextLabel: _currentStep == _totalSteps - 1 ? 'FINISH & GO TO DASHBOARD' : 'NEXT',
      isNextLoading: _isSubmitting,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _buildStep(_currentStep),
      ),
    );
  }
}

