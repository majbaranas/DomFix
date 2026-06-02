/// Holds all data collected during the Technician onboarding flow.
///
/// This model is passed forward through all 6 steps and submitted
/// to the backend at the final step.
class TechnicianOnboardingData {
  // ── Step 1 – Professional Identity ────────────────────────────────────────
  String? profilePhotoUrl; // Cloudinary secure_url
  String? fullName;
  int? age;
  String? city;
  String? bio;

  // ── Step 2 – Specialties ──────────────────────────────────────────────────
  List<String> specialties = [];   // Selected skill names
  List<String> customSkills = [];  // User-added custom skills

  // ── Step 3 – Experience & Portfolio ──────────────────────────────────────
  int yearsOfExperience = 0;
  List<UploadedFile> certifications = [];  // Cloudinary uploads
  List<UploadedFile> portfolioImages = []; // Cloudinary uploads

  // ── Step 4 – Availability ─────────────────────────────────────────────────
  bool isAvailable = true;
  List<String> availableDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  int startHour = 8;
  int startMinute = 0;
  int endHour = 18;
  int endMinute = 0;
  int serviceRadiusMiles = 25;
  String? detectedLocation;

  // ── Step 5 – Trust & Verification ─────────────────────────────────────────
  String? identityDocumentUrl;  // Cloudinary secure_url (passport / ID card)
  String? phoneNumber;
  bool isPhoneVerified = false;

  TechnicianOnboardingData();

  /// Convenience getters
  List<String> get certificationUrls =>
      certifications.map((f) => f.url).toList();
  List<String> get portfolioUrls =>
      portfolioImages.map((f) => f.url).toList();

  /// Returns true when the mandatory Step-1 fields are complete.
  bool get isStep1Complete =>
      profilePhotoUrl != null &&
      profilePhotoUrl!.isNotEmpty &&
      fullName != null &&
      fullName!.trim().isNotEmpty &&
      city != null &&
      city!.trim().isNotEmpty;

  /// Returns true when Step-2 has at least 1 specialty selected.
  bool get isStep2Complete => specialties.isNotEmpty || customSkills.isNotEmpty;

  @override
  String toString() => 'TechnicianOnboardingData('
      'fullName: $fullName, city: $city, '
      'specialties: $specialties, '
      'yearsOfExperience: $yearsOfExperience, '
      'certifications: ${certifications.length}, '
      'portfolioImages: ${portfolioImages.length})';
}

/// Metadata for a single Cloudinary-uploaded file.
class UploadedFile {
  final String url;       // Cloudinary secure_url
  final String fileName;  // Display name

  const UploadedFile({required this.url, required this.fileName});
}
