import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/language_provider.dart';
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
        title: const Text('Getting Started'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(
              'Skip',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
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
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return _OnboardingCard(
                    title: step['title'] as String,
                    body: step['body'] as String,
                    icon: step['icon'] as IconData,
                    iconColor: (step['color'] as Color?) ??
                        Theme.of(context).colorScheme.primary,
                    extra: index == _steps.length - 1 ? _dynamicContent : null,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Get Started'),
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

  const _OnboardingCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.iconColor,
    this.extra,
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



