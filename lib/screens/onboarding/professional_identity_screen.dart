import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/technician_onboarding_data.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen entry point
// ─────────────────────────────────────────────────────────────────────────────

class ProfessionalIdentityScreen extends StatefulWidget {
  /// Shared data object that is mutated and passed to the next step.
  final TechnicianOnboardingData onboardingData;

  /// Called when the user taps NEXT and the step is complete.
  final VoidCallback? onNext;

  /// Called when the user taps BACK.
  final VoidCallback? onBack;

  const ProfessionalIdentityScreen({
    super.key,
    required this.onboardingData,
    this.onNext,
    this.onBack,
  });

  @override
  State<ProfessionalIdentityScreen> createState() =>
      _ProfessionalIdentityScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalIdentityScreenState
    extends State<ProfessionalIdentityScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ─────────────────────────────────────────────────────────────
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── Animation ───────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Upload state ─────────────────────────────────────────────────────────────
  File? _pickedPhotoFile;
  _UploadState _photoUploadState = _UploadState.idle;
  String? _photoErrorMessage;

  // ── Bio char count ──────────────────────────────────────────────────────────
  int _bioCharCount = 0;

  // ── ImagePicker instance ────────────────────────────────────────────────────
  final _picker = ImagePicker();

  // ─────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Pre-fill from shared data (if the user navigated back)
    _fullNameController.text = widget.onboardingData.fullName ?? '';
    _ageController.text =
        widget.onboardingData.age?.toString() ?? '';
    _cityController.text = widget.onboardingData.city ?? '';
    _bioController.text = widget.onboardingData.bio ?? '';
    _bioCharCount = _bioController.text.length;

    _bioController.addListener(() {
      setState(() => _bioCharCount = _bioController.text.length);
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _fullNameController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Image picking & uploading
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (picked == null) return; // user cancelled

      final file = File(picked.path);
      setState(() {
        _pickedPhotoFile = file;
        _photoUploadState = _UploadState.uploading;
        _photoErrorMessage = null;
      });

      HapticFeedback.lightImpact();

      final cloudinaryService = CloudinaryService();
      final url = await cloudinaryService.uploadImage(
        imageFile: file,
        chatId: 'profile_photos', // Use a generic folder for profile photos
        compress: true,
      );

      if (!mounted) return;
      setState(() {
        _photoUploadState = _UploadState.success;
        widget.onboardingData.profilePhotoUrl = url;
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _photoUploadState = _UploadState.error;
        _photoErrorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _showImageSourceSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(
        onGallery: () {
          Navigator.pop(context);
          _pickAndUpload(ImageSource.gallery);
        },
        onCamera: () {
          Navigator.pop(context);
          _pickAndUpload(ImageSource.camera);
        },
        onRemove: _pickedPhotoFile != null
            ? () {
                Navigator.pop(context);
                setState(() {
                  _pickedPhotoFile = null;
                  _photoUploadState = _UploadState.idle;
                  _photoErrorMessage = null;
                  widget.onboardingData.profilePhotoUrl = null;
                });
              }
            : null,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────────────────────────────────────

  void _handleNext() {
    if (!_formKey.currentState!.validate()) return;

    // Warn if photo not uploaded yet (not blocking – photo is recommended)
    if (_photoUploadState == _UploadState.uploading) {
      _showSnackBar('Please wait for the photo upload to finish.', isError: true);
      return;
    }

    // Save to shared model
    widget.onboardingData
      ..fullName = _fullNameController.text.trim()
      ..age = int.tryParse(_ageController.text.trim())
      ..city = _cityController.text.trim()
      ..bio = _bioController.text.trim();

    HapticFeedback.mediumImpact();
    widget.onNext?.call();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor:
            isError ? const Color(0xFF93000A) : AppColors.primaryContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

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
              _buildTopAppBar(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                    children: [
                      _buildProgressSection(),
                      const SizedBox(height: 40),
                      _buildProfilePhotoSection(),
                      const SizedBox(height: 40),
                      _buildFormFields(),
                      const SizedBox(height: 32),
                      _buildProTip(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Top app bar ──────────────────────────────────────────────────────────────

  Widget _buildTopAppBar() {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onBack?.call();
            },
          ),
          const SizedBox(width: 12),
          Text(
            'DOMFIX_CORE',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Text(
            'STEP 1 OF 6',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.primaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 12),
          _IconBtn(icon: Icons.more_vert, onTap: () {}),
        ],
      ),
    );
  }

  // ── Progress bar ─────────────────────────────────────────────────────────────

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'PROFESSIONAL\nIDENTITY',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Text(
              '16% COMPLETE',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.primaryContainer,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              height: 3,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF31353B),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            FractionallySizedBox(
              widthFactor: 0.16,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Profile photo ─────────────────────────────────────────────────────────────

  Widget _buildProfilePhotoSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showImageSourceSheet,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildPhotoCircle(),
              Positioned(
                bottom: 0,
                right: -2,
                child: _buildEditBadge(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'UPLOAD PROFESSIONAL PORTRAIT',
          style: GoogleFonts.inter(
            color: const Color(0xFFA0AEC0),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        if (_photoUploadState == _UploadState.error &&
            _photoErrorMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            _photoErrorMessage!,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFB4AB),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoCircle() {
    const size = 120.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF181C21),
        border: Border.all(
          color: _borderColorForState(),
          width: _photoUploadState == _UploadState.success ? 2.5 : 1.5,
          style: _pickedPhotoFile == null
              ? BorderStyle.solid
              : BorderStyle.solid,
        ),
        boxShadow: _photoUploadState == _UploadState.success
            ? [
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.25),
                  blurRadius: 20,
                )
              ]
            : null,
      ),
      child: ClipOval(
        child: _buildPhotoContent(size),
      ),
    );
  }

  Color _borderColorForState() {
    switch (_photoUploadState) {
      case _UploadState.success:
        return AppColors.primaryContainer;
      case _UploadState.error:
        return const Color(0xFFFFB4AB);
      case _UploadState.uploading:
        return AppColors.primaryContainer.withValues(alpha: 0.5);
      case _UploadState.idle:
        return const Color(0xFF454932);
    }
  }

  Widget _buildPhotoContent(double size) {
    if (_pickedPhotoFile != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_pickedPhotoFile!, fit: BoxFit.cover),
          if (_photoUploadState == _UploadState.uploading)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: const Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFD9FF00),
                    ),
                  ),
                ),
              ),
            ),
          if (_photoUploadState == _UploadState.success)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: Color(0xFF2B3400)),
              ),
            ),
        ],
      );
    }

    // Idle / no image
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo_outlined,
          size: 34,
          color: _photoUploadState == _UploadState.error
              ? const Color(0xFFFFB4AB)
              : const Color(0xFF8F9378),
        ),
        const SizedBox(height: 6),
        Text(
          'ADD PHOTO',
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFF8F9378),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEditBadge() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.edit, size: 14, color: Color(0xFF2B3400)),
    );
  }

  // ── Form fields ──────────────────────────────────────────────────────────────

  Widget _buildFormFields() {
    return Column(
      children: [
        // Full Name
        _DomfixTextField(
          controller: _fullNameController,
          label: 'FULL NAME',
          keyboardType: TextInputType.name,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
        ),
        const SizedBox(height: 32),

        // Age + City row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Age (optional)
            Expanded(
              flex: 4,
              child: _DomfixTextField(
                controller: _ageController,
                label: 'AGE (OPT)',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final age = int.tryParse(v);
                  if (age == null || age < 18 || age > 80) {
                    return '18–80';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 20),

            // City
            Expanded(
              flex: 8,
              child: _DomfixTextField(
                controller: _cityController,
                label: 'CITY',
                keyboardType: TextInputType.text,
                suffixIcon: const Icon(Icons.location_on_outlined,
                    size: 18, color: Color(0xFFA0AEC0)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'City is required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Short Bio
        _DomfixTextArea(
          controller: _bioController,
          charCount: _bioCharCount,
          maxChars: 150,
        ),
      ],
    );
  }

  // ── Pro Tip card ─────────────────────────────────────────────────────────────

  Widget _buildProTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181C21),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: AppColors.primaryContainer,
            width: 2.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.primaryContainer, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRO-TIP',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.primaryContainer,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Profile photos with neutral backgrounds increase trust by up to 40% in our technician marketplace.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFB4B8C8),
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav ───────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final isUploading = _photoUploadState == _UploadState.uploading;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onBack?.call();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left,
                    color: Colors.white.withValues(alpha: 0.6), size: 22),
                const SizedBox(height: 2),
                Text(
                  'BACK',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Next
          GestureDetector(
            onTap: isUploading ? null : _handleNext,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              decoration: BoxDecoration(
                color: isUploading
                    ? AppColors.primaryContainer.withValues(alpha: 0.5)
                    : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isUploading
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.primaryContainer.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF2B3400)),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NEXT',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF2B3400),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.bolt,
                            color: Color(0xFF2B3400), size: 18),
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
// Private helpers / sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

enum _UploadState { idle, uploading, success, error }

// ── Small icon button ─────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: AppColors.onSurface, size: 22),
      ),
    );
  }
}

// ── DomFix text field ─────────────────────────────────────────────────────────

class _DomfixTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _DomfixTextField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 15),
      cursorColor: AppColors.primaryContainer,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
          color: const Color(0xFF8F9378),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.8,
        ),
        floatingLabelStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.primaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.8,
        ),
        suffixIcon: suffixIcon,
        enabledBorder: const UnderlineInputBorder(
          borderSide:
              BorderSide(color: Color(0xFF454932), width: 1.5),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryContainer, width: 2),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFFFB4AB), width: 1.5),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFFFB4AB), width: 2),
        ),
        errorStyle: GoogleFonts.inter(
          color: const Color(0xFFFFB4AB),
          fontSize: 11,
        ),
        filled: false,
        contentPadding:
            const EdgeInsets.only(bottom: 8, top: 4),
      ),
    );
  }
}

// ── DomFix text area ──────────────────────────────────────────────────────────

class _DomfixTextArea extends StatelessWidget {
  final TextEditingController controller;
  final int charCount;
  final int maxChars;

  const _DomfixTextArea({
    required this.controller,
    required this.charCount,
    required this.maxChars,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181C21),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
            border: const Border(
              bottom: BorderSide(color: Color(0xFF454932), width: 1.5),
            ),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: 4,
            maxLength: maxChars,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                const SizedBox.shrink(),
            style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 14),
            cursorColor: AppColors.primaryContainer,
            decoration: InputDecoration(
              labelText: 'SHORT BIO',
              alignLabelWithHint: true,
              labelStyle: GoogleFonts.spaceGrotesk(
                color: const Color(0xFF8F9378),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
              floatingLabelStyle: GoogleFonts.spaceGrotesk(
                color: AppColors.primaryContainer,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$charCount/$maxChars CHARACTERS',
          style: GoogleFonts.inter(
            color: charCount >= maxChars
                ? const Color(0xFFFFB4AB)
                : const Color(0xFF8F9378),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ── Image source bottom sheet ─────────────────────────────────────────────────

class _ImageSourceSheet extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback? onRemove;

  const _ImageSourceSheet({
    required this.onGallery,
    required this.onCamera,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1C2025),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          Text(
            'SELECT IMAGE SOURCE',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.primaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),

          _SheetOption(
            icon: Icons.photo_library_outlined,
            label: 'Choose from Gallery',
            onTap: onGallery,
          ),
          _SheetOption(
            icon: Icons.camera_alt_outlined,
            label: 'Use Camera',
            onTap: onCamera,
          ),

          if (onRemove != null) ...[
            const Divider(color: Color(0xFF31353B), height: 24),
            _SheetOption(
              icon: Icons.delete_outline,
              label: 'Remove Photo',
              onTap: onRemove!,
              isDestructive: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFFFB4AB)
        : AppColors.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
