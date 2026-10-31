import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/custom_app_bar.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_constants.dart';
import '../../utils/text_formatter.dart';
import '../../utils/responsive_utils.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: CustomAppBar(
        title: l10n.study,
        showBackButton: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        showThemeToggle: true,
        showLanguageToggle: true,
        showDonationButton: true,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: ResponsiveUtils.getResponsivePadding(context),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TextFormatter.formatText('grow_in_faith'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withValues(alpha: 0.95),
                          fontWeight: FontWeight.w500,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context, 16),
                        ),
                  ),
                ],
              ),
            ),

            SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

            // Bible Reader Card (accessible to all users)
            _buildBibleReaderCard(context),

            SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context, 16)),

            // Instant Word Card
            _buildBibleGameCard(context),

            SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context, 16)),

            // Study Guides Card (Includes Lessons, Progress Tracking & Statistics)
            _buildStudyGuidesCard(context),

            SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context, 28)),
          ],
        ),
      ),
    );
  }

  Widget _buildBibleReaderCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                        l10n.bible,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      SizedBox(
                          height:
                              ResponsiveUtils.getResponsiveSpacing(context, 6)),
                      Text(
                        l10n.read_bible,
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

  Widget _buildBibleGameCard(BuildContext context) {
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
                    Icons.sports_esports_rounded,
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
                        'Instant Word',
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
                        'Memorize, Recall, Overcome',
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

  Widget _buildStudyGuidesCard(BuildContext context) {
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
          onTap: () => context.push(AppConstants.studyGuideRoute),
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
                    Icons.library_books_rounded,
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
                        'Study Guides',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      SizedBox(
                          height:
                              ResponsiveUtils.getResponsiveSpacing(context, 6)),
                      Text(
                        'Structured Bible lessons, progress tracking & statistics',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveUtils.getResponsiveIconSize(context, 18),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
