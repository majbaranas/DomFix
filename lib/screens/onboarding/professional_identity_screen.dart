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

  const ProfessionalIdentityScreen({
    super.key,
    required this.onboardingData,
  });

  @override
  State<ProfessionalIdentityScreen> createState() =>
      ProfessionalIdentityScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class ProfessionalIdentityScreenState
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

  bool validate() {
    if (!_formKey.currentState!.validate()) return false;

    if (_photoUploadState == _UploadState.uploading) {
      _showSnackBar('Please wait for the photo upload to finish.', isError: true);
      return false;
    }
    return true;
  }

  void save() {
    widget.onboardingData
      ..fullName = _fullNameController.text.trim()
      ..age = int.tryParse(_ageController.text.trim())
      ..city = _cityController.text.trim()
      ..bio = _bioController.text.trim();
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
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
            children: [
              _buildWelcomeHero(),
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
    );
  }

  Widget _buildWelcomeHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Let\'s build your\nprofessional identity',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'This is how clients will see you. Make it count.',
          style: GoogleFonts.inter(
            color: AppColors.onSurfaceVariant,
            fontSize: 14,
          ),
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
        SizedBox(height: 12),
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
          SizedBox(height: 6),
          Text(
            _photoErrorMessage!,
            style: GoogleFonts.inter(
              color: AppColors.error,
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
        return AppColors.error;
      case _UploadState.uploading:
        return AppColors.primaryContainer.withValues(alpha: 0.5);
      case _UploadState.idle:
        return AppColors.outlineVariant;
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
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.neonAccent,
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
                child: Icon(Icons.check, size: 12, color: AppColors.onPrimary),
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
              ? AppColors.error
              : AppColors.outline,
        ),
        SizedBox(height: 6),
        Text(
          'ADD PHOTO',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.outline,
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
      child: Icon(Icons.edit, size: 14, color: AppColors.onPrimary),
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
          SizedBox(width: 12),
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


// ─────────────────────────────────────────────────────────────────────────────
}

// Private helpers / sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

enum _UploadState { idle, uploading, success, error }

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
          color: AppColors.outline,
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFF2A2E35), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryContainer, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        errorStyle: GoogleFonts.inter(
          color: AppColors.error,
          fontSize: 11,
        ),
        filled: true,
        fillColor: const Color(0xFF181C21),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2E35), width: 1.5),
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
                color: AppColors.outline,
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
        SizedBox(height: 4),
        Text(
          '$charCount/$maxChars CHARACTERS',
          style: GoogleFonts.inter(
            color: charCount >= maxChars
                ? AppColors.error
                : AppColors.outline,
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
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
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
              color: AppColors.glassHighlight,
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
        ? AppColors.error
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
