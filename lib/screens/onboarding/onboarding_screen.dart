import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/onboarding_service.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Welcome to ALIVE Nigeria',
      'body':
          'Join our vibrant community united in deep Prayer, Scripture Study, Campus & Global Missions, and Wholistic Health.',
      'icon': Icons.sentiment_very_satisfied,
      'color': const Color(0xFFD49B28),
    },
    {
      'title': 'Evangelism & Gospel Tracts',
      'body':
          'In need of evangelism tracts? Access an uplifting library of gospel tracts ready for outreach. Easy to download and print for field evangelism, or share instantly in softcopy with friends and seekers.',
      'icon': Icons.library_books_rounded,
      'color': const Color(0xFF0D9488),
    },
    {
      'title': 'Roles & Organization',
      'body':
          'We are organized to serve! From dedicated Members and Chapter Leaders to Coordinators, Directors, and BODs, every role is vital.',
      'icon': Icons.groups_rounded,
      'color': Colors.indigo,
    },
    {
      'title': 'Praying & Chatting',
      'body':
          'Stay deeply connected. Tag members, join chapter chats, pray together instantly, and share your powerful testimonies with the community.',
      'icon': Icons.chat_bubble_outline_rounded,
      'color': Colors.teal,
    },
    {
      'title': 'Kids & Discipleship',
      'body':
          'Grow in Christ through interactive discipleship lessons, audio podcasts, and children’s mission adventures with illustrated Bible stories and memory verses.',
      'icon': Icons.child_care_rounded,
      'color': Colors.orange,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
      appBar: CustomAppBar(
        title: 'Getting Started',
        showBackButton: false,
        showDonationButton: false,
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
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 24),
        child: Padding(
          padding: context.responsivePadding,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return _OnboardingCard(
                      title: step['title'] as String,
                      body: step['body'] as String,
                      icon: step['icon'] as IconData,
                      iconColor: (step['color'] as Color?) ??
                          Theme.of(context).colorScheme.primary,
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
            ],
          ),
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

  const _OnboardingCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.center,
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Welcoming Hero Icon Container with warm layered glow
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        iconColor.withValues(alpha: isDark ? 0.28 : 0.16),
                        iconColor.withValues(alpha: isDark ? 0.08 : 0.04),
                      ],
                    ),
                    border: Border.all(
                      color: iconColor.withValues(alpha: isDark ? 0.45 : 0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: isDark ? 0.25 : 0.12),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 68,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: context.responsiveFontSize(26),
                        letterSpacing: -0.5,
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: context.responsiveFontSize(16),
                          height: 1.6,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



