import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../utils/layout_fix_utils.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../utils/i18n_service.dart';
import 'donation_button.dart';
import 'custom_image.dart';
import '../constants/app_constants.dart';

class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool? centerTitle;
  final double? titleSpacing;
  final double? leadingWidth;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final PreferredSizeWidget? bottom;
  final ShapeBorder? shape;
  final double toolbarHeight;
  final bool pinned;
  final bool floating;
  final bool snap;
  final bool showThemeToggle;
  final bool showLanguageToggle;
  final bool showDonationButton;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle,
    this.titleSpacing,
    this.leadingWidth,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.showBackButton = false,
    this.onBackPressed,
    this.bottom,
    this.shape,
    this.toolbarHeight = kToolbarHeight,
    this.pinned = true,
    this.floating = false,
    this.snap = false,
    this.showThemeToggle = true,
    this.showLanguageToggle = true,
    this.showDonationButton = true,
  });

  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
    final translate = ref.read(translationProvider);
    final currentLocale = ref.watch(localeProvider);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(translate('language')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: SupportedLanguage.values.map((language) {
              final isSelected = currentLocale.languageCode == language.code;
              return ListTile(
                title: Text(language.name),
                subtitle: Text(language.code.toUpperCase()),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                      )
                    : Icon(
                        Icons.circle_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                selected: isSelected,
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(language.code);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(translate('cancel')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);
    final translate = ref.watch(translationProvider);

    Widget? effectiveLeading = leading;
    if (showBackButton && leading == null) {
      effectiveLeading = IconButton(
        icon: LayoutFixUtils.responsiveIcon(
          Icons.chevron_left,
          context: context,
        ),
        onPressed: onBackPressed ??
            () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
                return;
              }
              if (context.mounted) {
                context.go(AppConstants.homeRoute);
              }
            },
      );
    }

    // Build toggle actions
    List<Widget> toggleActions = [];

    if (showThemeToggle) {
      IconData themeIcon;
      String themeTooltip;

      switch (themeMode) {
        case ThemeMode.system:
          themeIcon = Icons.brightness_auto;
          themeTooltip = 'Auto Theme';
          break;
        case ThemeMode.light:
          themeIcon = Icons.light_mode;
          themeTooltip = 'Light Mode';
          break;
        case ThemeMode.dark:
          themeIcon = Icons.dark_mode;
          themeTooltip = 'Dark Mode';
          break;
      }

      toggleActions.add(
        IconButton(
          icon: LayoutFixUtils.responsiveIcon(
            themeIcon,
            context: context,
          ),
          onPressed: () {
            ref.read(themeModeProvider.notifier).toggleTheme();
          },
          tooltip: themeTooltip,
        ),
      );
    }

    if (showLanguageToggle) {
      toggleActions.add(
        IconButton(
          icon: LayoutFixUtils.responsiveIcon(
            Icons.translate_rounded,
            context: context,
          ),
          onPressed: () => _showLanguageSelector(context, ref),
          tooltip:
              '${translate('language')} (${currentLocale.languageCode.toUpperCase()})',
        ),
      );
    }

    if (showDonationButton) {
      toggleActions.add(
        const CompactDonationButton(),
      );
    }

    // Combine custom actions with toggle actions
    List<Widget>? allActions;
    if (actions != null || toggleActions.isNotEmpty) {
      allActions = [
        ...(actions ?? []),
        ...toggleActions,
      ];
    }

    // Resolve colors to ensure icon/text contrast across any background
    final Color resolvedBackground = backgroundColor ??
        theme.appBarTheme.backgroundColor ??
        theme.colorScheme.primary;

    // Choose a high-contrast foreground:
    // - If background is the theme primary, use onPrimary.
    // - Otherwise, fall back to black/white based on luminance.
    Color computedContrast;
    if (resolvedBackground.toARGB32() == theme.colorScheme.primary.toARGB32()) {
      computedContrast = theme.colorScheme.onPrimary;
    } else {
      final double luminance = resolvedBackground.computeLuminance();
      computedContrast = luminance > 0.5 ? Colors.black : Colors.white;
    }

    final Color resolvedForeground = foregroundColor ??
        theme.appBarTheme.foregroundColor ??
        computedContrast;

    final TextStyle? resolvedTitleStyle = (titleTextStyle ??
            theme.appBarTheme.titleTextStyle ??
            theme.textTheme.titleLarge)
        ?.copyWith(color: resolvedForeground);
    final ShapeBorder resolvedShape = shape ??
        Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.9),
            width: 1,
          ),
        );

    return AppBar(
      title: titleWidget ??
          (title != null
              ? LayoutFixUtils.responsiveText(
                  title!,
                  context: context,
                  style: resolvedTitleStyle,
                )
              : null),
      actions: allActions,
      leading: effectiveLeading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: resolvedBackground,
      foregroundColor: resolvedForeground,
      iconTheme: IconThemeData(color: resolvedForeground),
      actionsIconTheme: IconThemeData(color: resolvedForeground),
      elevation: elevation ?? theme.appBarTheme.elevation,
      centerTitle: centerTitle ?? theme.appBarTheme.centerTitle,
      titleSpacing: titleSpacing,
      leadingWidth: leadingWidth,
      systemOverlayStyle:
          systemOverlayStyle ?? theme.appBarTheme.systemOverlayStyle,
      bottom: bottom,
      shape: resolvedShape,
      toolbarHeight: toolbarHeight,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}

class SliverCustomAppBar extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool? centerTitle;
  final double? titleSpacing;
  final double? leadingWidth;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final PreferredSizeWidget? bottom;
  final ShapeBorder? shape;
  final double toolbarHeight;
  final bool pinned;
  final bool floating;
  final bool snap;
  final double? expandedHeight;
  final Widget? flexibleSpace;
  final double? collapsedHeight;
  final bool stretch;

  const SliverCustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle,
    this.titleSpacing,
    this.leadingWidth,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.showBackButton = false,
    this.onBackPressed,
    this.bottom,
    this.shape,
    this.toolbarHeight = kToolbarHeight,
    this.pinned = true,
    this.floating = false,
    this.snap = false,
    this.expandedHeight,
    this.flexibleSpace,
    this.collapsedHeight,
    this.stretch = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget? effectiveLeading = leading;
    if (showBackButton && leading == null) {
      effectiveLeading = IconButton(
        icon: LayoutFixUtils.responsiveIcon(
          Icons.chevron_left,
          context: context,
        ),
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
      );
    }

    return SliverAppBar(
      title: titleWidget ??
          (title != null
              ? LayoutFixUtils.responsiveText(
                  title!,
                  context: context,
                  style: titleTextStyle ?? theme.appBarTheme.titleTextStyle,
                )
              : null),
      actions: actions,
      leading: effectiveLeading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? theme.appBarTheme.backgroundColor,
      foregroundColor: foregroundColor ?? theme.appBarTheme.foregroundColor,
      elevation: elevation ?? theme.appBarTheme.elevation,
      centerTitle: centerTitle ?? theme.appBarTheme.centerTitle,
      titleSpacing: titleSpacing,
      leadingWidth: leadingWidth,
      systemOverlayStyle:
          systemOverlayStyle ?? theme.appBarTheme.systemOverlayStyle,
      bottom: bottom,
      shape: shape,
      toolbarHeight: toolbarHeight,
      pinned: pinned,
      floating: floating,
      snap: snap,
      expandedHeight: expandedHeight,
      flexibleSpace: flexibleSpace,
      collapsedHeight: collapsedHeight,
      stretch: stretch,
    );
  }
}

class SearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final List<Widget>? actions;
  final bool autofocus;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final double toolbarHeight;

  const SearchAppBar({
    super.key,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.controller,
    this.actions,
    this.autofocus = false,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.keyboardType,
    this.textInputAction,
    this.leading,
    this.showBackButton = true,
    this.onBackPressed,
    this.toolbarHeight = kToolbarHeight,
  });

  @override
  State<SearchAppBar> createState() => _SearchAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
}

class _SearchAppBarState extends State<SearchAppBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget? effectiveLeading = widget.leading;
    if (widget.showBackButton && widget.leading == null) {
      effectiveLeading = IconButton(
        icon: LayoutFixUtils.responsiveIcon(
          Icons.chevron_left,
          context: context,
        ),
        onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
      );
    }

    return AppBar(
      leading: effectiveLeading,
      backgroundColor:
          widget.backgroundColor ?? theme.appBarTheme.backgroundColor,
      foregroundColor:
          widget.foregroundColor ?? theme.appBarTheme.foregroundColor,
      elevation: widget.elevation ?? theme.appBarTheme.elevation,
      toolbarHeight: widget.toolbarHeight,
      title: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction ?? TextInputAction.search,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: widget.foregroundColor ?? theme.appBarTheme.foregroundColor,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search...',
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: (widget.foregroundColor ?? theme.appBarTheme.foregroundColor)
                ?.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: LayoutFixUtils.responsiveIcon(
                    Icons.clear,
                    context: context,
                  ),
                  onPressed: _clearSearch,
                  color: widget.foregroundColor ??
                      theme.appBarTheme.foregroundColor,
                )
              : null,
        ),
      ),
      actions: widget.actions,
    );
  }
}

class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget> tabs;
  final TabController? controller;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool? centerTitle;
  final double? titleSpacing;
  final double? leadingWidth;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final ShapeBorder? shape;
  final double toolbarHeight;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final EdgeInsetsGeometry? labelPadding;
  final TabBarIndicatorSize? indicatorSize;
  final Decoration? indicator;
  final double indicatorWeight;
  final EdgeInsetsGeometry indicatorPadding;
  final bool isScrollable;

  const TabAppBar({
    super.key,
    this.title,
    this.titleWidget,
    required this.tabs,
    this.controller,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle,
    this.titleSpacing,
    this.leadingWidth,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.showBackButton = false,
    this.onBackPressed,
    this.shape,
    this.toolbarHeight = kToolbarHeight,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.labelPadding,
    this.indicatorSize,
    this.indicator,
    this.indicatorWeight = 2.0,
    this.indicatorPadding = EdgeInsets.zero,
    this.isScrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget? effectiveLeading = leading;
    if (showBackButton && leading == null) {
      effectiveLeading = IconButton(
        icon: LayoutFixUtils.responsiveIcon(
          Icons.chevron_left,
          context: context,
        ),
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
      );
    }

    return AppBar(
      title: titleWidget ??
          (title != null
              ? LayoutFixUtils.responsiveText(
                  title!,
                  context: context,
                  style: titleTextStyle ?? theme.appBarTheme.titleTextStyle,
                )
              : null),
      actions: actions,
      leading: effectiveLeading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? theme.appBarTheme.backgroundColor,
      foregroundColor: foregroundColor ?? theme.appBarTheme.foregroundColor,
      elevation: elevation ?? theme.appBarTheme.elevation,
      centerTitle: centerTitle ?? theme.appBarTheme.centerTitle,
      titleSpacing: titleSpacing,
      leadingWidth: leadingWidth,
      systemOverlayStyle:
          systemOverlayStyle ?? theme.appBarTheme.systemOverlayStyle,
      shape: shape,
      toolbarHeight: toolbarHeight,
      bottom: TabBar(
        tabs: tabs,
        controller: controller,
        indicatorColor: indicatorColor ?? theme.colorScheme.primary,
        labelColor: labelColor ?? theme.colorScheme.primary,
        unselectedLabelColor: unselectedLabelColor ??
            theme.colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: labelStyle,
        unselectedLabelStyle: unselectedLabelStyle,
        labelPadding: labelPadding,
        indicatorSize: indicatorSize,
        indicator: indicator,
        indicatorWeight: indicatorWeight,
        indicatorPadding: indicatorPadding,
        isScrollable: isScrollable,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + kTextTabBarHeight,
      );
}

class ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final String? avatarUrl;
  final Widget? avatar;
  final List<Widget>? actions;
  final VoidCallback? onAvatarTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final double toolbarHeight;

  const ProfileAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.avatarUrl,
    this.avatar,
    this.actions,
    this.onAvatarTap,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.showBackButton = false,
    this.onBackPressed,
    this.toolbarHeight = kToolbarHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget avatarWidget = avatar ??
        CircleAvatar(
          radius: 20,
          backgroundImage:
              avatarUrl != null ? CustomImage.provider(avatarUrl!) : null,
          child: avatarUrl == null
              ? LayoutFixUtils.responsiveIcon(
                  Icons.person,
                  context: context,
                )
              : null,
        );

    if (onAvatarTap != null) {
      avatarWidget = GestureDetector(
        onTap: onAvatarTap,
        child: avatarWidget,
      );
    }

    return AppBar(
      leading: showBackButton
          ? IconButton(
              icon: LayoutFixUtils.responsiveIcon(
                Icons.chevron_left,
                context: context,
              ),
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
            )
          : null,
      backgroundColor: backgroundColor ?? theme.appBarTheme.backgroundColor,
      foregroundColor: foregroundColor ?? theme.appBarTheme.foregroundColor,
      elevation: elevation ?? theme.appBarTheme.elevation,
      toolbarHeight: toolbarHeight,
      title: Row(
        children: [
          avatarWidget,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  LayoutFixUtils.responsiveText(
                    title!,
                    context: context,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          foregroundColor ?? theme.appBarTheme.foregroundColor,
                    ),
                  ),
                if (subtitle != null)
                  LayoutFixUtils.responsiveText(
                    subtitle!,
                    context: context,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          (foregroundColor ?? theme.appBarTheme.foregroundColor)
                              ?.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
}
