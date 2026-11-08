import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
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

  Future<void> _loadDocumentBytes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.pdfBytes != null && widget.pdfBytes!.isNotEmpty) {
      setState(() {
        _bytes = widget.pdfBytes;
        _isLoading = false;
      });
      return;
    }

    if (widget.pdfUrl == null || widget.pdfUrl!.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No document URL provided.';
      });
      return;
    }

    try {
      final uri = Uri.parse(widget.pdfUrl!);
      final response = await http.get(uri).timeout(
            const Duration(seconds: 40),
            onTimeout: () => throw 'Connection timed out while loading document.',
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        setState(() {
          _bytes = response.bodyBytes;
          _isLoading = false;
        });
      } else {
        throw 'Server returned status ${response.statusCode}';
      }
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
            onPressed: _loadDocumentBytes,
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
                      onPressed: _loadDocumentBytes,
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
                enableTextSelection: false, // Prevents unauthorized text scraping
                maxScale: 6.0,
                minScale: 0.5,
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
