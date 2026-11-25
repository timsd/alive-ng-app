import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/billboard_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_image.dart';
import '../../widgets/modern_dropdown.dart';
import '../../widgets/video_embed_view.dart';

/// Reusable Program & Project Billboard / Showcase screen.
///
/// Serves `/billboard`, `/showcase`, `/project-3d-viewer`, and
/// `/alive_ng_3d_viewer.html`, rendering admin-configured flyers, videos
/// (both 16:9 and 9:16), registration forms (inbuilt or external), or
/// interactive 3D HTML scenes.
class Project3DViewerScreen extends StatefulWidget {
  final String viewerUrl;

  const Project3DViewerScreen({
    super.key,
    this.viewerUrl = '',
  });

  @override
  State<Project3DViewerScreen> createState() => _Project3DViewerScreenState();
}

class _Project3DViewerScreenState extends State<Project3DViewerScreen> {
  BillboardConfig _config = const BillboardConfig();
  bool _loading = true;
  bool _showInbuiltForm = false;
  bool _submittingForm = false;
  bool _submitted = false;
  WebViewController? _webViewController;

  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _textCtrls = {};
  final Map<String, String> _dropdownValues = {};
  final Map<String, Set<String>> _checkboxValues = {};

  @override
  void initState() {
    super.initState();
    _initBillboard();
  }

  @override
  void dispose() {
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isAllowedViewerUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;
    // Allow local bundled/same-origin relative paths (no traversal, no scheme)
    if (!trimmed.contains('://') && !trimmed.startsWith('//') && !trimmed.contains('..')) {
      return !trimmed.toLowerCase().startsWith('javascript:') &&
          !trimmed.toLowerCase().startsWith('data:');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host == 'app.alivenigeria.org' ||
        host == 'alivenigeria.org' ||
        host.endsWith('.alivenigeria.org') ||
        host == 'youtube.com' ||
        host == 'www.youtube.com' ||
        host == 'youtu.be' ||
        host == 'www.youtube-nocookie.com' ||
        host == 'vimeo.com' ||
        host == 'player.vimeo.com';
  }

  Future<void> _initBillboard() async {
    final rawExplicit = widget.viewerUrl.trim();
    final explicit = _isAllowedViewerUrl(rawExplicit) ? rawExplicit : '';
    final fetched = await BillboardService.instance.fetchConfig();
    BillboardConfig active = fetched;

    if (explicit.isNotEmpty &&
        explicit != 'alive_ng_3d_viewer.html' &&
        explicit != fetched.mediaUrl) {
      active = BillboardConfig(
        isEnabled: true,
        contentType: _inferType(explicit),
        title: 'Featured Showcase',
        mediaUrl: explicit,
      );
    }

    if (!mounted) return;
    _config = active;
    _prepareFormControllers(active);

    if (active.contentType == 'form' && !_isExternalHttpUrl(active.mediaUrl)) {
      _showInbuiltForm = true;
    }

    if (!kIsWeb && active.contentType != 'flyer' && !_showInbuiltForm) {
      final targetUrl = _resolveWebOrEmbedUrl(active);
      final headers = active.contentType == 'video'
          ? const {'Referer': 'https://app.alivenigeria.org/'}
          : const <String, String>{};
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0F172A))
        ..loadRequest(Uri.parse(targetUrl), headers: headers);
    }

    setState(() => _loading = false);
  }

  void _prepareFormControllers(BillboardConfig cfg) {
    final user = AuthService.instance.currentUser;
    for (final field in cfg.formFields) {
      if (field.type == 'dropdown' || field.type == 'radio') {
        if (field.options.isNotEmpty) {
          _dropdownValues[field.key] = field.options.first;
        }
      } else if (field.type == 'checkbox') {
        _checkboxValues[field.key] = <String>{};
      } else {
        String initial = '';
        if (user != null) {
          final k = field.key.toLowerCase();
          if (k == 'full_name' || k == 'name') {
            initial = user.displayName ?? '';
          } else if (k == 'email') {
            initial = user.email;
          }
        }
        _textCtrls[field.key] = TextEditingController(text: initial);
      }
    }
  }

  bool _isExternalHttpUrl(String url) {
    final lower = url.trim().toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  String _inferType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'video';
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp')) {
      return 'flyer';
    }
    if (lower.contains('forms.gle') || lower.contains('docs.google.com/forms')) {
      return 'form';
    }
    return '3d_html';
  }

  String? _extractYouTubeId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    if (uri.host.contains('youtube.com')) {
      if (uri.pathSegments.contains('embed') && uri.pathSegments.length >= 2) {
        return uri.pathSegments[uri.pathSegments.indexOf('embed') + 1];
      }
      if (uri.pathSegments.contains('shorts') && uri.pathSegments.length >= 2) {
        return uri.pathSegments[uri.pathSegments.indexOf('shorts') + 1];
      }
      return uri.queryParameters['v'];
    }
    return null;
  }

  double? _effectiveAspectRatio(BillboardConfig cfg) {
    if (cfg.aspectRatio == '16:9') return 16 / 9;
    if (cfg.aspectRatio == '9:16') return 9 / 16;
    if (cfg.contentType == 'video') {
      if (cfg.mediaUrl.toLowerCase().contains('/shorts/')) {
        return 9 / 16;
      }
      return 16 / 9;
    }
    return null;
  }

  String _resolveWebOrEmbedUrl(BillboardConfig cfg) {
    final target = cfg.mediaUrl.trim().isEmpty
        ? 'alive_ng_3d_viewer.html'
        : cfg.mediaUrl.trim();
    if (cfg.contentType == 'video') {
      final ytId = _extractYouTubeId(target);
      if (ytId != null && ytId.isNotEmpty) {
        final origin = (kIsWeb && Uri.base.scheme.startsWith('http'))
            ? Uri.encodeComponent(Uri.base.origin)
            : 'https%3A%2F%2Fapp.alivenigeria.org';
        return 'https://www.youtube.com/embed/$ytId?autoplay=1&playsinline=1&rel=0&enablejsapi=1&origin=$origin';
      }
    }
    if (target.startsWith('http://') || target.startsWith('https://')) {
      return target;
    }
    final cleanPath = target.startsWith('/') ? target.substring(1) : target;
    if (kIsWeb && Uri.base.scheme.startsWith('http')) {
      return '${Uri.base.origin}/$cleanPath';
    }
    return 'https://app.alivenigeria.org/$cleanPath';
  }

  Future<void> _openExternal(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.startsWith('/')) {
      if (mounted) context.push(trimmed);
      return;
    }
    final resolved =
        (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
            ? trimmed
            : 'https://app.alivenigeria.org/${trimmed.startsWith('/') ? trimmed.substring(1) : trimmed}';
    final uri = Uri.tryParse(resolved);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleShowcaseAction() {
    if (_config.attachInbuiltForm) {
      setState(() {
        _showInbuiltForm = true;
        _submitted = false;
      });
      return;
    }
    if (_config.ctaUrl.trim().isNotEmpty) {
      _openExternal(_config.ctaUrl);
    }
  }

  Future<void> _submitInbuiltForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submittingForm = true);
    try {
      final user = AuthService.instance.currentUser;
      final answers = <String, dynamic>{};
      String fullName = user?.displayName ?? '';
      String email = user?.email ?? '';
      String phone = '';

      for (final field in _config.formFields) {
        final String value;
        if (field.type == 'dropdown' || field.type == 'radio') {
          value = _dropdownValues[field.key] ?? '';
        } else if (field.type == 'checkbox') {
          final selected = _checkboxValues[field.key] ?? const <String>{};
          if (field.required && selected.isEmpty) {
            setState(() => _submittingForm = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please select at least one option for ${field.label}')),
            );
            return;
          }
          value = selected.join(', ');
        } else {
          value = _textCtrls[field.key]?.text.trim() ?? '';
        }
        answers[field.label] = value;

        final k = field.key.toLowerCase();
        if ((k == 'full_name' || k == 'name') && value.isNotEmpty) {
          fullName = value;
        } else if (k == 'email' && value.isNotEmpty) {
          email = value;
        } else if ((k == 'phone' || k == 'phone_number') && value.isNotEmpty) {
          phone = value;
        }
      }

      await BillboardService.instance.submitFormResponse(
        programTitle: _config.title,
        userId: user?.uid ?? '',
        fullName: fullName,
        email: email,
        phone: phone,
        answers: answers,
      );

      if (!mounted) return;
      setState(() {
        _submittingForm = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submittingForm = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getUserFriendlyMessage(e))),
      );
    }
  }

  Widget _buildMediaWithAspectRatio(Widget mediaWidget, double? ratio) {
    if (ratio == null) return mediaWidget;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ratio < 1 ? 420 : 960,
        ),
        child: AspectRatio(
          aspectRatio: ratio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: mediaWidget,
          ),
        ),
      ),
    );
  }

  Widget _buildInbuiltFormView(ThemeData theme) {
    if (_submitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Submission Received!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thank you for registering for ${_config.title}. Your response has been saved.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (_config.contentType != 'form')
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() {
                                _showInbuiltForm = false;
                                _submitted = false;
                              }),
                              child: const Text('Back to Showcase'),
                            ),
                          ),
                        if (_config.contentType != 'form')
                          const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Text('Done'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_config.contentType != 'form')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showInbuiltForm = false),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back to Flyer / Video'),
                    ),
                  ),
                Text(
                  _config.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_config.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _config.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ..._config.formFields.map((field) {
                  if (field.type == 'dropdown' && field.options.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ModernDropdownFormField<String>(
                        value: _dropdownValues[field.key] ?? field.options.first,
                        decoration: InputDecoration(
                          labelText: field.required
                              ? '${field.label} *'
                              : field.label,
                          border: const OutlineInputBorder(),
                        ),
                        items: field.options
                            .map((opt) => DropdownMenuItem(
                                  value: opt,
                                  child: Text(opt),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _dropdownValues[field.key] = val);
                          }
                        },
                      ),
                    );
                  }

                  if (field.type == 'radio' && field.options.isNotEmpty) {
                    final current =
                        _dropdownValues[field.key] ?? field.options.first;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                field.required
                                    ? '${field.label} *'
                                    : field.label,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              RadioGroup<String>(
                                groupValue: current,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(
                                        () => _dropdownValues[field.key] = val);
                                  }
                                },
                                child: Column(
                                  children: field.options
                                      .map(
                                        (opt) => RadioListTile<String>(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: Text(opt),
                                          value: opt,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (field.type == 'checkbox' && field.options.isNotEmpty) {
                    final selected =
                        _checkboxValues[field.key] ??= <String>{};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                field.required
                                    ? '${field.label} *'
                                    : field.label,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...field.options.map(
                                (opt) => CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(opt),
                                  value: selected.contains(opt),
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        selected.add(opt);
                                      } else {
                                        selected.remove(opt);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (field.type == 'date') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextFormField(
                        controller: _textCtrls[field.key],
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText:
                              field.required ? '${field.label} *' : field.label,
                          hintText: 'Select date',
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: DateTime(1920),
                            lastDate: DateTime(now.year + 10),
                          );
                          if (picked != null) {
                            _textCtrls[field.key]?.text =
                                '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          }
                        },
                        validator: (val) {
                          if (field.required && (val?.trim().isEmpty ?? true)) {
                            return '${field.label} is required';
                          }
                          return null;
                        },
                      ),
                    );
                  }

                  final keyboard = switch (field.type) {
                    'email' => TextInputType.emailAddress,
                    'phone' => TextInputType.phone,
                    'number' => TextInputType.number,
                    'multiline' => TextInputType.multiline,
                    _ => TextInputType.text,
                  };

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      controller: _textCtrls[field.key],
                      keyboardType: keyboard,
                      maxLines: field.type == 'multiline' ? 3 : 1,
                      decoration: InputDecoration(
                        labelText:
                            field.required ? '${field.label} *' : field.label,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        final text = val?.trim() ?? '';
                        if (field.required && text.isEmpty) {
                          return '${field.label} is required';
                        }
                        if (field.type == 'email' &&
                            text.isNotEmpty &&
                            !text.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  );
                }),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _submittingForm ? null : _submitInbuiltForm,
                  icon: _submittingForm
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _submittingForm ? 'Submitting...' : 'Submit Registration',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = _resolveWebOrEmbedUrl(_config);
    final hasAction =
        _config.attachInbuiltForm || _config.ctaUrl.trim().isNotEmpty;
    final ratio = _effectiveAspectRatio(_config);

    return Scaffold(
      appBar: CustomAppBar(
        title: _loading ? 'Showcase Billboard' : _config.title,
        showBackButton: true,
        actions: [
          if (!_loading &&
              !_showInbuiltForm &&
              _config.mediaUrl.trim().isNotEmpty &&
              _config.mediaUrl.trim() != 'inbuilt')
            IconButton(
              tooltip: 'Open in browser',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => _openExternal(
                _config.ctaUrl.trim().isNotEmpty
                    ? _config.ctaUrl
                    : _config.mediaUrl,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _showInbuiltForm
              ? _buildInbuiltFormView(theme)
              : _config.contentType == 'flyer'
                  ? Column(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: hasAction ? _handleShowcaseAction : null,
                            child: Padding(
                              padding: ratio != null
                                  ? const EdgeInsets.all(12)
                                  : EdgeInsets.zero,
                              child: _buildMediaWithAspectRatio(
                                InteractiveViewer(
                                  minScale: 0.8,
                                  maxScale: 4.0,
                                  child: Center(
                                    child: CustomImage(
                                      imageUrl: url,
                                      fit: ratio != null
                                          ? BoxFit.cover
                                          : BoxFit.contain,
                                    ),
                                  ),
                                ),
                                ratio,
                              ),
                            ),
                          ),
                        ),
                        if (_config.subtitle.trim().isNotEmpty || hasAction)
                          SafeArea(
                            top: false,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                border: Border(
                                  top: BorderSide(color: theme.dividerColor),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_config.subtitle.trim().isNotEmpty) ...[
                                    Text(
                                      _config.subtitle,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    if (hasAction) const SizedBox(height: 12),
                                  ],
                                  if (hasAction)
                                    FilledButton.icon(
                                      onPressed: _handleShowcaseAction,
                                      icon: const Icon(
                                          Icons.assignment_turned_in_outlined),
                                      label: Text(
                                        _config.ctaLabel.isEmpty
                                            ? 'Register / Fill Form'
                                            : _config.ctaLabel,
                                      ),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 46),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      children: [
                        if (_config.subtitle.trim().isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            child: Text(
                              _config.subtitle,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: ratio != null
                                ? const EdgeInsets.all(12)
                                : EdgeInsets.zero,
                            child: _buildMediaWithAspectRatio(
                              kIsWeb
                                  ? buildVideoEmbed(
                                      videoId:
                                          'billboard-${url.hashCode}-${ratio?.toString() ?? 'auto'}',
                                      embedUrl: url,
                                    )
                                  : (_webViewController != null
                                      ? WebViewWidget(
                                          controller: _webViewController!)
                                      : const Center(
                                          child: CircularProgressIndicator())),
                              ratio,
                            ),
                          ),
                        ),
                        if (hasAction ||
                            (_config.contentType == '3d_html' &&
                                _config.showDonateButton))
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  if (_config.contentType == '3d_html' &&
                                      _config.showDonateButton)
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () =>
                                            context.push('/donation'),
                                        icon: const Icon(
                                            Icons.volunteer_activism_outlined),
                                        label: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Donate to Project',
                                              maxLines: 1, softWrap: false),
                                        ),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 46),
                                        ),
                                      ),
                                    ),
                                  if (_config.contentType == '3d_html' &&
                                      _config.showDonateButton &&
                                      hasAction)
                                    const SizedBox(width: 10),
                                  if (hasAction)
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: _handleShowcaseAction,
                                        icon: Icon(_config.attachInbuiltForm
                                            ? Icons.assignment_turned_in_outlined
                                            : Icons.open_in_new_rounded),
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            _config.ctaLabel.isEmpty
                                                ? 'Register / Fill Form'
                                                : _config.ctaLabel,
                                            maxLines: 1,
                                            softWrap: false,
                                          ),
                                        ),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 46),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}
