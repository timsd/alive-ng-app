import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'loading_widget.dart';

class CustomImage extends StatelessWidget {
  final String? imageUrl;
  final String? assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Color? backgroundColor;
  final BlendMode? colorBlendMode;
  final Color? color;
  final double? opacity;
  final bool enableMemoryCache;
  final bool enableDiskCache;
  final Duration? fadeInDuration;
  final Duration? fadeOutDuration;
  final Curve fadeInCurve;
  final Curve fadeOutCurve;
  final FilterQuality filterQuality;
  final bool isAntiAlias;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? heroTag;
  
  const CustomImage({
    super.key,
    this.imageUrl,
    this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.backgroundColor,
    this.colorBlendMode,
    this.color,
    this.opacity,
    this.enableMemoryCache = true,
    this.enableDiskCache = true,
    this.fadeInDuration,
    this.fadeOutDuration,
    this.fadeInCurve = Curves.easeIn,
    this.fadeOutCurve = Curves.easeOut,
    this.filterQuality = FilterQuality.low,
    this.isAntiAlias = false,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.onTap,
    this.onLongPress,
    this.heroTag,
  }) : assert(imageUrl != null || assetPath != null, 'Either imageUrl or assetPath must be provided');

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    
    if (assetPath != null) {
      imageWidget = Image.asset(
        assetPath!,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        color: color,
        colorBlendMode: colorBlendMode,
        opacity: opacity != null ? AlwaysStoppedAnimation(opacity!) : null,
        filterQuality: filterQuality,
         isAntiAlias: isAntiAlias,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? _buildDefaultErrorWidget(context);
        },
      );
    } else if (imageUrl != null) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        placeholder: (context, url) {
          return placeholder ?? _buildDefaultPlaceholder(context);
        },
        errorWidget: (context, url, error) {
          return errorWidget ?? _buildDefaultErrorWidget(context);
        },
        color: color,
        colorBlendMode: colorBlendMode,
        fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 500),
        fadeOutDuration: fadeOutDuration ?? const Duration(milliseconds: 1000),
        fadeInCurve: fadeInCurve,
        fadeOutCurve: fadeOutCurve,
        useOldImageOnUrlChange: false,
        memCacheWidth: width?.toInt(),
        memCacheHeight: height?.toInt(),
        filterQuality: filterQuality,
      );
    } else {
      imageWidget = _buildDefaultErrorWidget(context);
    }
    
    // Apply opacity if specified
    if (opacity != null && assetPath == null) {
      imageWidget = Opacity(
        opacity: opacity!,
        child: imageWidget,
      );
    }
    
    // Apply decoration (border, shadow, etc.)
    if (borderRadius != null || border != null || boxShadow != null || backgroundColor != null) {
      imageWidget = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
          border: border,
          boxShadow: boxShadow,
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: imageWidget,
        ),
      );
    }
    
    // Apply hero animation if specified
    if (heroTag != null) {
      imageWidget = Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }
    
    // Apply tap gestures if specified
    if (onTap != null || onLongPress != null) {
      imageWidget = GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: imageWidget,
      );
    }
    
    return imageWidget;
  }
  
  Widget _buildDefaultPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: LoadingWidget(),
      ),
    );
  }
  
  Widget _buildDefaultErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.errorContainer,
      child: Icon(
        Icons.broken_image,
        color: Theme.of(context).colorScheme.onErrorContainer,
        size: (width != null && height != null) 
            ? (width! < height! ? width! * 0.3 : height! * 0.3)
            : 24,
      ),
    );
  }
}

class CircularImage extends StatelessWidget {
  final String? imageUrl;
  final String? assetPath;
  final double radius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? heroTag;
  
  const CircularImage({
    super.key,
    this.imageUrl,
    this.assetPath,
    required this.radius,
    this.placeholder,
    this.errorWidget,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.onTap,
    this.onLongPress,
    this.heroTag,
  }) : assert(imageUrl != null || assetPath != null, 'Either imageUrl or assetPath must be provided');

  @override
  Widget build(BuildContext context) {
    return CustomImage(
      imageUrl: imageUrl,
      assetPath: assetPath,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(radius),
      border: borderWidth > 0 ? Border.all(
        color: borderColor ?? Theme.of(context).colorScheme.outline,
        width: borderWidth,
      ) : null,
      backgroundColor: backgroundColor,
      placeholder: placeholder,
      errorWidget: errorWidget,
      onTap: onTap,
      onLongPress: onLongPress,
      heroTag: heroTag,
    );
  }
}

class ImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final List<String>? assetPaths;
  final double? itemWidth;
  final double? itemHeight;
  final double spacing;
  final double runSpacing;
  final int crossAxisCount;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final bool enableFullScreen;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final ValueChanged<int>? onImageTap;
  
  const ImageGallery({
    super.key,
    required this.imageUrls,
    this.assetPaths,
    this.itemWidth,
    this.itemHeight,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.crossAxisCount = 2,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.enableFullScreen = true,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onImageTap,
  });

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  @override
  Widget build(BuildContext context) {
    final allImages = <String>[];
    allImages.addAll(widget.imageUrls);
    if (widget.assetPaths != null) {
      allImages.addAll(widget.assetPaths!);
    }
    
    return GridView.builder(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: widget.spacing,
        mainAxisSpacing: widget.runSpacing,
        childAspectRatio: widget.itemWidth != null && widget.itemHeight != null
            ? widget.itemWidth! / widget.itemHeight!
            : 1.0,
      ),
      itemCount: allImages.length,
      itemBuilder: (context, index) {
        final imageUrl = allImages[index];
        final isAsset = widget.assetPaths?.contains(imageUrl) ?? false;
        
        return CustomImage(
          imageUrl: isAsset ? null : imageUrl,
          assetPath: isAsset ? imageUrl : null,
          width: widget.itemWidth,
          height: widget.itemHeight,
          fit: widget.fit,
          borderRadius: widget.borderRadius,
          heroTag: widget.enableFullScreen ? 'gallery_image_$index' : null,
          onTap: () {
            if (widget.onImageTap != null) {
              widget.onImageTap!(index);
            } else if (widget.enableFullScreen) {
              _showFullScreenImage(context, index, allImages);
            }
          },
        );
      },
    );
  }
  
  void _showFullScreenImage(BuildContext context, int initialIndex, List<String> images) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          images: images,
          initialIndex: initialIndex,
          assetPaths: widget.assetPaths,
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final List<String>? assetPaths;
  
  const FullScreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    this.assetPaths,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.images.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final imageUrl = widget.images[index];
          final isAsset = widget.assetPaths?.contains(imageUrl) ?? false;
          
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: CustomImage(
                imageUrl: isAsset ? null : imageUrl,
                assetPath: isAsset ? imageUrl : null,
                fit: BoxFit.contain,
                heroTag: 'gallery_image_$index',
              ),
            ),
          );
        },
      ),
    );
  }
}

class ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final List<String>? assetPaths;
  final double height;
  final BoxFit fit;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final bool enableInfiniteScroll;
  final bool showIndicators;
  final bool showArrows;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<int>? onPageChanged;
  
  const ImageCarousel({
    super.key,
    required this.imageUrls,
    this.assetPaths,
    required this.height,
    this.fit = BoxFit.cover,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 3),
    this.enableInfiniteScroll = true,
    this.showIndicators = true,
    this.showArrows = false,
    this.borderRadius,
    this.padding,
    this.onPageChanged,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late PageController _pageController;
  int _currentIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    if (widget.autoPlay) {
      _startAutoPlay();
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  void _startAutoPlay() {
    Future.delayed(widget.autoPlayInterval, () {
      if (mounted && widget.autoPlay) {
        final nextIndex = widget.enableInfiniteScroll
            ? (_currentIndex + 1) % _getTotalImages()
            : (_currentIndex + 1).clamp(0, _getTotalImages() - 1);
        
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        
        _startAutoPlay();
      }
    });
  }
  
  int _getTotalImages() {
    return widget.imageUrls.length + (widget.assetPaths?.length ?? 0);
  }
  
  String _getImageAt(int index) {
    if (index < widget.imageUrls.length) {
      return widget.imageUrls[index];
    } else {
      return widget.assetPaths![index - widget.imageUrls.length];
    }
  }
  
  bool _isAssetAt(int index) {
    return index >= widget.imageUrls.length;
  }

  @override
  Widget build(BuildContext context) {
    final totalImages = _getTotalImages();
    
    if (totalImages == 0) {
      return SizedBox(height: widget.height);
    }
    
    return Container(
      height: widget.height,
      padding: widget.padding,
      child: Stack(
        children: [
          // Image PageView
          ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                widget.onPageChanged?.call(index);
              },
              itemCount: widget.enableInfiniteScroll ? null : totalImages,
              itemBuilder: (context, index) {
                final actualIndex = widget.enableInfiniteScroll
                    ? index % totalImages
                    : index;
                
                final imageUrl = _getImageAt(actualIndex);
                final isAsset = _isAssetAt(actualIndex);
                
                return CustomImage(
                  imageUrl: isAsset ? null : imageUrl,
                  assetPath: isAsset ? imageUrl : null,
                  width: double.infinity,
                  height: widget.height,
                  fit: widget.fit,
                );
              },
            ),
          ),
          
          // Navigation arrows
          if (widget.showArrows && totalImages > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: () {
                    final prevIndex = widget.enableInfiniteScroll
                        ? (_currentIndex - 1) % totalImages
                        : (_currentIndex - 1).clamp(0, totalImages - 1);
                    
                    _pageController.animateToPage(
                      prevIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: const Icon(Icons.chevron_left),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: () {
                    final nextIndex = widget.enableInfiniteScroll
                        ? (_currentIndex + 1) % totalImages
                        : (_currentIndex + 1).clamp(0, totalImages - 1);
                    
                    _pageController.animateToPage(
                      nextIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: const Icon(Icons.chevron_right),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
          
          // Page indicators
          if (widget.showIndicators && totalImages > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  totalImages,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}