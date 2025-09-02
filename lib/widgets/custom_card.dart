import 'package:flutter/material.dart';

enum CardVariant {
  elevated,
  outlined,
  filled,
}

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? shadowColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final Border? border;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final CardVariant variant;
  final double? width;
  final double? height;
  final Clip clipBehavior;
  
  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.shadowColor,
    this.elevation,
    this.borderRadius,
    this.border,
    this.onTap,
    this.onLongPress,
    this.variant = CardVariant.elevated,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Determine card properties based on variant
    Color cardColor;
    double cardElevation;
    Border? cardBorder;
    
    switch (variant) {
      case CardVariant.elevated:
        cardColor = color ?? colorScheme.surface;
        cardElevation = elevation ?? 2;
        cardBorder = border;
        break;
      case CardVariant.outlined:
        cardColor = color ?? colorScheme.surface;
        cardElevation = 0;
        cardBorder = border ?? Border.all(
          color: colorScheme.outline,
          width: 1,
        );
        break;
      case CardVariant.filled:
        cardColor = color ?? colorScheme.surfaceContainerHighest;
        cardElevation = elevation ?? 0;
        cardBorder = border;
        break;
    }
    
    Widget cardWidget = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: cardBorder,
        boxShadow: cardElevation > 0 ? [
          BoxShadow(
            color: shadowColor ?? Colors.black.withValues(alpha: 0.1),
            blurRadius: cardElevation * 2,
            offset: Offset(0, cardElevation),
          ),
        ] : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        clipBehavior: clipBehavior,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
    
    if (onTap != null || onLongPress != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: cardWidget,
        ),
      );
    }
    
    return cardWidget;
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? value;
  final IconData? icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showDivider;
  
  const InfoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.icon,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
    this.trailing,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return CustomCard(
      color: backgroundColor,
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              if (icon != null) ..[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ..[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ..[
                const SizedBox(width: 12),
                Text(
                  value!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              if (trailing != null) ..[
                const SizedBox(width: 12),
                trailing!,
              ],
              if (onTap != null) ..[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
          if (showDivider) ..[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ],
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final String? trend;
  final bool isPositiveTrend;
  final VoidCallback? onTap;
  
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.color,
    this.trend,
    this.isPositiveTrend = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.colorScheme.primary;
    
    return CustomCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ..[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: cardColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cardColor,
            ),
          ),
          if (subtitle != null || trend != null) ..[
            const SizedBox(height: 4),
            Row(
              children: [
                if (subtitle != null)
                  Expanded(
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                if (trend != null) ..[
                  Icon(
                    isPositiveTrend ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: isPositiveTrend ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trend!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isPositiveTrend ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;
  
  const ActionCard({
    super.key,
    required this.title,
    this.description,
    required this.icon,
    this.color,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.colorScheme.primary;
    
    return CustomCard(
      onTap: onTap,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: cardColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (description != null) ..[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          if (badge != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ImageCard extends StatelessWidget {
  final String? imageUrl;
  final Widget? placeholder;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onTap;
  final double? height;
  final BoxFit imageFit;
  
  const ImageCard({
    super.key,
    this.imageUrl,
    this.placeholder,
    this.title,
    this.subtitle,
    this.actions,
    this.onTap,
    this.height,
    this.imageFit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return CustomCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null || placeholder != null)
            Container(
              height: height ?? 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: imageFit,
                      errorBuilder: (context, error, stackTrace) {
                        return placeholder ?? Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_not_supported,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 48,
                          ),
                        );
                      },
                    )
                  : placeholder,
            ),
          if (title != null || subtitle != null || actions != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (subtitle != null) ..[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  if (actions != null) ..[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ExpandableCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final IconData? icon;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry? padding;
  
  const ExpandableCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.icon,
    this.initiallyExpanded = false,
    this.padding,
  });

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return CustomCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (widget.icon != null) ..[
                    Icon(
                      widget.icon,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.subtitle != null) ..[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.expand_more,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _animation,
            child: Container(
              width: double.infinity,
              padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
