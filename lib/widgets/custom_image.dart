import 'package:flutter/foundation.dart';
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
    if (url != null && url.trim().isNotEmpty) {
      if (kIsWeb) {
        return NetworkImage(url.trim(), scale: scale);
      }
      return CachedNetworkImageProvider(url.trim(), scale: scale);
    }
    return const AssetImage('assets/images/logo.png');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanUrl = imageUrl?.trim();

    Widget imageWidget;

    if (cleanUrl != null && cleanUrl.isNotEmpty) {
      if (kIsWeb) {
        imageWidget = Image.network(
          cleanUrl,
          key: ValueKey(cleanUrl),
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(theme);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder ?? _buildLoadingWidget(theme);
          },
        );
      } else {
        imageWidget = CachedNetworkImage(
          key: ValueKey(cleanUrl),
          imageUrl: cleanUrl,
          width: width,
          height: height,
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 120),
          fadeOutDuration: Duration.zero,
          errorWidget: (context, url, error) {
            return _buildPlaceholder(theme);
          },
          placeholder: (context, url) {
            return placeholder ?? _buildLoadingWidget(theme);
          },
        );
      }
    } else {
      imageWidget = _buildPlaceholder(theme);
    }

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: backgroundColor),
        child: imageWidget,
      ),
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
