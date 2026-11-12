import 'package:flutter/material.dart';

/// Model representing an interactive metric pill (Option 3 for Admin UX).
/// Displays a label, an optional live record count (e.g. "4"), an optional
/// color accent, and an optional icon.
class AdminMetricPill<T> {
  final String label;
  final T value;
  final int? count;
  final Color? color;
  final IconData? icon;

  const AdminMetricPill({
    required this.label,
    required this.value,
    this.count,
    this.color,
    this.icon,
  });
}

/// A compact dropdown pill for secondary filter dimensions
/// (e.g., Mode, Timeframe, Chapter).
class AdminDropdownPill<T> extends StatelessWidget {
  final String label;
  final T selectedValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;

  const AdminDropdownPill({
    super.key,
    required this.label,
    required this.selectedValue,
    required this.items,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedItem = items.firstWhere(
      (i) => i.value == selectedValue,
      orElse: () => items.first,
    );

    return PopupMenuButton<T>(
      initialValue: selectedValue,
      tooltip: label,
      onSelected: (val) => onChanged(val),
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem<T>(
              value: item.value,
              child: item.child,
            ),
          )
          .toList(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 5),
            ],
            Text(
              '$label: ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: DefaultTextStyle(
                style: theme.textTheme.labelSmall!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                child: selectedItem.child,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Standardized, space-efficient, and interactive Admin Filter & Metric Header.
/// Replaces sprawling, screen-hogging filter cards across Admin pages with:
/// 1. Compact Search bar
/// 2. Compact dropdown pills row (e.g. Mode, Chapter, Timeframe)
/// 3. Horizontal scrolling interactive Metric Summary Pills (Option 3)
class AdminFilterHeader<T> extends StatelessWidget {
  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchCleared;

  final List<AdminDropdownPill>? dropdownFilters;
  final List<AdminMetricPill<T>> metricPills;
  final T selectedMetric;
  final ValueChanged<T> onSelectMetric;

  final VoidCallback? onClearAllFilters;
  final bool hasActiveNonDefaultFilters;
  final Widget? trailingAction;

  const AdminFilterHeader({
    super.key,
    this.searchController,
    this.searchHint = 'Search...',
    this.onSearchChanged,
    this.onSearchCleared,
    this.dropdownFilters,
    this.metricPills = const [],
    required this.selectedMetric,
    required this.onSelectMetric,
    this.onClearAllFilters,
    this.hasActiveNonDefaultFilters = false,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: searchHint,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    suffixIcon: (searchController?.text.isNotEmpty ?? false)
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              searchController?.clear();
                              onSearchCleared?.call();
                              onSearchChanged?.call('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              if (trailingAction != null) ...[
                const SizedBox(width: 8),
                trailingAction!,
              ],
            ],
          ),

          // 2. Secondary Dropdown Pills (e.g. Mode, Timeframe, Chapter)
          if ((dropdownFilters != null && dropdownFilters!.isNotEmpty) || hasActiveNonDefaultFilters) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (dropdownFilters != null)
                    ...dropdownFilters!.map(
                      (pill) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: pill,
                      ),
                    ),
                  if (hasActiveNonDefaultFilters && onClearAllFilters != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: onClearAllFilters,
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 14),
                      label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],

          // 3. Option 3: Interactive Metric Summary Pills (Horizontal scrollable)
          if (metricPills.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: metricPills.map((pill) {
                  final isSelected = pill.value == selectedMetric;
                  final pillColor = pill.color ?? theme.colorScheme.primary;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => onSelectMetric(pill.value),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? pillColor.withValues(alpha: 0.18)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? pillColor
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (pill.icon != null) ...[
                              Icon(
                                pill.icon,
                                size: 14,
                                color: isSelected ? pillColor : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                            ] else if (pill.color != null) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: pill.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              pill.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? pillColor : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (pill.count != null) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? pillColor
                                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${pill.count}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

