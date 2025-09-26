import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final double mobileBreakpoint;
  final double tabletBreakpoint;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.mobileBreakpoint = 600,
    this.tabletBreakpoint = 1024,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= tabletBreakpoint && desktop != null) {
          return desktop!;
        } else if (constraints.maxWidth >= mobileBreakpoint && tablet != null) {
          return tablet!;
        } else {
          return mobile;
        }
      },
    );
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints,
      DeviceType deviceType) builder;
  final double mobileBreakpoint;
  final double tabletBreakpoint;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
    this.mobileBreakpoint = 600,
    this.tabletBreakpoint = 1024,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        DeviceType deviceType;
        if (constraints.maxWidth >= tabletBreakpoint) {
          deviceType = DeviceType.desktop;
        } else if (constraints.maxWidth >= mobileBreakpoint) {
          deviceType = DeviceType.tablet;
        } else {
          deviceType = DeviceType.mobile;
        }

        return builder(context, constraints, deviceType);
      },
    );
  }
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
}

class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;
  final double mobileBreakpoint;
  final double tabletBreakpoint;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
    this.mobileBreakpoint = 600,
    this.tabletBreakpoint = 1024,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobileBreakpoint: mobileBreakpoint,
      tabletBreakpoint: tabletBreakpoint,
      builder: (context, constraints, deviceType) {
        int columns;
        switch (deviceType) {
          case DeviceType.desktop:
            columns = desktopColumns;
            break;
          case DeviceType.tablet:
            columns = tabletColumns;
            break;
          case DeviceType.mobile:
            columns = mobileColumns;
            break;
        }

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: runSpacing,
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          scrollDirection: scrollDirection,
          children: children,
        );
      },
    );
  }
}

class FlexibleLayout extends StatelessWidget {
  final List<FlexibleLayoutItem> children;
  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double spacing;
  final EdgeInsetsGeometry? padding;
  final bool wrap;
  final WrapAlignment wrapAlignment;
  final WrapCrossAlignment wrapCrossAlignment;
  final double runSpacing;

  const FlexibleLayout({
    super.key,
    required this.children,
    this.direction = Axis.horizontal,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing = 0.0,
    this.padding,
    this.wrap = false,
    this.wrapAlignment = WrapAlignment.start,
    this.wrapCrossAlignment = WrapCrossAlignment.start,
    this.runSpacing = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    for (int i = 0; i < children.length; i++) {
      final item = children[i];

      Widget child = item.child;

      if (item.flex != null) {
        child = Flexible(
          flex: item.flex!,
          fit: item.fit ?? FlexFit.loose,
          child: child,
        );
      } else if (item.expanded) {
        child = Expanded(
          flex: item.expandedFlex ?? 1,
          child: child,
        );
      }

      widgets.add(child);

      // Add spacing between items (except for the last item)
      if (i < children.length - 1 && spacing > 0) {
        if (direction == Axis.horizontal) {
          widgets.add(SizedBox(width: spacing));
        } else {
          widgets.add(SizedBox(height: spacing));
        }
      }
    }

    Widget layout;
    if (wrap) {
      layout = Wrap(
        direction: direction,
        alignment: wrapAlignment,
        crossAxisAlignment: wrapCrossAlignment,
        spacing: spacing,
        runSpacing: runSpacing,
        children: children.map((item) => item.child).toList(),
      );
    } else {
      layout = Flex(
        direction: direction,
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: widgets,
      );
    }

    if (padding != null) {
      layout = Padding(
        padding: padding!,
        child: layout,
      );
    }

    return layout;
  }
}

class FlexibleLayoutItem {
  final Widget child;
  final int? flex;
  final FlexFit? fit;
  final bool expanded;
  final int? expandedFlex;

  const FlexibleLayoutItem({
    required this.child,
    this.flex,
    this.fit,
    this.expanded = false,
    this.expandedFlex,
  });

  factory FlexibleLayoutItem.flexible({
    required Widget child,
    int flex = 1,
    FlexFit fit = FlexFit.loose,
  }) {
    return FlexibleLayoutItem(
      child: child,
      flex: flex,
      fit: fit,
    );
  }

  factory FlexibleLayoutItem.expanded({
    required Widget child,
    int flex = 1,
  }) {
    return FlexibleLayoutItem(
      child: child,
      expanded: true,
      expandedFlex: flex,
    );
  }
}

class StickyHeader extends StatelessWidget {
  final Widget header;
  final Widget content;
  final bool overlapInjector;
  final ScrollController? controller;

  const StickyHeader({
    super.key,
    required this.header,
    required this.content,
    this.overlapInjector = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            child: header,
            overlapInjector: overlapInjector,
          ),
        ),
        SliverToBoxAdapter(
          child: content,
        ),
      ],
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final bool overlapInjector;

  _StickyHeaderDelegate({
    required this.child,
    required this.overlapInjector,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => _getChildSize(child).height;

  @override
  double get minExtent => _getChildSize(child).height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate != this;
  }

  Size _getChildSize(Widget child) {
    // This is a simplified approach. In a real implementation,
    // you might want to measure the child more accurately.
    return const Size(double.infinity, kToolbarHeight);
  }
}

class MasonryLayout extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const MasonryLayout({
    super.key,
    required this.children,
    required this.crossAxisCount,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth - (padding?.horizontal ?? 0);
        final itemWidth =
            (availableWidth - (crossAxisSpacing * (crossAxisCount - 1))) /
                crossAxisCount;

        final columns = List.generate(crossAxisCount, (index) => <Widget>[]);
        final columnHeights = List.generate(crossAxisCount, (index) => 0.0);

        for (int i = 0; i < children.length; i++) {
          // Find the column with the minimum height
          int minHeightIndex = 0;
          for (int j = 1; j < columnHeights.length; j++) {
            if (columnHeights[j] < columnHeights[minHeightIndex]) {
              minHeightIndex = j;
            }
          }

          // Add the child to the column with minimum height
          columns[minHeightIndex].add(
            Container(
              width: itemWidth,
              margin: EdgeInsets.only(
                bottom:
                    i < children.length - crossAxisCount ? mainAxisSpacing : 0,
              ),
              child: children[i],
            ),
          );

          // Update the column height (simplified estimation)
          columnHeights[minHeightIndex] +=
              200 + mainAxisSpacing; // Estimated height
        }

        return SingleChildScrollView(
          physics: physics,
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: columns.asMap().entries.map((entry) {
                final index = entry.key;
                final columnChildren = entry.value;

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      right: index < columns.length - 1 ? crossAxisSpacing : 0,
                    ),
                    child: Column(
                      children: columnChildren,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class SafeAreaLayout extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  final EdgeInsetsGeometry? minimum;
  final bool maintainBottomViewPadding;

  const SafeAreaLayout({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
    this.minimum,
    this.maintainBottomViewPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      minimum: (minimum as EdgeInsets?) ?? EdgeInsets.zero,
      maintainBottomViewPadding: maintainBottomViewPadding,
      child: child,
    );
  }
}

class CenteredLayout extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool fillHeight;

  const CenteredLayout({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (maxWidth != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: content,
      );
    }

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    content = Center(child: content);

    if (fillHeight) {
      content = SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: content,
      );
    }

    return content;
  }
}

class SplitLayout extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double? leftFlex;
  final double? rightFlex;
  final double? dividerWidth;
  final Color? dividerColor;
  final double minLeftWidth;
  final double minRightWidth;
  final bool resizable;
  final Axis direction;

  const SplitLayout({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex,
    this.rightFlex,
    this.dividerWidth,
    this.dividerColor,
    this.minLeftWidth = 200,
    this.minRightWidth = 200,
    this.resizable = false,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (direction == Axis.horizontal) {
      return Row(
        children: [
          Flexible(
            flex: (leftFlex ?? 1).toInt(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minLeftWidth),
              child: left,
            ),
          ),
          if (dividerWidth != null && dividerWidth! > 0)
            Container(
              width: dividerWidth,
              color: dividerColor ?? theme.dividerColor,
            ),
          Flexible(
            flex: (rightFlex ?? 1).toInt(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minRightWidth),
              child: right,
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Flexible(
            flex: (leftFlex ?? 1).toInt(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minLeftWidth),
              child: left,
            ),
          ),
          if (dividerWidth != null && dividerWidth! > 0)
            Container(
              height: dividerWidth,
              color: dividerColor ?? theme.dividerColor,
            ),
          Flexible(
            flex: (rightFlex ?? 1).toInt(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minRightWidth),
              child: right,
            ),
          ),
        ],
      );
    }
  }
}

class StackedLayout extends StatelessWidget {
  final List<Widget> children;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit fit;
  final Clip clipBehavior;

  const StackedLayout({
    super.key,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.fit = StackFit.loose,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: alignment,
      textDirection: textDirection,
      fit: fit,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}

class PositionedWidget extends StatelessWidget {
  final Widget child;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final double? width;
  final double? height;

  const PositionedWidget({
    super.key,
    required this.child,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: child,
    );
  }

  factory PositionedWidget.fill({
    required Widget child,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return PositionedWidget(
      left: left ?? 0,
      top: top ?? 0,
      right: right ?? 0,
      bottom: bottom ?? 0,
      child: child,
    );
  }

  factory PositionedWidget.fromRect({
    required Widget child,
    required Rect rect,
  }) {
    return PositionedWidget(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: child,
    );
  }

  factory PositionedWidget.fromRelativeRect({
    required Widget child,
    required RelativeRect rect,
    required Size size,
  }) {
    return PositionedWidget(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
      child: child,
    );
  }
}




