enum ChatRestrictionReason {
  phoneNumber,
  externalLink,
  socialContact,
  emailAddress,
  spam,
}

class ChatModerationResult {
  final bool allowed;
  final ChatRestrictionReason? reason;
  final String? message;

  const ChatModerationResult.allowed()
      : allowed = true,
        reason = null,
        message = null;

  const ChatModerationResult.blocked(this.reason, this.message)
      : allowed = false;
}

class ChatModerationService {
  static final RegExp _phonePattern =
      RegExp(r'(\+?\d[\d\s().-]{7,}\d)');
  static final RegExp _urlPattern =
      RegExp(r'(https?:\/\/|www\.)\S+', caseSensitive: false);
  static final RegExp _emailPattern = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );
  static final RegExp _socialPattern = RegExp(
    r'\b(whatsapp|wa\.me|telegram|t\.me|telegram\.me|signal|discord|instagram|facebook|messenger)\b',
    caseSensitive: false,
  );
  static final RegExp _spamPattern = RegExp(r'(.)\1{6,}');
  static final RegExp _wordSpamPattern = RegExp(
    r'\b(\w+)(\s+\1\b){3,}',
    caseSensitive: false,
  );

  static ChatModerationResult validateLimitedMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const ChatModerationResult.allowed();
    }

    if (_urlPattern.hasMatch(trimmed)) {
      return const ChatModerationResult.blocked(
        ChatRestrictionReason.externalLink,
        'Links are hidden until a booking is confirmed.',
      );
    }

    if (_emailPattern.hasMatch(trimmed)) {
      return const ChatModerationResult.blocked(
        ChatRestrictionReason.emailAddress,
        'Email sharing is locked until booking confirmation.',
      );
    }

    if (_phonePattern.hasMatch(trimmed)) {
      return const ChatModerationResult.blocked(
        ChatRestrictionReason.phoneNumber,
        'Phone numbers are blocked before booking.',
      );
    }

    if (_socialPattern.hasMatch(trimmed)) {
      return const ChatModerationResult.blocked(
        ChatRestrictionReason.socialContact,
        'External contact apps are blocked before booking.',
      );
    }

    if (_spamPattern.hasMatch(trimmed) || _wordSpamPattern.hasMatch(trimmed)) {
      return const ChatModerationResult.blocked(
        ChatRestrictionReason.spam,
        'That message looks like spam. Please keep it concise and relevant.',
      );
    }

    return const ChatModerationResult.allowed();
  }
}
