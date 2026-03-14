import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/onboarding_service.dart';
import '../../utils/responsive_utils.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _step = 0;
  String? _dynamicContent;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Welcome to ALIVE Nigeria',
      'body': 'Join our vibrant community united by Prayer, Study, Missions, and Health.',
      'icon': Icons.public,
      'color': null, // default primary
    },
    {
      'title': 'Roles & Organization',
      'body': 'We are organized to serve! From dedicated Members and Chapter Leaders to Coordinators, Directors, and BODs, every role is vital.',
      'icon': Icons.groups,
      'color': Colors.indigo,
    },
    {
      'title': 'Tagging, Praying & Chatting',
      'body': 'Stay deeply connected. Tag members, join chapter chats, pray together instantly, and share your powerful testimonies with the community.',
      'icon': Icons.chat_bubble_outline,
      'color': Colors.teal,
    },
    {
      'title': 'Kids & Discipleship',
      'body': 'A rich library of Books, Tracts, and Podcasts awaits you. Plus, special mission activities and Bible memorization features for both Kids and Adults to grow as true Disciples of Christ.',
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
      final firebaseService = ref.read(firebaseDatabaseServiceProvider);
      final contentData = await firebaseService.getContentPageBySlug(
        'onboarding',
        languageCode: languageCode,
      );
      if (!mounted) return;
      setState(() {
        _dynamicContent = contentData?['content']?.toString();
      });
    } catch (_) {
      // keep static onboarding fallback
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _next() async {
    if (_step < _steps.length - 1) {
      final next = _step + 1;
      await _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      return;
    }
    await OnboardingService.complete();
    if (mounted) {
      context.go(AppConstants.homeRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Getting Started')),
      body: Padding(
        padding: context.responsivePadding,
        child: Column(
          children: [
            if (_isLoading) const LinearProgressIndicator(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) => setState(() => _step = index),
                itemBuilder: (context, index) {
                  final item = _steps[index];
                  return _OnboardingCard(
                    title: item['title'] as String,
                    body: item['body'] as String,
                    icon: item['icon'] as IconData,
                    iconColor: (item['color'] as Color?) ?? Theme.of(context).colorScheme.primary,
                    extra: index == 0 ? _dynamicContent : null,
                  );
                },
              ),
            ),
            SizedBox(height: context.responsivePadding.top / 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                final active = i == _step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),
            SizedBox(height: context.responsivePadding.top),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _next,
                    child: Text(
                      _step < _steps.length - 1 ? 'Next' : 'Get Started',
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.responsivePadding.top / 2),
            Center(
              child: TextButton(
                onPressed: () => context.go(AppConstants.authRoute),
                child: const Text('Sign In'),
              ),
            ),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                child: Icon(
                  icon,
                  size: 80,
                  color: iconColor,
                ),
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
              ),
              if (extra != null && extra!.trim().isNotEmpty) ...[
                SizedBox(height: context.responsivePadding.top),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
    );
  }
}

