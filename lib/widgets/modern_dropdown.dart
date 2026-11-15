import 'package:flutter/material.dart';

class _ModernDropdownSelection<T> {
  final T? value;
  const _ModernDropdownSelection(this.value);
}

/// Extracts plain text from a widget tree for search filtering and header fallback.
String extractModernDropdownText(Widget? widget) {
  if (widget == null) return '';
  if (widget is Text) {
    return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }
  if (widget is RichText) {
    return widget.text.toPlainText();
  }
  if (widget is SingleChildRenderObjectWidget) {
    return extractModernDropdownText(widget.child);
  }
  if (widget is ProxyWidget) {
    return extractModernDropdownText(widget.child);
  }
  if (widget is MultiChildRenderObjectWidget) {
    return widget.children
        .map(extractModernDropdownText)
        .where((s) => s.trim().isNotEmpty)
        .join(' ');
  }
  if (widget is ListTile) {
    final t = extractModernDropdownText(widget.title);
    final s = extractModernDropdownText(widget.subtitle);
    return [t, s].where((e) => e.trim().isNotEmpty).join(' - ');
  }
  return '';
}

/// Shows the unified Modernized Dropdown modal sheet used across the entire app.
Future<void> showModernDropdownSheet<T>({
  required BuildContext context,
  required List<DropdownMenuItem<T>> items,
  required T? selectedValue,
  required ValueChanged<T?> onChanged,
  String? title,
  IconData? headerIcon,
}) async {
  if (items.isEmpty) return;

  final selection = await showModalBottomSheet<_ModernDropdownSelection<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _ModernDropdownSheetContent<T>(
        items: items,
        selectedValue: selectedValue,
        title: (title != null && title.trim().isNotEmpty)
            ? title.trim().replaceAll(RegExp(r'\s*\*$'), '')
            : 'Select Option',
        headerIcon: headerIcon,
      );
    },
  );

  if (selection != null) {
    onChanged(selection.value);
  }
}

class _ModernDropdownSheetContent<T> extends StatefulWidget {
  final List<DropdownMenuItem<T>> items;
  final T? selectedValue;
  final String title;
  final IconData? headerIcon;

  const _ModernDropdownSheetContent({
    required this.items,
    required this.selectedValue,
    required this.title,
    this.headerIcon,
  });

  @override
  State<_ModernDropdownSheetContent<T>> createState() =>
      _ModernDropdownSheetContentState<T>();
}

class _ModernDropdownSheetContentState<T>
    extends State<_ModernDropdownSheetContent<T>> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final showSearch = widget.items.length > 6;

    final filteredItems = _searchQuery.isEmpty
        ? widget.items
        : widget.items.where((item) {
            final label = extractModernDropdownText(item.child).toLowerCase();
            final valStr = (item.value?.toString() ?? '').toLowerCase();
            return label.contains(_searchQuery) || valStr.contains(_searchQuery);
          }).toList();

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: mediaQuery.size.height * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.headerIcon ?? Icons.tune_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${widget.items.length} ${widget.items.length == 1 ? 'option' : 'options'} available',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              if (showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search ${widget.title.toLowerCase()}...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Flexible(
                child: filteredItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No matching options found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final isSelected = item.value == widget.selectedValue;
                          final isEnabled = item.enabled;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: isEnabled
                                  ? () {
                                      item.onTap?.call();
                                      Navigator.of(context).pop(
                                        _ModernDropdownSelection<T>(item.value),
                                      );
                                    }
                                  : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                          .withValues(alpha: 0.12)
                                      : theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.55),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: DefaultTextStyle.merge(
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: !isEnabled
                                              ? theme.disabledColor
                                              : isSelected
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurface,
                                        ),
                                        child: item.child,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      size: 20,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.45),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unified, drop-in replacement for [DropdownButtonFormField] that renders a
/// sleek modernized field and opens [showModernDropdownSheet] on tap.
class ModernDropdownFormField<T> extends FormField<T> {
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration? decoration;
  final Widget? hint;
  final Widget? disabledHint;
  final bool isExpanded;
  final bool isDense;
  final Widget? icon;
  final double iconSize;
  final Color? iconEnabledColor;
  final Color? iconDisabledColor;
  final TextStyle? style;
  final Color? dropdownColor;
  final BorderRadius? borderRadius;
  final double? menuMaxHeight;
  final DropdownButtonBuilder? selectedItemBuilder;
  final AlignmentGeometry alignment;
  final int elevation;
  final EdgeInsetsGeometry? padding;
  final String? sheetTitle;

  ModernDropdownFormField({
    super.key,
    required this.items,
    T? value,
    T? initialValue,
    this.onChanged,
    this.decoration,
    this.hint,
    this.disabledHint,
    this.isExpanded = false,
    this.isDense = true,
    this.icon,
    this.iconSize = 24.0,
    this.iconEnabledColor,
    this.iconDisabledColor,
    this.style,
    this.dropdownColor,
    this.borderRadius,
    this.menuMaxHeight,
    this.selectedItemBuilder,
    this.alignment = AlignmentDirectional.centerStart,
    this.elevation = 8,
    this.padding,
    this.sheetTitle,
    super.onSaved,
    super.validator,
    super.autovalidateMode,
    super.enabled = true,
  }) : _controlledValue = value ?? initialValue,
       super(
         initialValue: value ?? initialValue,
         builder: (FormFieldState<T> field) {
           final state = field as _ModernDropdownFormFieldState<T>;
           return state._buildField(field.context);
         },
       );

  final T? _controlledValue;

  @override
  FormFieldState<T> createState() => _ModernDropdownFormFieldState<T>();
}

class _ModernDropdownFormFieldState<T> extends FormFieldState<T> {
  @override
  ModernDropdownFormField<T> get widget =>
      super.widget as ModernDropdownFormField<T>;

  @override
  void didUpdateWidget(ModernDropdownFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._controlledValue != oldWidget._controlledValue &&
        widget._controlledValue != value) {
      setValue(widget._controlledValue);
    }
  }

  Widget _buildField(BuildContext context) {
    final theme = Theme.of(context);
    final itemList = widget.items ?? const [];
    final isEnabled = widget.enabled && widget.onChanged != null && itemList.isNotEmpty;

    DropdownMenuItem<T>? selectedItem;
    int selectedIndex = -1;
    for (int i = 0; i < itemList.length; i++) {
      if (itemList[i].value == value) {
        selectedItem = itemList[i];
        selectedIndex = i;
        break;
      }
    }

    Widget displayChild;
    if (selectedItem != null) {
      if (widget.selectedItemBuilder != null) {
        final built = widget.selectedItemBuilder!(context);
        if (selectedIndex >= 0 && selectedIndex < built.length) {
          displayChild = built[selectedIndex];
        } else {
          displayChild = selectedItem.child;
        }
      } else {
        displayChild = selectedItem.child;
      }
    } else {
      final hasLabel = widget.decoration?.labelText != null ||
          widget.decoration?.label != null;
      displayChild = isEnabled
          ? (widget.hint ??
              (hasLabel && widget.decoration?.hintText == null
                  ? const SizedBox.shrink()
                  : Text(
                      widget.decoration?.hintText ?? 'Select option',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    )))
          : (widget.disabledHint ?? widget.hint ?? const SizedBox.shrink());
    }

    final baseDecoration = (widget.decoration ?? const InputDecoration())
        .applyDefaults(theme.inputDecorationTheme);

    final effectiveDecoration = baseDecoration.copyWith(
      errorText: errorText,
      enabled: isEnabled,
      filled: true,
      fillColor: baseDecoration.fillColor ??
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      contentPadding: baseDecoration.contentPadding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: baseDecoration.border ??
          OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
      enabledBorder: baseDecoration.enabledBorder ??
          OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
      focusedBorder: baseDecoration.focusedBorder ??
          OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
      suffixIcon: baseDecoration.suffixIcon ??
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isEnabled
                    ? (widget.iconEnabledColor ?? theme.colorScheme.primary)
                    : (widget.iconDisabledColor ?? theme.disabledColor),
              ),
            ),
          ),
      suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );

    final resolvedTitle = widget.sheetTitle ??
        baseDecoration.labelText ??
        baseDecoration.hintText ??
        extractModernDropdownText(widget.hint);

    Widget fieldWidget = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isEnabled
          ? () {
              FocusScope.of(context).unfocus();
              showModernDropdownSheet<T>(
                context: context,
                items: itemList,
                selectedValue: value,
                title: resolvedTitle,
                onChanged: (newValue) {
                  didChange(newValue);
                  widget.onChanged?.call(newValue);
                },
              );
            }
          : null,
      child: InputDecorator(
        decoration: effectiveDecoration,
        isEmpty: selectedItem == null && widget.hint == null,
        isFocused: false,
        child: Align(
          alignment: widget.alignment,
          widthFactor: widget.isExpanded ? null : 1.0,
          child: DefaultTextStyle.merge(
            style: widget.style ??
                theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isEnabled
                      ? theme.colorScheme.onSurface
                      : theme.disabledColor,
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            child: displayChild,
          ),
        ),
      ),
    );

    if (widget.padding != null) {
      fieldWidget = Padding(padding: widget.padding!, child: fieldWidget);
    }

    return fieldWidget;
  }
}

/// Unified, drop-in replacement for [DropdownButton] that renders a
/// sleek modernized selector and opens [showModernDropdownSheet] on tap.
class ModernDropdownButton<T> extends StatelessWidget {
  final List<DropdownMenuItem<T>>? items;
  final T? value;
  final Widget? hint;
  final Widget? disabledHint;
  final ValueChanged<T?>? onChanged;
  final VoidCallback? onTap;
  final DropdownButtonBuilder? selectedItemBuilder;
  final int elevation;
  final TextStyle? style;
  final Widget? underline;
  final Widget? icon;
  final Color? iconDisabledColor;
  final Color? iconEnabledColor;
  final double iconSize;
  final bool isDense;
  final bool isExpanded;
  final double? itemHeight;
  final Color? focusColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? dropdownColor;
  final double? menuMaxHeight;
  final bool? enableFeedback;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final String? sheetTitle;

  const ModernDropdownButton({
    super.key,
    required this.items,
    this.value,
    this.hint,
    this.disabledHint,
    required this.onChanged,
    this.onTap,
    this.selectedItemBuilder,
    this.elevation = 8,
    this.style,
    this.underline,
    this.icon,
    this.iconDisabledColor,
    this.iconEnabledColor,
    this.iconSize = 24.0,
    this.isDense = false,
    this.isExpanded = false,
    this.itemHeight = kMinInteractiveDimension,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.dropdownColor,
    this.menuMaxHeight,
    this.enableFeedback,
    this.alignment = AlignmentDirectional.centerStart,
    this.borderRadius,
    this.padding,
    this.sheetTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemList = items ?? const [];
    final isEnabled = onChanged != null && itemList.isNotEmpty;

    DropdownMenuItem<T>? selectedItem;
    int selectedIndex = -1;
    for (int i = 0; i < itemList.length; i++) {
      if (itemList[i].value == value) {
        selectedItem = itemList[i];
        selectedIndex = i;
        break;
      }
    }

    Widget displayChild;
    if (selectedItem != null) {
      if (selectedItemBuilder != null) {
        final built = selectedItemBuilder!(context);
        if (selectedIndex >= 0 && selectedIndex < built.length) {
          displayChild = built[selectedIndex];
        } else {
          displayChild = selectedItem.child;
        }
      } else {
        displayChild = selectedItem.child;
      }
    } else {
      displayChild = isEnabled
          ? (hint ??
              Text(
                'Select',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ))
          : (disabledHint ?? hint ?? const SizedBox.shrink());
    }

    final hasNoUnderline = DropdownButtonHideUnderline.at(context);
    final resolvedTitle = sheetTitle ?? extractModernDropdownText(hint);

    Widget content = Row(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (isExpanded)
          Expanded(
            child: Align(
              alignment: alignment,
              child: DefaultTextStyle.merge(
                style: style ??
                    theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isEnabled
                          ? theme.colorScheme.onSurface
                          : theme.disabledColor,
                    ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                child: displayChild,
              ),
            ),
          )
        else
          Flexible(
            child: Align(
              alignment: alignment,
              widthFactor: 1.0,
              child: DefaultTextStyle.merge(
                style: style ??
                    theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isEnabled
                          ? theme.colorScheme.onSurface
                          : theme.disabledColor,
                    ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                child: displayChild,
              ),
            ),
          ),
        const SizedBox(width: 6),
        icon ??
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: isDense ? 18 : 20,
              color: isEnabled
                  ? (iconEnabledColor ?? theme.colorScheme.primary)
                  : (iconDisabledColor ?? theme.disabledColor),
            ),
      ],
    );

    if (!hasNoUnderline) {
      content = Container(
        padding: padding ??
            EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isDense ? 6 : 8,
            ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: content,
      );
    } else if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return InkWell(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      onTap: isEnabled
          ? () {
              onTap?.call();
              FocusScope.of(context).unfocus();
              showModernDropdownSheet<T>(
                context: context,
                items: itemList,
                selectedValue: value,
                title: resolvedTitle,
                onChanged: (newValue) => onChanged?.call(newValue),
              );
            }
          : null,
      child: content,
    );
  }
}
