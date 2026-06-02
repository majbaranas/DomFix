class OnboardingPage {
  final String title;
  final String highlightedText;
  final String description;
  final String iconName;
  final int pageIndex;

  const OnboardingPage({
    required this.title,
    required this.highlightedText,
    required this.description,
    required this.iconName,
    required this.pageIndex,
  });
}

final List<OnboardingPage> onboardingPages = [
  const OnboardingPage(
    title: 'AI-Powered',
    highlightedText: 'Diagnosis',
    description: 'Describe your home issue and let our intelligence find the fix.',
    iconName: 'psychology',
    pageIndex: 0,
  ),
  const OnboardingPage(
    title: 'Elite',
    highlightedText: 'Technicians',
    description: 'Connect with certified pros in minutes. Simple, fast, reliable.',
    iconName: 'engineering',
    pageIndex: 1,
  ),
  const OnboardingPage(
    title: 'Full Home',
    highlightedText: 'Control',
    description: 'Manage your smart home devices from one unified dashboard.',
    iconName: 'wb_iridescent',
    pageIndex: 2,
  ),
];
