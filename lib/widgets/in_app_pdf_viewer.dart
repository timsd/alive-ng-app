import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/error_handler.dart';
import '../widgets/custom_app_bar.dart';

/// Secure in-app PDF Viewer Screen that renders documents directly onto the
/// Flutter canvas using pdfrx (PDFium engine).
///
/// Documents are loaded strictly into memory (RAM) as raw bytes (Uint8List).
/// This prevents Google Docs Viewer URL exposure, prevents automatic linking
/// to personal Google accounts, and removes external browser download toolbars.
class InAppPdfViewerScreen extends StatefulWidget {
  final String title;
  final String? pdfUrl;
  final Uint8List? pdfBytes;

  const InAppPdfViewerScreen({
    super.key,
    required this.title,
    this.pdfUrl,
    this.pdfBytes,
  }) : assert(pdfUrl != null || pdfBytes != null,
            'Either pdfUrl or pdfBytes must be provided');

  @override
  State<InAppPdfViewerScreen> createState() => _InAppPdfViewerScreenState();
}

class _InAppPdfViewerScreenState extends State<InAppPdfViewerScreen> {
  static const int _maxCachedPdfs = 5;
  static final Map<String, Uint8List> _pdfMemoryCache = {};

  static void _putPdfCache(String key, Uint8List bytes) {
    _pdfMemoryCache.remove(key);
    _pdfMemoryCache[key] = bytes;
    while (_pdfMemoryCache.length > _maxCachedPdfs) {
      _pdfMemoryCache.remove(_pdfMemoryCache.keys.first);
    }
  }

  final PdfViewerController _pdfController = PdfViewerController();
  Uint8List? _bytes;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadDocumentBytes();
  }

  static bool _isValidPdfBytes(Uint8List bytes) {
    if (bytes.length < 5) return false;
    // Allow optional leading whitespace/BOM before %PDF-
    final limit = bytes.length < 64 ? bytes.length - 5 : 59;
    for (int i = 0; i <= limit; i++) {
      if (bytes[i] == 0x25 && // %
          bytes[i + 1] == 0x50 && // P
          bytes[i + 2] == 0x44 && // D
          bytes[i + 3] == 0x46 && // F
          bytes[i + 4] == 0x2D) { // -
        return true;
      }
    }
    return false;
  }

  static ({String bucketId, String fileId})? _parseAppwriteStorageTarget(
      String url) {
    final uri = Uri.tryParse(url);
    final endpointUri = Uri.tryParse(AppwriteBackendConfig.endpoint);
    if (uri == null || endpointUri == null) return null;
    if (uri.host.toLowerCase() != endpointUri.host.toLowerCase()) return null;
    final segs = uri.pathSegments;
    final bIdx = segs.indexOf('buckets');
    final fIdx = segs.indexOf('files');
    if (bIdx == -1 ||
        fIdx == -1 ||
        bIdx + 1 >= segs.length ||
        fIdx + 1 >= segs.length) {
      return null;
    }
    return (bucketId: segs[bIdx + 1], fileId: segs[fIdx + 1]);
  }

  Future<void> _loadDocumentBytes({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.pdfBytes != null && widget.pdfBytes!.isNotEmpty) {
      if (!_isValidPdfBytes(widget.pdfBytes!)) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'The selected file is not a valid PDF document.';
        });
        return;
      }
      setState(() {
        _bytes = widget.pdfBytes;
        _isLoading = false;
      });
      return;
    }

    final url = widget.pdfUrl?.trim();
    if (url == null || url.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No document URL provided.';
      });
      return;
    }

    // Check fast in-memory cache first for instant 0ms preview (unless reloaded)
    if (!forceRefresh && _pdfMemoryCache.containsKey(url)) {
      setState(() {
        _bytes = _pdfMemoryCache[url];
        _isLoading = false;
      });
      return;
    }
    if (forceRefresh) {
      _pdfMemoryCache.remove(url);
    }

    try {
      Uint8List? downloadedBytes;

      // For Appwrite Storage URLs, fetch via authenticated Appwrite Storage SDK first
      // so private buckets (e.g. board_documents / meeting_files) work seamlessly.
      final storageTarget = _parseAppwriteStorageTarget(url);
      if (storageTarget != null) {
        try {
          downloadedBytes = await Storage(appwriteClient)
              .getFileView(
                bucketId: storageTarget.bucketId,
                fileId: storageTarget.fileId,
              )
              .timeout(const Duration(seconds: 25));
        } catch (sdkErr) {
          debugPrint('Appwrite Storage authenticated PDF fetch fallback: $sdkErr');
        }
      }

      if (downloadedBytes == null || downloadedBytes.isEmpty) {
        final uri = Uri.parse(url);
        http.Response? response;

        // Resilient attempt with quick automatic retry on transient mobile packet drops
        for (int attempt = 1; attempt <= 2; attempt++) {
          try {
            response = await http.get(uri).timeout(
                  const Duration(seconds: 25),
                );
            if (response.statusCode >= 200 && response.statusCode < 300) {
              break;
            }
          } catch (e) {
            if (attempt == 2) rethrow;
            await Future.delayed(const Duration(milliseconds: 800));
          }
        }

        if (response != null &&
            response.statusCode >= 200 &&
            response.statusCode < 300) {
          downloadedBytes = response.bodyBytes;
        } else {
          throw 'Server returned status ${response?.statusCode ?? 500}';
        }
      }

      if (!_isValidPdfBytes(downloadedBytes)) {
        throw 'The server did not return a valid PDF document (you may not have permission to view this file).';
      }

      if (!mounted) return;
      _putPdfCache(url, downloadedBytes);
      setState(() {
        _bytes = downloadedBytes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: widget.title,
        showBackButton: true,
        actions: [
          if (_totalPages > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload Document',
            onPressed: () => _loadDocumentBytes(forceRefresh: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Document View Error',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _loadDocumentBytes(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_bytes != null)
            PdfViewer.data(
              _bytes!,
              sourceName: widget.title,
              controller: _pdfController,
              params: PdfViewerParams(
                backgroundColor: theme.scaffoldBackgroundColor,
                sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
                  maxScale: 6.0,
                  minScale: 0.5,
                ),
                margin: 8.0,
                onViewerReady: (document, controller) {
                  if (mounted) {
                    setState(() {
                      _totalPages = document.pages.length;
                    });
                  }
                },
                onPageChanged: (pageNumber) {
                  if (mounted && pageNumber != null) {
                    setState(() {
                      _currentPage = pageNumber;
                    });
                  }
                },
              ),
            ),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _bytes != null && _totalPages > 0
          ? SafeArea(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_out_rounded, size: 20),
                      tooltip: 'Zoom Out',
                      onPressed: () {
                        _pdfController.zoomDown();
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.fit_screen_rounded, size: 20),
                      tooltip: 'Fit to Width',
                      onPressed: () {
                        final m = _pdfController.calcMatrixFitWidthForPage(
                          pageNumber: _currentPage,
                        );
                        if (m != null) {
                          _pdfController.goTo(m);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.zoom_in_rounded, size: 20),
                      tooltip: 'Zoom In',
                      onPressed: () {
                        _pdfController.zoomUp();
                      },
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
