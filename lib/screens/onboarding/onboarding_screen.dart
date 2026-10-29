import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/language_provider.dart';
import '../../l10n/supported_language.dart';
import '../../services/appwrite_content_service.dart';
import '../../services/onboarding_service.dart';
import '../../utils/responsive_utils.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _dynamicContent;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Welcome to ALIVE Nigeria',
      'body':
          'Join our vibrant community united by Prayer, Study, Missions, and Health.',
      'icon': Icons.public,
      'color': null,
    },
    {
      'title': 'Roles & Organization',
      'body':
          'We are organized to serve! From dedicated Members and Chapter Leaders to Coordinators, Directors, and BODs, every role is vital.',
      'icon': Icons.groups,
      'color': Colors.indigo,
    },
    {
      'title': 'Tagging, Praying & Chatting',
      'body':
          'Stay deeply connected. Tag members, join chapter chats, pray together instantly, and share your powerful testimonies with the community.',
      'icon': Icons.chat_bubble_outline,
      'color': Colors.teal,
    },
    {
      'title': 'Kids & Discipleship',
      'body':
          'A rich library of Books, Tracts, and Podcasts awaits you. Plus special mission activities and Bible memorization features for both Kids and Adults.',
      'icon': Icons.menu_book,
      'color': Colors.orange,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDynamicContent();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDynamicContent() async {
    setState(() => _isLoading = true);
    try {
      final currentLocale = ref.read(localeProvider);
      final languageCode = currentLocale.languageCode;
      final contentData =
          await AppwriteContentService.instance.getContentPageBySlug(
        'onboarding',
        languageCode: languageCode,
      );
      if (!mounted) return;
      setState(() {
        _dynamicContent = contentData?['content']?.toString();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _next() async {
    await OnboardingService.complete();
    if (mounted) context.go('/oath');
  }

  void _skip() {
    // Skip jumps straight to the final step so the user can review the
    // last card before continuing.
    _pageController.animateToPage(
      _steps.length - 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Getting Started',
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          if (_currentPage < _steps.length - 1)
            TextButton(
              onPressed: _skip,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: context.responsivePadding,
        child: Column(
          children: [
            if (_isLoading) const LinearProgressIndicator(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  final currentLocale = ref.watch(localeProvider);
                  return _OnboardingCard(
                    title: step['title'] as String,
                    body: step['body'] as String,
                    icon: step['icon'] as IconData,
                    iconColor: (step['color'] as Color?) ??
                        Theme.of(context).colorScheme.primary,
                    extra: index == _steps.length - 1 ? _dynamicContent : null,
                    isFirstCard: index == 0,
                    selectedLanguageCode: currentLocale.languageCode,
                    onLanguageSelected: (code) {
                      ref.read(localeProvider.notifier).setLocale(code);
                      _loadDynamicContent();
                    },
                  );
                },
              ),
            ),
            // Progress dots indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) {
                    final isSelected = _currentPage == index;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isSelected ? 24 : 8,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Action button: Next on slides, Get Started on last slide
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _steps.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _next();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentPage < _steps.length - 1
                            ? 'Next'
                            : 'Get Started',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _currentPage < _steps.length - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: context.responsivePadding.top / 2),
          ],
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color iconColor;
  final String? extra;
  final bool isFirstCard;
  final String? selectedLanguageCode;
  final ValueChanged<String>? onLanguageSelected;

  const _OnboardingCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.iconColor,
    this.extra,
    this.isFirstCard = false,
    this.selectedLanguageCode,
    this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 80, color: iconColor),
                ),
                SizedBox(height: context.responsivePadding.top * 1.5),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: context.responsiveFontSize(24),
                      ),
                ),
                SizedBox(height: context.responsivePadding.top),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: context.responsiveFontSize(16),
                        height: 1.6,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.8),
                      ),
                ),
                if (isFirstCard) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.translate_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Choose Language / Zaɓi Harshe / Yan Èdè / Họrọ Asụsụ',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: SupportedLanguage.values.map((lang) {
                            final isSelected = (selectedLanguageCode ?? 'en') == lang.code;
                            return ChoiceChip(
                              selected: isSelected,
                              label: Text(
                                lang.name,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              avatar: isSelected
                                  ? const Icon(Icons.check_circle_rounded, size: 16)
                                  : CircleAvatar(
                                      radius: 8,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.15),
                                      child: Text(
                                        lang.code.toUpperCase(
                                        ),
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                              onSelected: (_) => onLanguageSelected?.call(lang.code),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                if (extra != null && extra!.trim().isNotEmpty) ...[
                  SizedBox(height: context.responsivePadding.top),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      extra!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}



