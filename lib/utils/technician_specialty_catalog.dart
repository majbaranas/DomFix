class TechnicianSpecialtyCatalog {
  TechnicianSpecialtyCatalog._();

  static const List<String> canonicalSpecialties = [
    'Smart Home',
    'Electrical Installation',
    'Solar Panels',
    'CCTV & Security',
    'Networking',
    'WiFi & Routers',
    'Home Automation',
    'Lighting Systems',
    'Energy Monitoring',
    'IoT Systems',
    'Access Control',
    'Intercom Systems',
  ];

  static final Map<String, String> _normalizedToCanonical = {
    for (final specialty in canonicalSpecialties) _normalizeKey(specialty): specialty,
  };

  static final Map<String, String> _aliases = {
    'smart home installation': 'Smart Home',
    'smart home system': 'Smart Home',
    'smart home systems': 'Smart Home',
    'smart-home': 'Smart Home',
    'electrical': 'Electrical Installation',
    'electrical install': 'Electrical Installation',
    'electrician': 'Electrical Installation',
    'solar panel': 'Solar Panels',
    'solar panels installation': 'Solar Panels',
    'cctv': 'CCTV & Security',
    'security cameras': 'CCTV & Security',
    'camera security': 'CCTV & Security',
    'network': 'Networking',
    'wifi': 'WiFi & Routers',
    'wi fi': 'WiFi & Routers',
    'wireless routers': 'WiFi & Routers',
    'router setup': 'WiFi & Routers',
    'home automation system': 'Home Automation',
    'automation': 'Home Automation',
    'lighting': 'Lighting Systems',
    'energy monitoring system': 'Energy Monitoring',
    'iot': 'IoT Systems',
    'access control system': 'Access Control',
    'intercom': 'Intercom Systems',
  }.map((key, value) => MapEntry(_normalizeKey(key), value));

  static String? normalize(String? raw) {
    if (raw == null) return null;
    final key = _normalizeKey(raw);
    if (key.isEmpty) return null;
    return _aliases[key] ?? _normalizedToCanonical[key];
  }

  static List<String> normalizeList(Iterable<String> values) {
    final result = <String>[];
    for (final value in values) {
      final normalized = normalize(value);
      if (normalized != null && !result.contains(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }

  static bool matchesFilter(Iterable<String> specialties, String filter) {
    final normalizedFilter = normalize(filter);
    if (normalizedFilter == null) return false;
    return normalizeList(specialties).contains(normalizedFilter);
  }

  static bool matchesQuery({
    required String query,
    required String primarySpecialty,
    required Iterable<String> specialties,
  }) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return true;

    final normalizedQuery = normalize(trimmed);
    final normalizedSpecialties = normalizeList(specialties);
    final normalizedPrimary = normalize(primarySpecialty) ?? primarySpecialty;

    if (normalizedQuery != null) {
      return normalizedPrimary == normalizedQuery ||
          normalizedSpecialties.contains(normalizedQuery);
    }

    return normalizedPrimary.toLowerCase().contains(trimmed) ||
        normalizedSpecialties.any((value) => value.toLowerCase().contains(trimmed));
  }

  static String _normalizeKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
