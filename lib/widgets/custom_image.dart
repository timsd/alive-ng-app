import 'package:flutter/material.dart';

class CustomImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const CustomImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget imageWidget;
    
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(theme);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingWidget(theme);
        },
      );
    } else {
      imageWidget = _buildPlaceholder(theme);
    }

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return Container(
      width: width,
      height: height,
      color: backgroundColor,
      child: imageWidget,
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return placeholder ??
        Container(
          width: width,
          height: height,
          color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.image,
            color: theme.colorScheme.onSurfaceVariant,
            size: (width != null && height != null) 
                ? (width! < height! ? width! * 0.4 : height! * 0.4)
                : 24,
          ),
        );
  }

  Widget _buildLoadingWidget(ThemeData theme) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}