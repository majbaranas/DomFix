import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'settings': 'Settings',
      'profile': 'Profile',
      'notifications': 'Notifications',
      'privacy_security': 'Privacy & Security',
      'help_support': 'Help & Support',
      'logout': 'Logout',
      'cancel': 'Cancel',
      'logout_confirm_title': 'Logout',
      'logout_confirm_content': 'Are you sure you want to logout?',
      'language': 'Language',
      'select_language': 'Select Language',
      'english': 'English',
      'french': 'Français',
      'arabic': 'العربية',
      // Booking & Dashboard
      'active_job': 'Active job',
      'new_requests': 'New requests',
      'weekly_earnings': 'Weekly earnings',
      'online_status': 'Online Status',
      'accept': 'Accept',
      'decline': 'Decline',
      'start_job': 'Start job',
      'complete_job': 'Complete job',
      'on_the_way': 'On the way',
      'arrived': 'Arrived',
      // Bookings flow
      'book_now': 'Book Now',
      'select_service': 'Select Service',
      'select_date_time': 'Select Date & Time',
      'problem_description': 'Problem Description',
      'attach_photos': 'Attach Photos',
      'priority': 'Priority Selection',
      'estimation': 'Estimation',
      'review': 'Review',
      'confirmation': 'Confirmation',
      // Common
      'email': 'Email',
      'password': 'Password',
      'login': 'Log In',
      'register': 'Register',
      'welcome': 'Welcome',
    },
    'fr': {
      'settings': 'Paramètres',
      'profile': 'Profil',
      'notifications': 'Notifications',
      'privacy_security': 'Confidentialité et Sécurité',
      'help_support': 'Aide et Support',
      'logout': 'Déconnexion',
      'cancel': 'Annuler',
      'logout_confirm_title': 'Déconnexion',
      'logout_confirm_content': 'Êtes-vous sûr de vouloir vous déconnecter ?',
      'language': 'Langue',
      'select_language': 'Choisir la langue',
      'english': 'English',
      'french': 'Français',
      'arabic': 'العربية',
      // Booking & Dashboard
      'active_job': 'Travail actif',
      'new_requests': 'Nouvelles demandes',
      'weekly_earnings': 'Revenus hebdomadaires',
      'online_status': 'Statut en ligne',
      'accept': 'Accepter',
      'decline': 'Décliner',
      'start_job': 'Démarrer le travail',
      'complete_job': 'Terminer le travail',
      'on_the_way': 'En chemin',
      'arrived': 'Arrivé',
      // Bookings flow
      'book_now': 'Réserver maintenant',
      'select_service': 'Sélectionner le service',
      'select_date_time': 'Sélectionner la date et l\'heure',
      'problem_description': 'Description du problème',
      'attach_photos': 'Joindre des photos',
      'priority': 'Sélection de la priorité',
      'estimation': 'Estimation',
      'review': 'Révision',
      'confirmation': 'Confirmation',
      // Common
      'email': 'E-mail',
      'password': 'Mot de passe',
      'login': 'Connexion',
      'register': 'S\'inscrire',
      'welcome': 'Bienvenue',
    },
    'ar': {
      'settings': 'الإعدادات',
      'profile': 'الملف الشخصي',
      'notifications': 'الإشعارات',
      'privacy_security': 'الخصوصية والأمان',
      'help_support': 'المساعدة والدعم',
      'logout': 'تسجيل الخروج',
      'cancel': 'إلغاء',
      'logout_confirm_title': 'تسجيل الخروج',
      'logout_confirm_content': 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      'language': 'اللغة',
      'select_language': 'اختر اللغة',
      'english': 'English',
      'french': 'Français',
      'arabic': 'العربية',
      // Booking & Dashboard
      'active_job': 'العمل الحالي',
      'new_requests': 'طلبات جديدة',
      'weekly_earnings': 'الأرباح الأسبوعية',
      'online_status': 'حالة الاتصال',
      'accept': 'قبول',
      'decline': 'رفض',
      'start_job': 'بدء العمل',
      'complete_job': 'إكمال العمل',
      'on_the_way': 'في الطريق',
      'arrived': 'وصلت',
      // Bookings flow
      'book_now': 'احجز الآن',
      'select_service': 'اختر الخدمة',
      'select_date_time': 'اختر التاريخ والوقت',
      'problem_description': 'وصف المشكلة',
      'attach_photos': 'إرفاق صور',
      'priority': 'تحديد الأهمية',
      'estimation': 'التقدير التقديري',
      'review': 'مراجعة الطلب',
      'confirmation': 'تأكيد الحجز',
      // Common
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'login': 'تسجيل الدخول',
      'register': 'إنشاء حساب',
      'welcome': 'مرحباً',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalizations> old) => false;
}

extension LocalizationExtension on BuildContext {
  String translate(String key) {
    return AppLocalizations.of(this)?.translate(key) ?? key;
  }
}
