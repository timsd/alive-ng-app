import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firebase_storage_service.dart';
import '../../constants/app_constants.dart';
import '../../models/tract_models.dart';
import '../../utils/responsive_utils.dart';
import '../../services/donation_service.dart';
import '../../services/auth_service.dart';
import '../../services/tract_service.dart';
import '../../models/donation_models.dart';
import '../materials/donation_dialog.dart';
import '../../widgets/custom_image.dart';

class TractReaderScreen extends StatefulWidget {
  final Tract tract;

  const TractReaderScreen({
    super.key,
    required this.tract,
  });

  @override
  State<TractReaderScreen> createState() => _TractReaderScreenState();
}

class _TractReaderScreenState extends State<TractReaderScreen> {
  final PageController _pageController = PageController();
  final TractService _tractService = TractService();
  final AuthService _authService = AuthService.instance;
  int _currentPage = 0;
  final Map<String, TextEditingController> _answerControllers = {};
  bool _showAnswers = false;
  List<String> _contentPages = [];
  List<Map<String, dynamic>> _reflectionQuestions = [];
  bool _loadingDynamicContent = true;

  @override
  void initState() {
    super.initState();
    _initializeAnswerControllers();
    _loadDynamicTractContent();
  }

  void _initializeAnswerControllers() {
    // Initialize text controllers for interactive questions
    // This would be based on the tract content structure
    for (int i = 1; i <= 10; i++) {
      _answerControllers['question_$i'] = TextEditingController();
    }
  }

  Future<void> _loadDynamicTractContent() async {
    try {
      final tractContent = await _tractService.getTractContent(widget.tract.id);
      if (tractContent == null) {
        if (mounted) {
          setState(() {
            _loadingDynamicContent = false;
          });
        }
        return;
      }

      final extractedText = tractContent.content.trim();
      final rawPages = tractContent.metadata?['pages'];

      List<String> pages = [];
      if (rawPages is List) {
        pages = rawPages
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (pages.isEmpty && extractedText.isNotEmpty) {
        pages = _chunkText(extractedText, 2200);
      }

      final questions = tractContent.questions
          .map((question) => question.toJson())
          .toList(growable: false);

      for (int i = 1; i <= questions.length; i++) {
        _answerControllers.putIfAbsent(
            'question_$i', () => TextEditingController());
      }

      if (!mounted) return;
      setState(() {
        _contentPages = pages;
        _reflectionQuestions = questions;
        _loadingDynamicContent = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDynamicContent = false;
      });
    }
  }

  Future<String?> _resolveDirectPdfUrl() async {
    final existingUrl = widget.tract.downloadUrl?.trim();
    if (existingUrl != null && existingUrl.isNotEmpty) return existingUrl;
    return FirebaseStorageService().getTractDownloadURL('${widget.tract.id}.pdf');
  }

  List<String> _chunkText(String text, int chunkSize) {
    final normalized = text.replaceAll(RegExp(r'\r\n?'), '\n').trim();
    if (normalized.isEmpty) return const [];
    final chunks = <String>[];
    int cursor = 0;
    while (cursor < normalized.length) {
      int end = cursor + chunkSize;
      if (end >= normalized.length) {
        chunks.add(normalized.substring(cursor).trim());
        break;
      }
      final splitAt = normalized.lastIndexOf('\n', end);
      if (splitAt > cursor + (chunkSize ~/ 3)) {
        chunks.add(normalized.substring(cursor, splitAt).trim());
        cursor = splitAt + 1;
      } else {
        chunks.add(normalized.substring(cursor, end).trim());
        cursor = end;
      }
    }
    return chunks.where((e) => e.isNotEmpty).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.tract.title,
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 18.0,
              tablet: 20.0,
              desktop: 22.0,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _viewOriginalPDF,
            tooltip: 'View Original PDF',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadTract,
            tooltip: 'Download Tract',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareTract,
            tooltip: 'Share Tract',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'toggle_answers':
                  setState(() {
                    _showAnswers = !_showAnswers;
                  });
                  break;
                case 'reset_answers':
                  _resetAnswers();
                  break;
                case 'save_progress':
                  _saveProgress();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_answers',
                child: Row(
                  children: [
                    Icon(
                        _showAnswers ? Icons.visibility_off : Icons.visibility),
                    const SizedBox(width: 8),
                    Text(_showAnswers ? 'Hide Answers' : 'Show Answers'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset_answers',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Reset Answers'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'save_progress',
                child: Row(
                  children: [
                    Icon(Icons.save),
                    SizedBox(width: 8),
                    Text('Save Progress'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page ${_currentPage + 1} of ${_getTotalPages()}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      widget.tract.category.tractDisplayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentPage + 1) / _getTotalPages(),
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _getTotalPages(),
              itemBuilder: (context, index) {
                return _buildTractPage(index);
              },
            ),
          ),

          // Navigation controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentPage > 0 ? _previousPage : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
                Text(
                  '${_currentPage + 1} / ${_getTotalPages()}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                ElevatedButton.icon(
                  onPressed:
                      _currentPage < _getTotalPages() - 1 ? _nextPage : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTractPage(int pageIndex) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pageIndex == 0) _buildCoverPage(),
              if (pageIndex > 0) _buildContentPage(pageIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tract cover image section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // Prefer cover image; fallback to series image
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CustomImage(
                  imageUrl: widget.tract.primaryCover,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(10),
                  placeholder:
                      _buildPassportAvatar(""),
                ),
              ),

              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.tract.category.tractDisplayName.toUpperCase()} SERIES',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 10.0,
                      tablet: 12.0,
                      desktop: 14.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 20.0,
          tablet: 24.0,
          desktop: 28.0,
        )),

        // Title
        Text(
          widget.tract.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 20.0,
                  tablet: 24.0,
                  desktop: 28.0,
                ),
              ),
          textAlign: TextAlign.center,
        ),
        SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 12.0,
          tablet: 16.0,
          desktop: 20.0,
        )),

        // Author
        Text(
          'By ${widget.tract.author}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
              ),
          textAlign: TextAlign.center,
        ),
        SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 20.0,
          tablet: 24.0,
          desktop: 28.0,
        )),

        // Description
        Container(
          padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 14.0,
            tablet: 16.0,
            desktop: 18.0,
          )),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Text(
            widget.tract.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,
                  ),
                ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 20.0,
          tablet: 24.0,
          desktop: 28.0,
        )),

        // Enhanced Support ministry banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[100]!, Colors.green[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[300]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.volunteer_activism,
                      color: Colors.green[800],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support Gospel Ministry',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You can reuse any of this tract. Each downloads help fund tract printing & outreach',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.green[700],
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDonationInfo(),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Learn More'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        side: BorderSide(color: Colors.green[400]!),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(120, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openDonationPage,
                      icon: const Icon(Icons.favorite, size: 18),
                      label: const Text('Donate Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        minimumSize: const Size(120, 48),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 16.0,
          tablet: 18.0,
          desktop: 20.0,
        )),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pages,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 18.0,
                tablet: 20.0,
                desktop: 22.0,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.tract.pages} pages',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 14.0,
                      tablet: 16.0,
                      desktop: 18.0,
                    ),
                  ),
            ),
          ],
        ),
        SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 28.0,
          tablet: 32.0,
          desktop: 36.0,
        )),

        Text(
          'Copyright © ALIVE-NG, ALIVE by the Truth',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 12.0,
                  tablet: 14.0,
                  desktop: 16.0,
                ),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Helper method to build passport-sized avatars
  Widget _buildPassportAvatar(String imagePath) {
    return Container(
      width: ResponsiveUtils.getResponsiveValue(
        context: context,
        mobile: 80.0,
        tablet: 90.0,
        desktop: 100.0,
      ),
      height: ResponsiveUtils.getResponsiveValue(
        context: context,
        mobile: 100.0,
        tablet: 110.0,
        desktop: 120.0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Icon(
                Icons.auto_stories,
                size: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 32.0,
                  tablet: 36.0,
                  desktop: 40.0,
                ),
                color: Theme.of(context).primaryColor,
              ),
            );
          },
        ),
      ),
    );
  }

  // Duplicate _buildContentPage removed (kept original earlier definition)

  // Duplicate _buildQuestionSection removed (kept original earlier definition)

  // Duplicate _getSampleContent and _getSampleQuestion removed (kept original earlier definitions)

  int _getTotalPages() {
    final dynamicPages = _contentPages.length;
    if (dynamicPages > 0) {
      return dynamicPages + 1; // +1 for cover page
    }
    return (widget.tract.pages ?? 0) + 1; // +1 for cover page
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _getTotalPages() - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _viewOriginalPDF() async {
    final rootCtx = context;
    try {
      final donationService = DonationService();
      DownloadableMaterial? material;
      try {
        material = await donationService.getMaterialById(widget.tract.id);
      } catch (_) {
        material = null;
      }

      if (material != null) {
        final canDownload =
            await donationService.canUserDownloadMaterial(material.id);
        if (!canDownload && material.requiresDonation) {
          if (!mounted) return;
          final donated = await showDialog<bool>(
            context: context,
            builder: (context) => DonationDialog(
              material: material!,
              donationType: DonationType.tractReprint,
            ),
          );
          if (donated != true) return;
        }

        final downloadUrl =
            await donationService.generateDownloadUrl(material.id);
        if (await canLaunchUrl(Uri.parse(downloadUrl))) {
          await launchUrl(Uri.parse(downloadUrl),
              mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch PDF viewer';
        }
        return;
      }

      // Fallback to direct Storage URL if material is not registered
      final String? pdfUrl = await _resolveDirectPdfUrl();
      if (pdfUrl != null && await canLaunchUrl(Uri.parse(pdfUrl))) {
        await launchUrl(Uri.parse(pdfUrl),
            mode: LaunchMode.externalApplication);
        if (!rootCtx.mounted) return;
        _showDonationDialog(rootCtx);
      } else {
        throw 'Could not launch PDF viewer';
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error opening PDF: $e'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
    }
  }

  void _downloadTract() async {
    final rootCtx = context;
    try {
      final donationService = DonationService();
      DownloadableMaterial? material;
      try {
        material = await donationService.getMaterialById(widget.tract.id);
      } catch (_) {
        material = null;
      }

      if (material != null) {
        final canDownload =
            await donationService.canUserDownloadMaterial(material.id);
        if (!canDownload && material.requiresDonation) {
          if (!mounted) return;
          final donated = await showDialog<bool>(
            context: context,
            builder: (context) => DonationDialog(
              material: material!,
              donationType: DonationType.tractReprint,
            ),
          );
          if (donated != true) return;
        }

        final downloadUrl =
            await donationService.generateDownloadUrl(material.id);
        if (await canLaunchUrl(Uri.parse(downloadUrl))) {
          await launchUrl(Uri.parse(downloadUrl),
              mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloading ${widget.tract.title}...'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw 'Could not launch downloaded tract';
        }
        return;
      }

      // Fallback: direct Storage URL and optional donation prompt
      final String? pdfUrl = await _resolveDirectPdfUrl();
      if (pdfUrl != null && await canLaunchUrl(Uri.parse(pdfUrl))) {
        await launchUrl(Uri.parse(pdfUrl),
            mode: LaunchMode.externalApplication);
        if (!rootCtx.mounted) return;
        _showDonationDialog(rootCtx);
      } else {
        throw 'Could not launch downloaded tract';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download tract: $e')),
      );
    }
  }

  void _showDonationDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('Support Our Ministry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Thank you for downloading this tract! Your support helps us continue spreading the Gospel.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Consider making a donation to support ALIVE-NG ministry.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openDonationPage();
            },
            child: const Text('Donate Now'),
          ),
        ],
      ),
    );
  }

  void _openDonationPage() {
    // Navigate to in-app donation page
    context.go(AppConstants.donationRoute);
  }

  void _shareTract() async {
    try {
      final shareText = '''
Check out this amazing tract: "${widget.tract.title}" by ${widget.tract.author}

${widget.tract.description}

Download it from ALIVE-NG App www.app.alivenigeria.org

#ALIVE-NG #Gospel #ChristianTract
      '''
          .trim();

      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'Check out this tract: ${widget.tract.title}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing tract: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetAnswers() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Answers'),
        content: const Text(
            'Are you sure you want to clear all your answers? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              for (var controller in _answerControllers.values) {
                controller.clear();
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All answers have been cleared')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showDonationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.volunteer_activism, color: Colors.green[700]),
            const SizedBox(width: 8),
            const Text('How Your Support Helps'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem(
              icon: Icons.print,
              title: 'Tract Printing',
              description: 'Fund physical tract production for distribution',
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              icon: Icons.campaign,
              title: 'Outreach Programs',
              description: 'Support evangelism and community outreach',
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              icon: Icons.library_books,
              title: 'Literature Development',
              description: 'Create new gospel materials and resources',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Every download helps track impact and plan future resources',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openDonationPage();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Donate Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green[100],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.green[700], size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentPage(int pageIndex) {
    final contentIndex = pageIndex - 1;
    final hasDynamicContent =
        _contentPages.isNotEmpty && contentIndex >= 0 && contentIndex < _contentPages.length;
    final dynamicText = hasDynamicContent ? _contentPages[contentIndex] : null;
    final hasDynamicQuestion =
        _reflectionQuestions.isNotEmpty &&
            contentIndex >= 0 &&
            contentIndex < _reflectionQuestions.length;
    final question = hasDynamicQuestion ? _reflectionQuestions[contentIndex] : null;

    if (_loadingDynamicContent && _contentPages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lesson $pageIndex',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
        ),
        const SizedBox(height: 16),

        // Sample content
        Text(
          dynamicText ?? _getSampleContent(pageIndex),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
        ),
        const SizedBox(height: 24),

        // Interactive question section
        if (pageIndex <= 10 || question != null)
          _buildQuestionSection(pageIndex, question: question),

        const SizedBox(height: 24),

        // Bible verse reference
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Bible Reference',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showBibleVerseDialog(
                    _getSampleBibleVerse(pageIndex),
                    _getBibleReference(pageIndex)),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue[300]!),
                  ),
                  child: Text(
                    _getSampleBibleVerse(pageIndex),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.blue[800],
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionSection(int pageIndex, {Map<String, dynamic>? question}) {
    final prompt = (question?['question'] ??
            question?['prompt'] ??
            question?['text'] ??
            _getSampleQuestion(pageIndex))
        .toString();
    final suggested = (question?['suggested_answer'] ??
            question?['answer'] ??
            question?['model_answer'] ??
            _getSampleAnswer(pageIndex))
        .toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Text(
                'Reflection Question',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            prompt,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _answerControllers['question_$pageIndex'],
            decoration: InputDecoration(
              hintText: 'Type your answer here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: 3,
            onChanged: (value) {
              // Auto-save functionality could be implemented here
            },
          ),
          if (_showAnswers) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.green[700], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Suggested Answer:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggested,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getSampleContent(int pageIndex) {
    // Sample content for demonstration - in real implementation,
    // this would come from the actual tract content
    switch (pageIndex) {
      case 1:
        return "Welcome to this study on what the Bible says about salvation. Throughout this series, we will explore the fundamental truths that God has revealed to us through His Word. Each lesson builds upon the previous one, creating a comprehensive understanding of God's plan for humanity.";
      case 2:
        return "The Bible teaches us that all have sinned and fall short of the glory of God (Romans 3:23). This universal condition affects every person born into this world, separating us from our Creator and requiring divine intervention for reconciliation.";
      default:
        return "This lesson continues our exploration of biblical truth, examining the scriptures to understand God's will for our lives. Through careful study and prayer, we can discover the wonderful truths that God has preserved for us in His Word.";
    }
  }

  String _getSampleQuestion(int pageIndex) {
    switch (pageIndex) {
      case 1:
        return "What does it mean to you personally that God has provided a way of salvation?";
      case 2:
        return "How does understanding our sinful condition help us appreciate God's grace?";
      default:
        return "What key truth from this lesson will you apply to your daily life?";
    }
  }

  String _getSampleAnswer(int pageIndex) {
    switch (pageIndex) {
      case 1:
        return "God's provision of salvation demonstrates His incredible love and mercy. It means that despite our failures, we have hope for eternal life through Jesus Christ.";
      case 2:
        return "Recognizing our sinful nature helps us understand that salvation is entirely by God's grace, not by our own works or merit.";
      default:
        return "Each lesson provides practical truths that can transform our daily walk with God when applied with faith and commitment.";
    }
  }

  String _getSampleBibleVerse(int pageIndex) {
    switch (pageIndex) {
      case 1:
        return "\"For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.\" - John 3:16";
      case 2:
        return "\"For all have sinned and fall short of the glory of God, and all are justified freely by his grace through the redemption that came by Christ Jesus.\" - Romans 3:23-24";
      default:
        return "\"All Scripture is God-breathed and is useful for teaching, rebuking, correcting and training in righteousness.\" - 2 Timothy 3:16";
    }
  }

  String _getBibleReference(int pageIndex) {
    switch (pageIndex) {
      case 1:
        return "John 3:16";
      case 2:
        return "Romans 3:23-24";
      default:
        return "2 Timothy 3:16";
    }
  }

  void _showBibleVerseDialog(String verse, String reference) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.menu_book, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(
              reference,
              style: TextStyle(color: Colors.blue[700]),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verse,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap "Read More" to explore this passage in context.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openBibleApp(reference);
            },
            child: const Text('Read More'),
          ),
        ],
      ),
    );
  }

  void _openBibleApp(String reference) async {
    final rootCtx = context;
    // Try to open in Bible app or web browser
    final bibleUrls = [
      'bible://$reference', // Bible app protocol
      'https://www.biblegateway.com/passage/?search=${Uri.encodeComponent(reference)}&version=NIV',
    ];

    for (String url in bibleUrls) {
      try {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {
        continue;
      }
    }

    // Fallback message
    if (!rootCtx.mounted) return;
    ScaffoldMessenger.of(rootCtx).showSnackBar(
      SnackBar(
        content: Text(
            'Please install a Bible app or visit BibleGateway.com to read $reference'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _saveProgress() async {
    final rootCtx = context;
    try {
      // Collect all answers
      Map<String, String> answers = {};
      _answerControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) {
          answers[key] = controller.text;
        }
      });

      final user = _authService.currentUser;
      if (user != null) {
        await _tractService.saveTractProgress(
          TractProgress(
            id: '${user.uid}_${widget.tract.id}',
            userId: user.uid,
            tractId: widget.tract.id,
            currentPage: _currentPage,
            isCompleted: _currentPage >= _getTotalPages() - 1,
            lastUpdated: DateTime.now(),
          ),
        );
        if (answers.isNotEmpty) {
          await _tractService.saveUserAnswers(user.uid, widget.tract.id, answers);
        }

        if (!rootCtx.mounted) return;
        ScaffoldMessenger.of(rootCtx).showSnackBar(
          const SnackBar(
            content: Text('Progress saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw 'User not authenticated';
      }
    } catch (e) {
      if (!rootCtx.mounted) return;
      ScaffoldMessenger.of(rootCtx).showSnackBar(
        SnackBar(
          content: Text('Error saving progress: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
