import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/onboarding_service.dart';
import '../../utils/responsive_utils.dart';
import '../../constants/app_constants.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  String? _dynamicContent;
  bool _isLoading = false;
  final List<Map<String, String>> _steps = [
    {
      'title': 'Welcome to ALIVE Nigeria',
      'body': 'Join prayer, study, missions, health tracking and more.'
    },
    {
      'title': 'Stay Connected',
      'body': 'Follow chapters, join events, and share testimonies.'
    },
    {
      'title': 'Admin & Kids Content',
      'body': 'Admins manage content; kids enjoy curated resources.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDynamicContent();
  }

  Future<void> _loadDynamicContent() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final currentLocale = ref.read(localeProvider);
      final languageCode = currentLocale.languageCode;
      final firebaseService = ref.read(firebaseDatabaseServiceProvider);
      final contentData = await firebaseService.getContentPageBySlug(
        'onboarding',
        languageCode: languageCode,
      );
      if (mounted) {
        setState(() {
          _dynamicContent = contentData?['content'];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _next() async {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      await OnboardingService.complete();
      if (mounted) {
        context.go(AppConstants.homeRoute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _steps[_step];
    return Scaffold(
      appBar: AppBar(title: const Text('Getting Started')),
      body: Padding(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const LinearProgressIndicator(),
            if (_dynamicContent != null && _dynamicContent!.isNotEmpty) ...[
              Text(
                'Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: context.responsiveFontSize(18),
                ),
              ),
              SizedBox(height: context.responsivePadding.top / 2),
              Text(
                _dynamicContent!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: context.responsiveFontSize(16),
                  height: 1.6,
                ),
              ),
              SizedBox(height: context.responsivePadding.top),
            ],
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tagging Guide',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: context.responsiveFontSize(18),
                    ),
                  ),
                  SizedBox(height: context.responsivePadding.top / 3),
                  Text(
                    'Use tags to reach the right audience:',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: context.responsiveFontSize(15),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Role tags (#): #bod, #director, #chap_coor, #media, #tech, #chapter_lagos',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Individual tags (@): @username, @firstname.lastname',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Special tags: #all, #online, #active, #new, #meeting, #event_[name]',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Visibility follows hierarchy (e.g. #bod sees all), peers (directors ↔ directors), and team membership (chapters, ministries).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
            Text(
              current['title']!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: context.responsiveFontSize(22),
              ),
            ),
            SizedBox(height: context.responsivePadding.top),
            Text(
              current['body']!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: context.responsiveFontSize(16),
                height: 1.6,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _next,
                    child: Text(_step < _steps.length - 1 ? 'Next' : 'Get Started'),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.responsivePadding.top / 2),
            Center(
              child: TextButton(
                onPressed: () {
                  context.go(AppConstants.authRoute);
                },
                child: const Text('Sign In'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
