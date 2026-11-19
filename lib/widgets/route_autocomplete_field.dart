import 'package:flutter/material.dart';

import '../constants/app_routes_catalog.dart';

/// A search-as-you-type route picker field for admin screens (e.g. Push
/// Notification Custom Route Path and Announcement Action Button URL).
///
/// Renders suggestions inline beneath the input so the list is never obscured
/// by the mobile keyboard inside scrollable forms.
class RouteAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final bool allowExternalUrls;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const RouteAutocompleteField({
    super.key,
    required this.controller,
    this.labelText = 'Custom Route Path',
    this.hintText = 'Type to search routes, e.g. /announcements',
    this.prefixIcon = Icons.alt_route,
    this.allowExternalUrls = false,
    this.validator,
    this.onChanged,
  });

  @override
  State<RouteAutocompleteField> createState() => _RouteAutocompleteFieldState();
}

class _RouteAutocompleteFieldState extends State<RouteAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;
  bool _forceBrowse = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_focusNode.hasFocus) {
      final text = widget.controller.text.trim();
      final shouldOpen = !widget.allowExternalUrls || text.startsWith('/');
      setState(() {
        _showSuggestions = shouldOpen || _forceBrowse;
      });
    } else {
      setState(() {
        if (!_forceBrowse) {
          _showSuggestions = false;
        }
      });
    }
  }

  void _onTextChanged() {
    if (!mounted) return;
    final text = widget.controller.text;
    final trimmed = text.trim();

    if (widget.allowExternalUrls) {
      if (trimmed.startsWith('/')) {
        if (!_showSuggestions && _focusNode.hasFocus) {
          setState(() => _showSuggestions = true);
        } else {
          setState(() {});
        }
      } else {
        setState(() {
          _forceBrowse = false;
          _showSuggestions = false;
        });
      }
    } else {
      setState(() {
        if (_focusNode.hasFocus) {
          _showSuggestions = true;
        }
      });
    }
  }

  void _selectRoute(AppRouteOption option) {
    widget.controller.text = option.path;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: option.path.length),
    );
    widget.onChanged?.call(option.path);
    setState(() {
      _showSuggestions = false;
      _forceBrowse = false;
    });
    _focusNode.unfocus();
  }

  void _toggleBrowse() {
    setState(() {
      _forceBrowse = !_showSuggestions;
      _showSuggestions = !_showSuggestions;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentText = widget.controller.text;
    final trimmed = currentText.trim();
    final isExactValid =
        trimmed.startsWith('/') && AppRoutesCatalog.isValidAppRoute(trimmed);

    final queryForSearch =
        (widget.allowExternalUrls && !trimmed.startsWith('/')) ? '' : trimmed;
    final matches = _showSuggestions
        ? AppRoutesCatalog.search(queryForSearch)
        : const <AppRouteOption>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: (value) {
            widget.onChanged?.call(value);
          },
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(widget.prefixIcon),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trimmed.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Clear',
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged?.call('');
                      setState(() {});
                    },
                  ),
                IconButton(
                  icon: Icon(
                    _showSuggestions
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.list_alt_rounded,
                    size: 20,
                    color: _showSuggestions ? colorScheme.primary : null,
                  ),
                  tooltip: _showSuggestions
                      ? 'Hide available routes'
                      : 'Browse available app routes',
                  onPressed: _toggleBrowse,
                ),
              ],
            ),
            helperText: !widget.allowExternalUrls
                ? (isExactValid
                    ? 'Valid route selected'
                    : 'Start typing or tap the list icon to pick an available route')
                : 'Enter an external URL (https://...) or type / to pick an app route',
            helperStyle: isExactValid
                ? TextStyle(color: colorScheme.tertiary)
                : null,
          ),
          validator: widget.validator,
        ),
        if (_showSuggestions) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.route_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Available Routes (${matches.length})',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _showSuggestions = false;
                            _forceBrowse = false;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No matching route for "$trimmed". Clear or refine your search to avoid a Route Unavailable page.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 230),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 12,
                        endIndent: 12,
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                      itemBuilder: (context, index) {
                        final option = matches[index];
                        final selected = trimmed == option.path;
                        return InkWell(
                          onTap: () => _selectRoute(option),
                          child: Container(
                            color: selected
                                ? colorScheme.primary.withValues(alpha: 0.1)
                                : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              option.label,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              option.category,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                fontSize: 10,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        option.path,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.primary,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
