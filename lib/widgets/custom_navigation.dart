import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/language_provider.dart';

class CustomBottomNavigationBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;
  final BottomNavigationBarType? type;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double? selectedFontSize;
  final double? unselectedFontSize;
  final IconThemeData? selectedIconTheme;
  final IconThemeData? unselectedIconTheme;
  final TextStyle? selectedLabelStyle;
  final TextStyle? unselectedLabelStyle;
  final bool showSelectedLabels;
  final bool showUnselectedLabels;
  final double? elevation;
  final bool enableFeedback;
  final MouseCursor? mouseCursor;
  final bool? useLegacyColorScheme;
  final String? selectedItemTooltip;
  final String? unselectedItemTooltip;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.type,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.selectedFontSize,
    this.unselectedFontSize,
    this.selectedIconTheme,
    this.unselectedIconTheme,
    this.selectedLabelStyle,
    this.unselectedLabelStyle,
    this.showSelectedLabels = true,
    this.showUnselectedLabels = true,
    this.elevation,
    this.enableFeedback = true,
    this.mouseCursor,
    this.useLegacyColorScheme,
    this.selectedItemTooltip,
    this.unselectedItemTooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: items,
      type: type ??
          (items.length > 3
              ? BottomNavigationBarType.fixed
              : BottomNavigationBarType.shifting),
      backgroundColor:
          backgroundColor ?? theme.bottomNavigationBarTheme.backgroundColor,
      selectedItemColor: selectedItemColor ?? theme.colorScheme.primary,
      unselectedItemColor:
          unselectedItemColor ?? theme.colorScheme.onSurfaceVariant,
      selectedFontSize: selectedFontSize ?? 12,
      unselectedFontSize: unselectedFontSize ?? 12,
      selectedIconTheme: selectedIconTheme,
      unselectedIconTheme: unselectedIconTheme,
      selectedLabelStyle: selectedLabelStyle,
      unselectedLabelStyle: unselectedLabelStyle,
      showSelectedLabels: showSelectedLabels,
      showUnselectedLabels: showUnselectedLabels,
      elevation: elevation,
      enableFeedback: enableFeedback,
      mouseCursor: mouseCursor,
      useLegacyColorScheme: useLegacyColorScheme ?? false,
    );
  }
}

class CustomNavigationRail extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationRailDestination> destinations;
  final Widget? leading;
  final Widget? trailing;
  final bool extended;
  final double? minWidth;
  final double? minExtendedWidth;
  final bool? useIndicator;
  final Color? indicatorColor;
  final ShapeBorder? indicatorShape;
  final double? groupAlignment;
  final NavigationRailLabelType? labelType;
  final TextStyle? selectedLabelTextStyle;
  final TextStyle? unselectedLabelTextStyle;
  final IconThemeData? selectedIconTheme;
  final IconThemeData? unselectedIconTheme;
  final Color? backgroundColor;
  final double? elevation;

  const CustomNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.leading,
    this.trailing,
    this.extended = false,
    this.minWidth,
    this.minExtendedWidth,
    this.useIndicator,
    this.indicatorColor,
    this.indicatorShape,
    this.groupAlignment,
    this.labelType,
    this.selectedLabelTextStyle,
    this.unselectedLabelTextStyle,
    this.selectedIconTheme,
    this.unselectedIconTheme,
    this.backgroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
      leading: leading,
      trailing: trailing,
      extended: extended,
      minWidth: minWidth,
      minExtendedWidth: minExtendedWidth,
      useIndicator: useIndicator,
      indicatorColor: indicatorColor ?? theme.colorScheme.secondaryContainer,
      indicatorShape: indicatorShape,
      groupAlignment: groupAlignment,
      labelType: labelType ?? NavigationRailLabelType.all,
      selectedLabelTextStyle: selectedLabelTextStyle,
      unselectedLabelTextStyle: unselectedLabelTextStyle,
      selectedIconTheme: selectedIconTheme,
      unselectedIconTheme: unselectedIconTheme,
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      elevation: elevation,
    );
  }
}

class CustomNavigationDrawer extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDrawerDestination> destinations;
  final Widget? leading;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? surfaceTintColor;
  final double? elevation;
  final Color? shadowColor;
  final ShapeBorder? shape;
  final double? width;
  final EdgeInsetsGeometry? tilePadding;
  final Color? indicatorColor;
  final ShapeBorder? indicatorShape;
  final Size? indicatorSize;

  const CustomNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.leading,
    this.trailing,
    this.backgroundColor,
    this.surfaceTintColor,
    this.elevation,
    this.shadowColor,
    this.shape,
    this.width,
    this.tilePadding,
    this.indicatorColor,
    this.indicatorShape,
    this.indicatorSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation,
      shadowColor: shadowColor,
      indicatorColor: indicatorColor ?? theme.colorScheme.secondaryContainer,
      indicatorShape: indicatorShape,
      children: [
        if (leading != null) leading!,
        ...destinations,
        if (trailing != null) trailing!,
      ],
    );
  }
}

class CustomTabBar extends ConsumerWidget implements PreferredSizeWidget {
  final List<Widget> tabs;
  final TabController? controller;
  final bool isScrollable;
  final EdgeInsetsGeometry? padding;
  final Color? indicatorColor;
  final Decoration? indicator;
  final TabBarIndicatorSize? indicatorSize;
  final Color? labelColor;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? labelPadding;
  final Color? unselectedLabelColor;
  final TextStyle? unselectedLabelStyle;
  final DragStartBehavior dragStartBehavior;
  final WidgetStateProperty<Color?>? overlayColor;
  final MouseCursor? mouseCursor;
  final bool? enableFeedback;
  final ValueChanged<int>? onTap;
  final ScrollPhysics? physics;
  final InteractiveInkFeatureFactory? splashFactory;
  final BorderRadius? splashBorderRadius;
  final TabAlignment? tabAlignment;
  final TextScaler? textScaler;

  const CustomTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.padding,
    this.indicatorColor,
    this.indicator,
    this.indicatorSize,
    this.labelColor,
    this.labelStyle,
    this.labelPadding,
    this.unselectedLabelColor,
    this.unselectedLabelStyle,
    this.dragStartBehavior = DragStartBehavior.start,
    this.overlayColor,
    this.mouseCursor,
    this.enableFeedback,
    this.onTap,
    this.physics,
    this.splashFactory,
    this.splashBorderRadius,
    this.tabAlignment,
    this.textScaler,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return TabBar(
      tabs: tabs,
      controller: controller,
      isScrollable: isScrollable,
      padding: padding,
      indicatorColor: indicatorColor ?? theme.colorScheme.primary,
      indicator: indicator,
      indicatorSize: indicatorSize,
      labelColor: labelColor ?? theme.colorScheme.primary,
      labelStyle: labelStyle,
      labelPadding: labelPadding,
      unselectedLabelColor:
          unselectedLabelColor ?? theme.colorScheme.onSurfaceVariant,
      unselectedLabelStyle: unselectedLabelStyle,
      dragStartBehavior: dragStartBehavior,
      overlayColor: overlayColor,
      mouseCursor: mouseCursor,
      enableFeedback: enableFeedback,
      onTap: onTap,
      physics: physics,
      splashFactory: splashFactory,
      splashBorderRadius: splashBorderRadius,
      tabAlignment: tabAlignment,
      textScaler: textScaler,
    );
  }

  @override
  Size get preferredSize => const Size(double.infinity, kToolbarHeight);
}

class BreadcrumbNavigation extends ConsumerWidget {
  final List<BreadcrumbItem> items;
  final String separator;
  final TextStyle? textStyle;
  final TextStyle? activeTextStyle;
  final Color? separatorColor;
  final EdgeInsetsGeometry? padding;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final bool wrap;

  const BreadcrumbNavigation({
    super.key,
    required this.items,
    this.separator = ' > ',
    this.textStyle,
    this.activeTextStyle,
    this.separatorColor,
    this.padding,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final defaultTextStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final defaultActiveTextStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w500,
    );

    final children = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;

      // Add breadcrumb item
      if (item.onTap != null && !isLast) {
        children.add(
          InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                item.label,
                style: textStyle ?? defaultTextStyle,
              ),
            ),
          ),
        );
      } else {
        children.add(
          Text(
            item.label,
            style: isLast
                ? (activeTextStyle ?? defaultActiveTextStyle)
                : (textStyle ?? defaultTextStyle),
          ),
        );
      }

      // Add separator (except for last item)
      if (!isLast) {
        children.add(
          Text(
            separator,
            style: TextStyle(
              color: separatorColor ??
                  theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        );
      }
    }

    Widget content;
    if (wrap) {
      content = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    } else {
      content = Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    }

    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: content,
    );
  }
}

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  const BreadcrumbItem({
    required this.label,
    this.onTap,
    this.icon,
  });
}

class StepperNavigation extends ConsumerWidget {
  final int currentStep;
  final List<StepperItem> steps;
  final ValueChanged<int>? onStepTapped;
  final VoidCallback? onStepContinue;
  final VoidCallback? onStepCancel;
  final StepperType type;
  final EdgeInsetsGeometry? margin;
  final ControlsWidgetBuilder? controlsBuilder;
  final double? elevation;
  final Color? connectorColor;
  final double? connectorThickness;

  const StepperNavigation({
    super.key,
    required this.currentStep,
    required this.steps,
    this.onStepTapped,
    this.onStepContinue,
    this.onStepCancel,
    this.type = StepperType.vertical,
    this.margin,
    this.controlsBuilder,
    this.elevation,
    this.connectorColor,
    this.connectorThickness,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Stepper(
      currentStep: currentStep,
      onStepTapped: onStepTapped,
      onStepContinue: onStepContinue,
      onStepCancel: onStepCancel,
      type: type,
      margin: margin,
      elevation: elevation,
      connectorColor: WidgetStateProperty.all(connectorColor ?? theme.colorScheme.outline),
      connectorThickness: connectorThickness ?? 1.0,
      controlsBuilder: controlsBuilder ??
          (context, details) {
              return Row(
                children: [
                  if (details.stepIndex < steps.length - 1)
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(
                          ref.watch(translationProvider)('continue')),
                    ),
                  const SizedBox(width: 8),
                  if (details.stepIndex > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: Text(ref.watch(translationProvider)('back')),
                    ),
                ],
              );
            },
      steps: steps.map((stepperItem) {
        final stepIndex = steps.indexOf(stepperItem);
        final isActive = stepIndex == currentStep;
        final isCompleted = stepIndex < currentStep;

        StepState state;
        if (isCompleted) {
          state = StepState.complete;
        } else if (isActive) {
          state = stepperItem.hasError ? StepState.error : StepState.indexed;
        } else {
          state = StepState.disabled;
        }

        return Step(
          title: Text(stepperItem.title),
          content: stepperItem.content,
          subtitle:
              stepperItem.subtitle != null ? Text(stepperItem.subtitle!) : null,
          isActive: isActive,
          state: state,
        );
      }).toList(),
    );
  }
}

class StepperItem {
  final String title;
  final String? subtitle;
  final Widget content;
  final bool hasError;

  const StepperItem({
    required this.title,
    this.subtitle,
    required this.content,
    this.hasError = false,
  });
}

class PaginationNavigation extends ConsumerWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final int visiblePages;
  final bool showFirstLast;
  final bool showPrevNext;
  final String? previousText;
  final String? nextText;
  final String? firstText;
  final String? lastText;
  final EdgeInsetsGeometry? padding;
  final Color? activeColor;
  final Color? inactiveColor;
  final TextStyle? activeTextStyle;
  final TextStyle? inactiveTextStyle;

  const PaginationNavigation({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.visiblePages = 5,
    this.showFirstLast = true,
    this.showPrevNext = true,
    this.previousText,
    this.nextText,
    this.firstText,
    this.lastText,
    this.padding,
    this.activeColor,
    this.inactiveColor,
    this.activeTextStyle,
    this.inactiveTextStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);

    if (totalPages <= 1) return const SizedBox.shrink();

    final buttons = <Widget>[];

    // First button
    if (showFirstLast && currentPage > 1) {
      buttons.add(
        _PaginationButton(
          text: firstText ?? translate('first'),
          onPressed: () => onPageChanged(1),
          isActive: false,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          activeTextStyle: activeTextStyle,
          inactiveTextStyle: inactiveTextStyle,
        ),
      );
    }

    // Previous button
    if (showPrevNext && currentPage > 1) {
      buttons.add(
        _PaginationButton(
          text: previousText ?? translate('previous'),
          onPressed: () => onPageChanged(currentPage - 1),
          isActive: false,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          activeTextStyle: activeTextStyle,
          inactiveTextStyle: inactiveTextStyle,
        ),
      );
    }

    // Page number buttons
    final startPage = (currentPage - visiblePages ~/ 2).clamp(1, totalPages);
    final endPage = (startPage + visiblePages - 1).clamp(1, totalPages);

    for (int i = startPage; i <= endPage; i++) {
      buttons.add(
        _PaginationButton(
          text: i.toString(),
          onPressed: () => onPageChanged(i),
          isActive: i == currentPage,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          activeTextStyle: activeTextStyle,
          inactiveTextStyle: inactiveTextStyle,
        ),
      );
    }

    // Next button
    if (showPrevNext && currentPage < totalPages) {
      buttons.add(
        _PaginationButton(
          text: nextText ?? translate('next'),
          onPressed: () => onPageChanged(currentPage + 1),
          isActive: false,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          activeTextStyle: activeTextStyle,
          inactiveTextStyle: inactiveTextStyle,
        ),
      );
    }

    // Last button
    if (showFirstLast && currentPage < totalPages) {
      buttons.add(
        _PaginationButton(
          text: lastText ?? translate('last'),
          onPressed: () => onPageChanged(totalPages),
          isActive: false,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          activeTextStyle: activeTextStyle,
          inactiveTextStyle: inactiveTextStyle,
        ),
      );
    }

    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: buttons,
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;
  final TextStyle? activeTextStyle;
  final TextStyle? inactiveTextStyle;

  const _PaginationButton({
    required this.text,
    required this.onPressed,
    required this.isActive,
    this.activeColor,
    this.inactiveColor,
    this.activeTextStyle,
    this.inactiveTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isActive) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: activeColor ?? theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          minimumSize: const Size(40, 40),
        ),
        child: Text(
          text,
          style: activeTextStyle,
        ),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: inactiveColor,
        minimumSize: const Size(40, 40),
      ),
      child: Text(
        text,
        style: inactiveTextStyle,
      ),
    );
  }
}




