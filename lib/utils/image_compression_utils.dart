import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Cross-platform utility for compressing and resizing images on the client
/// prior to uploading to Appwrite Storage buckets.
///
/// Ensures compact file sizes, rapid upload times, and low bandwidth usage
/// without data truncation or corruption of documents.
class ImageCompressionUtils {
  ImageCompressionUtils._();

  /// Compresses and centers/crops/resizes an avatar image to a square of max [maxDimension] px.
  /// Typically reduces a 5MB phone selfie down to ~50KB.
  static Uint8List compressAvatar(
    Uint8List rawBytes, {
    int maxDimension = 512,
    int quality = 85,
  }) {
    if (rawBytes.isEmpty) return rawBytes;

    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      // Ensure square aspect ratio for avatar
      img.Image processed;
      if (decoded.width != decoded.height) {
        final minDim = decoded.width < decoded.height ? decoded.width : decoded.height;
        final x = (decoded.width - minDim) ~/ 2;
        final y = (decoded.height - minDim) ~/ 2;
        processed = img.copyCrop(decoded, x: x, y: y, width: minDim, height: minDim);
      } else {
        processed = decoded;
      }

      // Resize down if larger than maxDimension
      if (processed.width > maxDimension || processed.height > maxDimension) {
        processed = img.copyResize(
          processed,
          width: maxDimension,
          height: maxDimension,
          interpolation: img.Interpolation.linear,
        );
      }

      final compressed = img.encodeJpg(processed, quality: quality);
      debugPrint('[ImageCompressionUtils] Avatar compressed: ${rawBytes.lengthInBytes} B -> ${compressed.lengthInBytes} B');
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('[ImageCompressionUtils] Failed to compress avatar: $e. Returning original.');
      return rawBytes;
    }
  }

  /// Compresses a chat image or media attachment down to max [maxDimension] px on its longest side.
  /// Encodes to compact JPEG at [quality]%.
  static Uint8List compressChatImage(
    Uint8List rawBytes, {
    int maxDimension = 1280,
    int quality = 80,
  }) {
    if (rawBytes.isEmpty) return rawBytes;

    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      // Only downscale if larger than maxDimension
      img.Image processed = decoded;
      if (decoded.width > maxDimension || decoded.height > maxDimension) {
        int targetWidth;
        int targetHeight;
        if (decoded.width >= decoded.height) {
          targetWidth = maxDimension;
          targetHeight = (decoded.height * maxDimension) ~/ decoded.width;
        } else {
          targetHeight = maxDimension;
          targetWidth = (decoded.width * maxDimension) ~/ decoded.height;
        }

        processed = img.copyResize(
          decoded,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear,
        );
      }

      final compressed = img.encodeJpg(processed, quality: quality);
      debugPrint('[ImageCompressionUtils] Chat image compressed: ${rawBytes.lengthInBytes} B -> ${compressed.lengthInBytes} B');
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('[ImageCompressionUtils] Failed to compress chat image: $e. Returning original.');
      return rawBytes;
    }
  }

  /// Check if a filename corresponds to a supported raster image extension
  static bool isImageFilename(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }
}

