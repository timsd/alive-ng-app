import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  static ImageProvider provider(String? url, {double scale = 1.0}) {
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImageProvider(url, scale: scale);
    }
    // Return a transparent image provider or a local placeholder if needed
    // For now, we return a provider that will fail gracefully or show nothing
    // But typically CircleAvatar handles null backgroundImage by showing child
    return const AssetImage('assets/images/logo.png'); // Fallback
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget imageWidget;
    
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorWidget: (context, url, error) {
          return _buildPlaceholder(theme);
        },
        placeholder: (context, url) {
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



