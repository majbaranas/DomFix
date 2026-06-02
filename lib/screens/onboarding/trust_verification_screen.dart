import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/technician_onboarding_data.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step 5 – Trust & Verification
// ─────────────────────────────────────────────────────────────────────────────

class TrustVerificationScreen extends StatefulWidget {
  final TechnicianOnboardingData onboardingData;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const TrustVerificationScreen({
    super.key,
    required this.onboardingData,
    this.onNext,
    this.onBack,
  });

  @override
  State<TrustVerificationScreen> createState() =>
      _TrustVerificationScreenState();
}

class _TrustVerificationScreenState extends State<TrustVerificationScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  final _phoneController = TextEditingController();
  bool _phoneVerified = false;
  bool _verifyingPhone = false;

  _DocUploadState _idUploadState = _DocUploadState.idle;
  String? _idDocLabel; // "Passport" or "ID Card"
  String? _idError;

  final _picker = ImagePicker();

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _badgePulse;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.onboardingData.phoneNumber ?? '';
    _phoneVerified = widget.onboardingData.isPhoneVerified;

    if (widget.onboardingData.identityDocumentUrl != null) {
      _idUploadState = _DocUploadState.success;
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _badgePulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
    _animController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── ID upload ──────────────────────────────────────────────────────────────

  Future<void> _uploadIdDocument(String docType) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() {
        _idUploadState = _DocUploadState.uploading;
        _idDocLabel = docType;
        _idError = null;
      });
      HapticFeedback.lightImpact();

      final cloudinaryService = CloudinaryService();
      final url = await cloudinaryService.uploadImage(
        imageFile: File(picked.path),
        chatId: 'identity_documents',
        compress: false,
      );

      if (!mounted) return;
      setState(() {
        _idUploadState = _DocUploadState.success;
        widget.onboardingData.identityDocumentUrl = url;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _idUploadState = _DocUploadState.error;
        _idError = 'Upload failed. Please try again.';
      });
    }
  }

  // ── Phone verification (stub) ──────────────────────────────────────────────

  Future<void> _verifyPhone() async {
    final number = _phoneController.text.trim();
    if (number.isEmpty) {
      _showSnackBar('Please enter your phone number.', isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _verifyingPhone = true);
    // Stub: replace with real OTP flow
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _verifyingPhone = false;
      _phoneVerified = true;
      widget.onboardingData.isPhoneVerified = true;
      widget.onboardingData.phoneNumber = number;
    });
    _showSnackBar('Phone verified successfully!');
    HapticFeedback.lightImpact();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _handleNext() {
    if (_idUploadState == _DocUploadState.uploading || _verifyingPhone) {
      _showSnackBar('Please wait for uploads to complete.', isError: true);
      return;
    }
    widget.onboardingData.phoneNumber = _phoneController.text.trim();
    HapticFeedback.mediumImpact();
    widget.onNext?.call();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor:
          isError ? const Color(0xFF93000A) : AppColors.primaryContainer,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                  children: [
                    _buildProgress(),
                    const SizedBox(height: 24),
                    _buildHeroCard(),
                    const SizedBox(height: 24),
                    _buildIdentityCard(),
                    const SizedBox(height: 20),
                    _buildPhoneCard(),
                    const SizedBox(height: 20),
                    _buildBadgePreview(),
                    const SizedBox(height: 24),
                    _buildComplianceNote(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16, right: 16, bottom: 12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); widget.onBack?.call(); },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.arrow_back,
                  color: AppColors.onSurface, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Text('DOMFIX_CORE',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1,
            )),
          const Spacer(),
          Icon(Icons.more_vert, color: AppColors.onSurface, size: 22),
        ],
      ),
    );
  }

  // ── Progress ───────────────────────────────────────────────────────────────

  Widget _buildProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ONBOARDING PROGRESS',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 10, letterSpacing: 2,
                    )),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Step 5 ',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.onSurface, fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: 'of 6',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.onSurfaceVariant, fontSize: 28,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Text('83%',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.primaryContainer,
                fontSize: 24, fontWeight: FontWeight.w800,
              )),
          ],
        ),
        const SizedBox(height: 12),
        Stack(children: [
          Container(height: 3,
            decoration: BoxDecoration(color: const Color(0xFF31353B),
              borderRadius: BorderRadius.circular(99))),
          FractionallySizedBox(widthFactor: 0.83,
            child: Container(height: 3,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.4),
                  blurRadius: 12,
                )],
              ))),
        ]),
      ],
    );
  }

  // ── Hero card ──────────────────────────────────────────────────────────────

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF181C21),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trust & Verification',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.onSurface, fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant, fontSize: 13,
                    height: 1.6,
                  ),
                  children: [
                    const TextSpan(text: 'Verified Pros earn '),
                    TextSpan(
                      text: '2.5x more',
                      style: GoogleFonts.inter(
                        color: AppColors.primaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(
                        text: ' on average. Build instant credibility with customers.'),
                  ],
                ),
              ),
            ],
          ),
          // Decorative watermark icon
          Positioned(
            right: -8, bottom: -8,
            child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.verified, size: 90, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Identity document card ─────────────────────────────────────────────────

  Widget _buildIdentityCard() {
    final isUploaded = _idUploadState == _DocUploadState.success;
    final isUploading = _idUploadState == _DocUploadState.uploading;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2025),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('VERIFY IDENTITY',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.primaryContainer, fontSize: 11,
                            fontWeight: FontWeight.w700, letterSpacing: 2,
                          )),
                        if (isUploaded) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle,
                              color: AppColors.primaryContainer, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Official document required for security audit.',
                      style: GoogleFonts.inter(
                        color: AppColors.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.shield_outlined,
                  color: AppColors.onSurfaceVariant, size: 22),
            ],
          ),

          if (isUploaded) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user,
                      color: AppColors.primaryContainer, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    '${_idDocLabel ?? "Document"} uploaded successfully',
                    style: GoogleFonts.inter(
                      color: AppColors.primaryContainer, fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _idUploadState = _DocUploadState.idle;
                      widget.onboardingData.identityDocumentUrl = null;
                    }),
                    child: Icon(Icons.close,
                        color: AppColors.onSurfaceVariant, size: 16),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _docButton(
                    icon: Icons.add_a_photo_outlined,
                    label: 'PASSPORT',
                    isLoading: isUploading && _idDocLabel == 'Passport',
                    onTap: () => _uploadIdDocument('Passport'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _docButton(
                    icon: Icons.upload_file_outlined,
                    label: 'ID CARD',
                    isLoading: isUploading && _idDocLabel == 'ID Card',
                    onTap: () => _uploadIdDocument('ID Card'),
                  ),
                ),
              ],
            ),
            if (_idError != null) ...[
              const SizedBox(height: 8),
              Text(_idError!,
                style: GoogleFonts.inter(
                  color: const Color(0xFFFFB4AB), fontSize: 11)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _docButton({
    required IconData icon,
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF262A30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF454932).withValues(alpha: 0.2), width: 1),
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD9FF00)),
                  )))
            : Column(
                children: [
                  Icon(icon, color: const Color(0xFFB4D400), size: 26),
                  const SizedBox(height: 8),
                  Text(label,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.onSurface, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5,
                    )),
                ],
              ),
      ),
    );
  }

  // ── Phone card ─────────────────────────────────────────────────────────────

  Widget _buildPhoneCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF181C21),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('PHONE NUMBER',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.onSurface, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 2,
                )),
              const Spacer(),
              if (_phoneVerified)
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.primaryContainer, size: 14),
                    const SizedBox(width: 4),
                    Text('VERIFIED',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.primaryContainer, fontSize: 9,
                        fontWeight: FontWeight.w700, letterSpacing: 1.5,
                      )),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.primaryContainer, fontSize: 18),
            cursorColor: AppColors.primaryContainer,
            enabled: !_phoneVerified,
            decoration: InputDecoration(
              hintText: '+1 (555) 000-0000',
              hintStyle: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                fontSize: 16,
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF454932), width: 1.5)),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: AppColors.primaryContainer, width: 2)),
              disabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: AppColors.primaryContainer.withValues(alpha: 0.4),
                    width: 1.5)),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _phoneVerified ? null : (_verifyingPhone ? null : _verifyPhone),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _phoneVerified
                    ? AppColors.primaryContainer.withValues(alpha: 0.15)
                    : const Color(0xFF31353B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _verifyingPhone
                  ? const Center(
                      child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFD9FF00)),
                        )))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _phoneVerified ? 'Verified' : 'Verify',
                          style: GoogleFonts.spaceGrotesk(
                            color: _phoneVerified
                                ? AppColors.primaryContainer
                                : AppColors.onSurface,
                            fontSize: 12, fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _phoneVerified ? Icons.check : Icons.bolt,
                          color: _phoneVerified
                              ? AppColors.primaryContainer
                              : AppColors.onSurface,
                          size: 16,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Badge preview ──────────────────────────────────────────────────────────

  Widget _buildBadgePreview() {
    final isVerified = _idUploadState == _DocUploadState.success &&
        _phoneVerified;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF181C21),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVerified
              ? AppColors.primaryContainer.withValues(alpha: 0.2)
              : Colors.transparent,
          width: 1,
        ),
        boxShadow: isVerified
            ? [
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.08),
                  blurRadius: 30, spreadRadius: 4,
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: isVerified ? _badgePulse : const AlwaysStoppedAnimation(1.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryContainer.withValues(alpha: 0.2),
                        const Color(0xFF31353B),
                      ],
                    ),
                    boxShadow: isVerified
                        ? [BoxShadow(
                            color: AppColors.primaryContainer.withValues(alpha: 0.2),
                            blurRadius: 30,
                          )]
                        : [],
                  ),
                  child: Icon(Icons.verified,
                    color: isVerified
                        ? AppColors.primaryContainer
                        : AppColors.onSurfaceVariant,
                    size: 42,
                  ),
                ),
                // Small check badge
                if (isVerified)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle,
                          size: 14, color: Color(0xFF181E00)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('DOMFIX VERIFIED',
            style: GoogleFonts.spaceGrotesk(
              color: isVerified ? AppColors.onSurface : AppColors.onSurfaceVariant,
              fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2.5,
            )),
          const SizedBox(height: 4),
          Text('BADGE PREVIEW',
            style: GoogleFonts.inter(
              color: AppColors.onSurfaceVariant, fontSize: 9,
              letterSpacing: 2,
            )),
          if (!isVerified) ...[
            const SizedBox(height: 10),
            Text(
              'Complete identity & phone to unlock',
              style: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Compliance note ────────────────────────────────────────────────────────

  Widget _buildComplianceNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E13),
        border: Border(
          left: BorderSide(
            color: AppColors.primaryContainer.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
      ),
      child: Text(
        'By completing this step, you authorize DOMFIX_CORE to perform a standard identity background check. Data is encrypted and managed under Tier-4 security protocols.',
        style: GoogleFonts.inter(
          color: AppColors.onSurfaceVariant,
          fontSize: 12, height: 1.6, fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final isLoading = _idUploadState == _DocUploadState.uploading || _verifyingPhone;

    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        border: Border(top: BorderSide(
          color: Colors.white.withValues(alpha: 0.08), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); widget.onBack?.call(); },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left,
                    color: Colors.white.withValues(alpha: 0.6), size: 22),
                const SizedBox(height: 2),
                Text('BACK',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10, fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  )),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: isLoading ? null : _handleNext,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: isLoading
                    ? AppColors.primaryContainer.withValues(alpha: 0.5)
                    : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isLoading ? [] : [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.35),
                    blurRadius: 20, offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2B3400)),
                      ))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt,
                            color: const Color(0xFF2B3400), size: 20),
                        const SizedBox(height: 2),
                        Text('NEXT',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF2B3400),
                            fontWeight: FontWeight.w800,
                            fontSize: 11, letterSpacing: 2,
                          )),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload state enum
// ─────────────────────────────────────────────────────────────────────────────

enum _DocUploadState { idle, uploading, success, error }
