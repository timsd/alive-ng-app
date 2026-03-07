import 'package:flutter/material.dart';
import 'responsive_utils.dart';
import 'theme_icon_utils.dart';
import 'dart:math' as math;

/// Utility class for auto-arranging feature icons and widgets
class AutoArrangeUtils {
  /// Calculate optimal grid count based on screen size and item count
  static int calculateOptimalGridCount({
    required BuildContext context,
    required int itemCount,
    int? minColumns,
    int? maxColumns,
  }) {
    final screenType = ResponsiveUtils.getScreenType(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Base columns based on screen type
    int baseColumns;
    switch (screenType) {
      case ScreenType.mobile:
        baseColumns = 2;
        break;
      case ScreenType.tablet:
        baseColumns = 3;
        break;
      case ScreenType.desktop:
        baseColumns = 4;
        break;
    }
    
    // Adjust based on screen width for fine-tuning
    if (screenWidth < 360) {
      baseColumns = math.max(1, baseColumns - 1);
    } else if (screenWidth > 800) {
      baseColumns = math.min(6, baseColumns + 1);
    }
    
    // Apply min/max constraints
    if (minColumns != null) {
      baseColumns = math.max(minColumns, baseColumns);
    }
    if (maxColumns != null) {
      baseColumns = math.min(maxColumns, baseColumns);
    }
    
    // Ensure we don't have more columns than items
    return math.min(baseColumns, itemCount);
  }
  
  /// Calculate optimal item size for grid items
  static double calculateOptimalItemSize({
    required BuildContext context,
    required int gridCount,
    double padding = 16.0,
    double spacing = 8.0,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - (padding * 2) - (spacing * (gridCount - 1));
    return availableWidth / gridCount;
  }
  
  /// Create auto-arranged grid of feature items
  static Widget createAutoArrangedGrid({
    required BuildContext context,
    required List<FeatureItem> items,
    int? minColumns,
    int? maxColumns,
    double padding = 16.0,
    double spacing = 8.0,
    double? aspectRatio,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final gridCount = calculateOptimalGridCount(
      context: context,
      itemCount: items.length,
      minColumns: minColumns,
      maxColumns: maxColumns,
    );
    
    return Padding(
      padding: EdgeInsets.all(padding),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: aspectRatio ?? 1.0,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildFeatureItemWidget(context, items[index]);
        },
      ),
    );
  }
  
  /// Create auto-arranged wrap of feature items
  static Widget createAutoArrangedWrap({
    required BuildContext context,
    required List<FeatureItem> items,
    double padding = 16.0,
    double spacing = 8.0,
    double runSpacing = 8.0,
    WrapAlignment alignment = WrapAlignment.center,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Wrap(
        alignment: alignment,
        spacing: spacing,
        runSpacing: runSpacing,
        children: items.map((item) => _buildFeatureItemWidget(context, item)).toList(),
      ),
    );
  }
  
  /// Create auto-arranged list of feature items
  static Widget createAutoArrangedList({
    required BuildContext context,
    required List<FeatureItem> items,
    double padding = 16.0,
    double spacing = 8.0,
    bool scrollable = true,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: EdgeInsets.all(padding),
      child: ListView.separated(
        shrinkWrap: !scrollable,
        physics: scrollable ? null : const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => SizedBox(height: spacing),
        itemBuilder: (context, index) {
          return _buildFeatureListItemWidget(context, items[index]);
        },
      ),
    );
  }
  
  /// Build individual feature item widget for grid/wrap
  static Widget _buildFeatureItemWidget(BuildContext context, FeatureItem item) {
    final itemSize = ResponsiveUtils.getResponsiveIconSize(context, 48.0);
    
    return ThemeIconUtils.createThemeContainer(
      context: context,
      elevation: 2.0,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveBorderRadiusValue(context, 8)),
        child: Padding(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.icon != null)
                ThemeIconUtils.createThemeIcon(
                  context: context,
                  icon: item.icon!,
                  size: itemSize,
                  lightColor: item.lightIconColor,
                  darkColor: item.darkIconColor,
                ),
              if (item.customIcon != null) item.customIcon!,
              if (item.icon != null || item.customIcon != null)
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8.0)),
              Flexible(
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12.0),
                    fontWeight: FontWeight.w500,
                    color: ThemeIconUtils.getTextColor(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.subtitle != null) ...[
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 4.0)),
                Flexible(
                  child: Text(
                    item.subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, 10.0),
                      color: ThemeIconUtils.getTextColor(context, type: TextColorType.secondary),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build individual feature item widget for list
  static Widget _buildFeatureListItemWidget(BuildContext context, FeatureItem item) {
    return ThemeIconUtils.createThemeContainer(
      context: context,
      elevation: 1.0,
      child: ListTile(
        leading: item.icon != null
            ? ThemeIconUtils.createThemeIcon(
                context: context,
                icon: item.icon!,
                size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
                lightColor: item.lightIconColor,
                darkColor: item.darkIconColor,
              )
            : item.customIcon,
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16.0),
            fontWeight: FontWeight.w500,
            color: ThemeIconUtils.getTextColor(context),
          ),
        ),
        subtitle: item.subtitle != null
            ? Text(
                item.subtitle!,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14.0),
                  color: ThemeIconUtils.getTextColor(context, type: TextColorType.secondary),
                ),
              )
            : null,
        trailing: item.showArrow
            ? ThemeIconUtils.createThemeIcon(
                context: context,
                icon: Icons.arrow_forward_ios,
                size: ResponsiveUtils.getResponsiveIconSize(context, 16.0),
              )
            : null,
        onTap: item.onTap,
        contentPadding: ResponsiveUtils.getResponsivePadding(context),
      ),
    );
  }
  
  /// Sort feature items by priority and usage
  static List<FeatureItem> sortFeatureItems(List<FeatureItem> items) {
    return List.from(items)..sort((a, b) {
      // Sort by priority first (high to low)
      final priorityComparison = b.priority.index.compareTo(a.priority.index);
      if (priorityComparison != 0) return priorityComparison;
      
      // Then by usage count (high to low)
      final usageComparison = b.usageCount.compareTo(a.usageCount);
      if (usageComparison != 0) return usageComparison;
      
      // Finally by title alphabetically
      return a.title.compareTo(b.title);
    });
  }
  
  /// Filter feature items based on search query
  static List<FeatureItem> filterFeatureItems(List<FeatureItem> items, String query) {
    if (query.isEmpty) return items;
    
    final lowercaseQuery = query.toLowerCase();
    return items.where((item) {
      return item.title.toLowerCase().contains(lowercaseQuery) ||
             (item.subtitle?.toLowerCase().contains(lowercaseQuery) ?? false) ||
             item.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }
  
  /// Group feature items by category
  static Map<String, List<FeatureItem>> groupFeatureItems(List<FeatureItem> items) {
    final Map<String, List<FeatureItem>> grouped = {};
    
    for (final item in items) {
      final category = item.category ?? 'Other';
      grouped.putIfAbsent(category, () => []).add(item);
    }
    
    return grouped;
  }
  
  /// Create categorized feature sections
  static Widget createCategorizedFeatures({
    required BuildContext context,
    required List<FeatureItem> items,
    ArrangementType arrangementType = ArrangementType.grid,
    bool showCategoryHeaders = true,
  }) {
    final groupedItems = groupFeatureItems(items);
    final sortedCategories = groupedItems.keys.toList()..sort();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedCategories.map((category) {
        final categoryItems = sortFeatureItems(groupedItems[category]!);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showCategoryHeaders) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, 18.0),
                    fontWeight: FontWeight.bold,
                    color: ThemeIconUtils.getTextColor(context),
                  ),
                ),
              ),
            ],
            _buildArrangedItems(context, categoryItems, arrangementType),
            const SizedBox(height: 16.0),
          ],
        );
      }).toList(),
    );
  }
  
  /// Build arranged items based on arrangement type
  static Widget _buildArrangedItems(
    BuildContext context,
    List<FeatureItem> items,
    ArrangementType arrangementType,
  ) {
    switch (arrangementType) {
      case ArrangementType.grid:
        return createAutoArrangedGrid(context: context, items: items);
      case ArrangementType.wrap:
        return createAutoArrangedWrap(context: context, items: items);
      case ArrangementType.list:
        return createAutoArrangedList(context: context, items: items, scrollable: false);
    }
  }
}

/// Feature item model for auto-arrangement
class FeatureItem {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? customIcon;
  final VoidCallback? onTap;
  final FeaturePriority priority;
  final int usageCount;
  final List<String> tags;
  final String? category;
  final Color? lightIconColor;
  final Color? darkIconColor;
  final bool showArrow;
  
  const FeatureItem({
    required this.title,
    this.subtitle,
    this.icon,
    this.customIcon,
    this.onTap,
    this.priority = FeaturePriority.medium,
    this.usageCount = 0,
    this.tags = const [],
    this.category,
    this.lightIconColor,
    this.darkIconColor,
    this.showArrow = true,
  });
  
  /// Create a copy with updated usage count
  FeatureItem copyWithIncrementedUsage() {
    return FeatureItem(
      title: title,
      subtitle: subtitle,
      icon: icon,
      customIcon: customIcon,
      onTap: onTap,
      priority: priority,
      usageCount: usageCount + 1,
      tags: tags,
      category: category,
      lightIconColor: lightIconColor,
      darkIconColor: darkIconColor,
      showArrow: showArrow,
    );
  }
}

/// Priority levels for feature items
enum FeaturePriority {
  low,
  medium,
  high,
  critical,
}

/// Arrangement types for feature items
enum ArrangementType {
  grid,
  wrap,
  list,
}