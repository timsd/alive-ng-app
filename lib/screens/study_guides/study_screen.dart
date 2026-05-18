import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';
import 'package:go_router/go_router.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/app_models.dart';
import '../../constants/app_constants.dart';
import '../../utils/text_formatter.dart';
import '../../utils/responsive_utils.dart';
import '../../services/appwrite_study_service.dart';

// Provider for study programs
final studyProgramsProvider = FutureProvider<List<StudyProgram>>((ref) async {
  return AppwriteStudyService.instance.getStudyPrograms();
});

// Provider for user's study progress
final studyProgressProvider = FutureProvider<List<StudyProgress>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return <StudyProgress>[];
  return AppwriteStudyService.instance.getUserStudyProgress(user.uid);
});

class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    final studyProgramsAsync = ref.watch(studyProgramsProvider);
    final studyProgressAsync = ref.watch(studyProgressProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: translate('study'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        showThemeToggle: true,
        showLanguageToggle: true,
        showDonationButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studyProgramsProvider);
          ref.invalidate(studyProgressProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Container(
                width: double.infinity,
                padding:
                    ResponsiveUtils.getResponsivePaddingWithBase(context, 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(
                        ResponsiveUtils.getResponsiveBorderRadiusValue(
                            context, 24)),
                    bottomRight: Radius.circular(
                        ResponsiveUtils.getResponsiveBorderRadiusValue(
                            context, 24)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TextFormatter.formatActivityType('bible_study'),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 8)),
                    Text(
                      TextFormatter.formatText('grow_in_faith'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

              // Progress Overview
              studyProgressAsync.when(
                data: (progress) =>
                    _buildProgressOverview(context, translate, progress),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    _buildErrorWidget(context, translate, error.toString()),
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

              // Bible Reader Card (accessible to all users)
              _buildBibleReaderCard(context, translate),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

              // Bible Game Card
              _buildBibleGameCard(context, translate),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

              // Study Programs
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal:
                        ResponsiveUtils.getResponsiveSpacing(context, 20)),
                child: Text(
                  TextFormatter.formatActivityType('study_programs'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 16)),

              studyProgramsAsync.when(
                data: (programs) =>
                    _buildStudyPrograms(context, translate, programs),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    _buildErrorWidget(context, translate, error.toString()),
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBibleReaderCard(
      BuildContext context, String Function(String) translate) {
    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context, 20)),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
        ),
        child: InkWell(
          onTap: () => context.go(AppConstants.bibleRoute),
          borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
          child: Container(
            padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 20),
            child: Row(
              children: [
                Container(
                  padding:
                      ResponsiveUtils.getResponsivePaddingWithBase(context, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getResponsiveBorderRadiusValue(
                            context, 12)),
                  ),
                  child: Icon(
                    Icons.menu_book,
                    color: Theme.of(context).colorScheme.primary,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 32),
                  ),
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translate('bible'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      SizedBox(
                          height:
                              ResponsiveUtils.getResponsiveSpacing(context, 6)),
                      Text(
                        translate('read_bible'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveUtils.getResponsiveIconSize(context, 18),
                  color: Theme.of(context).colorScheme.primary,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBibleGameCard(
      BuildContext context, String Function(String) translate) {
    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context, 20)),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
        ),
        child: InkWell(
          onTap: () => context.go(AppConstants.bibleGameRoute),
          borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
          child: Container(
            padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      ResponsiveUtils.getResponsivePaddingWithBase(context, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getResponsiveBorderRadiusValue(
                            context, 12)),
                  ),
                  child: Icon(
                    Icons.games,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 32),
                  ),
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bible Memorization Game',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context, 18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                          height:
                              ResponsiveUtils.getResponsiveSpacing(context, 4)),
                      Text(
                        'Learn verses with voice recitation and fill-in-the-gap exercises',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context, 14),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: ResponsiveUtils.getResponsiveIconSize(context, 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressOverview(BuildContext context,
      String Function(String) translate, List<StudyProgress> progress) {
    final completedLessons =
        progress.fold<int>(0, (sum, p) => sum + p.completedLessons);
    final totalLessons = progress.length;
    final progressPercentage =
        totalLessons > 0 ? (completedLessons / totalLessons) : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context, 20)),
      padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TextFormatter.formatText('your_progress'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completedLessons / $totalLessons ${TextFormatter.formatActivityType('lessons_completed')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 8)),
                    LinearProgressIndicator(
                      value: progressPercentage,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                  width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
              CircularProgressIndicator(
                value: progressPercentage,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudyPrograms(BuildContext context,
      String Function(String) translate, List<StudyProgram> programs) {
    if (programs.isEmpty) {
      return Container(
        margin: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getResponsiveSpacing(context, 20)),
        padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: ResponsiveUtils.getResponsiveIconSize(context, 48),
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
            Text(
              TextFormatter.formatText('no_study_programs'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context, 20)),
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final program = programs[index];
        return StudyProgramCard(
          program: program,
          onTap: () {
            _navigateToProgramDetails(context, program);
          },
        );
      },
    );
  }

  Widget _buildErrorWidget(
      BuildContext context, String Function(String) translate, String error) {
    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context, 20)),
      padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: ResponsiveUtils.getResponsiveIconSize(context, 48),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          Text(
            TextFormatter.formatText('error_loading_data'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToProgramDetails(BuildContext context, dynamic program) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(program.title ?? 'Study Program'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Program Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 16)),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
              Text(program.description ??
                  'Detailed study program with comprehensive lessons and activities.'),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
              Text(
                'Includes:',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              const Text('• Interactive lessons and quizzes'),
              const Text('• Progress tracking'),
              const Text('• Discussion forums'),
              const Text('• Certificate upon completion'),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
              Container(
                padding:
                    ResponsiveUtils.getResponsivePaddingWithBase(context, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getResponsiveBorderRadiusValue(
                          context, 8)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                    SizedBox(
                        width:
                            ResponsiveUtils.getResponsiveSpacing(context, 8)),
                    Expanded(
                      child: Text(
                        'This program includes multiple modules and assessments.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Starting program: ${program.title ?? "Study Program"}'),
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                ),
              );
            },
            child: const Text('Start Program'),
          ),
        ],
      ),
    );
  }
}

class StudyProgramCard extends StatelessWidget {
  final StudyProgram program;
  final VoidCallback onTap;

  const StudyProgramCard({
    super.key,
    required this.program,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 16)),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
        child: Padding(
          padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: ResponsiveUtils.getResponsivePaddingWithBase(
                        context, 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveBorderRadiusValue(
                              context, 8)),
                    ),
                    child: Icon(
                      Icons.menu_book,
                      color: Theme.of(context).colorScheme.primary,
                      size: ResponsiveUtils.getResponsiveIconSize(context, 24),
                    ),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        if (program.description.isNotEmpty)
                          Text(
                            program.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(context).colorScheme.primary,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                  ),
                ],
              ),
              if (program.duration > 0) ...[
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                    SizedBox(
                        width:
                            ResponsiveUtils.getResponsiveSpacing(context, 4)),
                    Text(
                      '${program.duration} days',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
