import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/health_nuggets_data.dart';
import '../../../utils/responsive_utils.dart';

/// Displays the daily rotating 365-day Seventh-day Adventist Health Nugget
/// on `/health`, with prev/next day browsing, sharing, and a full 365-day
/// searchable NEWSTART directory sheet.
class DailyHealthNuggetCard extends StatefulWidget {
  const DailyHealthNuggetCard({super.key});

  @override
  State<DailyHealthNuggetCard> createState() => _DailyHealthNuggetCardState();
}

class _DailyHealthNuggetCardState extends State<DailyHealthNuggetCard> {
  late final int _todayDay;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _todayDay =
        ((HealthNuggetsData.dayOfYear(DateTime.now()) - 1) %
            HealthNuggetsData.allNuggets.length) +
        1;
    _selectedDay = _todayDay;
  }

  HealthNugget get _currentNugget =>
      HealthNuggetsData.nuggetForDay(_selectedDay);

  void _stepDay(int delta) {
    final total = HealthNuggetsData.allNuggets.length;
    setState(() {
      _selectedDay = ((_selectedDay - 1 + delta) % total + total) % total + 1;
    });
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Nutrition':
        return const Color(0xFF2E7D32);
      case 'Exercise':
        return const Color(0xFF1565C0);
      case 'Water':
        return const Color(0xFF00838F);
      case 'Sunlight':
        return const Color(0xFFEF6C00);
      case 'Temperance':
        return const Color(0xFFAB47BC);
      case 'Air':
        return const Color(0xFF00695C);
      case 'Rest':
        return const Color(0xFF5C6BC0);
      case 'Trust in God':
        return const Color(0xFFB71C1C);
      default:
        return const Color(0xFF059669);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Nutrition':
        return Icons.restaurant_outlined;
      case 'Exercise':
        return Icons.directions_walk_outlined;
      case 'Water':
        return Icons.water_drop_outlined;
      case 'Sunlight':
        return Icons.wb_sunny_outlined;
      case 'Temperance':
        return Icons.balance_outlined;
      case 'Air':
        return Icons.air_outlined;
      case 'Rest':
        return Icons.bedtime_outlined;
      case 'Trust in God':
        return Icons.favorite_outline;
      default:
        return Icons.health_and_safety_outlined;
    }
  }

  void _shareNugget(HealthNugget nugget) {
    final text =
        'ALIVE Nigeria Daily Health Nugget (${nugget.category})\n\n'
        '"${nugget.title}"\n'
        '${nugget.nugget}\n\n'
        '— ${nugget.speaker} (${nugget.scripture})\n\n'
        'Read more on ALIVE Nigeria: https://app.alivenigeria.org/health';
    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Daily Health Nugget: ${nugget.title}',
      ),
    );
  }

  void _openBrowseSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _BrowseNuggetsSheet(
        todayDay: _todayDay,
        selectedDay: _selectedDay,
        categoryColor: _categoryColor,
        categoryIcon: _categoryIcon,
        onSelectDay: (day) {
          setState(() => _selectedDay = day);
          Navigator.of(sheetCtx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nugget = _currentNugget;
    final accent = _categoryColor(nugget.category);
    final isToday = _selectedDay == _todayDay;

    return Container(
      margin: ResponsiveUtils.getResponsiveHorizontalPadding(context),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar: Day badge + NEWSTART pill + Share
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_categoryIcon(nugget.category),
                          size: 15, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        '${nugget.category} • Day ${nugget.day}/${HealthNuggetsData.allNuggets.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!isToday)
                  TextButton(
                    onPressed: () => setState(() => _selectedDay = _todayDay),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Today'),
                  ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  tooltip: 'Share Health Nugget',
                  onPressed: () => _shareNugget(nugget),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              nugget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              nugget.nugget,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: colorScheme.onSurface.withValues(alpha: 0.88),
              ),
            ),

            const SizedBox(height: 12),

            // Speaker + Scripture attribution
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.record_voice_over_outlined,
                          size: 15, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          nugget.speaker,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 15, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        nugget.scripture,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Footer navigation: Prev / Browse 365 / Next
            Row(
              children: [
                IconButton.outlined(
                  onPressed: () => _stepDay(-1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous Day',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openBrowseSheet,
                    icon: const Icon(Icons.auto_stories_outlined, size: 18),
                    label: const Text(
                      'All Nuggets',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => _stepDay(1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next Day',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowseNuggetsSheet extends StatefulWidget {
  final int todayDay;
  final int selectedDay;
  final Color Function(String) categoryColor;
  final IconData Function(String) categoryIcon;
  final ValueChanged<int> onSelectDay;

  const _BrowseNuggetsSheet({
    required this.todayDay,
    required this.selectedDay,
    required this.categoryColor,
    required this.categoryIcon,
    required this.onSelectDay,
  });

  @override
  State<_BrowseNuggetsSheet> createState() => _BrowseNuggetsSheetState();
}

class _BrowseNuggetsSheetState extends State<_BrowseNuggetsSheet> {
  String _selectedCategory = 'All';
  String _query = '';

  List<HealthNugget> get _filtered {
    final q = _query.trim().toLowerCase();
    return HealthNuggetsData.allNuggets.where((n) {
      if (_selectedCategory != 'All' && n.category != _selectedCategory) {
        return false;
      }
      if (q.isEmpty) return true;
      return n.title.toLowerCase().contains(q) ||
          n.nugget.toLowerCase().contains(q) ||
          n.speaker.toLowerCase().contains(q) ||
          n.scripture.toLowerCase().contains(q) ||
          'day ${n.day}'.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = _filtered;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  '${HealthNuggetsData.allNuggets.length} Adventist Health Nuggets',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.length} shown',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search topic, speaker, or scripture...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: HealthNuggetsData.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = HealthNuggetsData.categories[i];
                final selected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final accent = widget.categoryColor(item.category);
                final isToday = item.day == widget.todayDay;
                final isSelected = item.day == widget.selectedDay;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: isSelected
                        ? BorderSide(color: accent, width: 1.5)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    onTap: () => widget.onSelectDay(item.day),
                    leading: CircleAvatar(
                      backgroundColor: accent.withValues(alpha: 0.14),
                      child: Icon(
                        widget.categoryIcon(item.category),
                        color: accent,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Today',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          item.nugget,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Day ${item.day} • ${item.category} • ${item.speaker}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
