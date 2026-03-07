import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/layout_fix_utils.dart';

enum InputVariant {
  outlined,
  filled,
  underlined,
}

class CustomInput extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final FormFieldValidator<String>? validator;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? prefix;
  final IconData? suffixIcon;
  final Widget? suffix;
  final VoidCallback? onSuffixIconPressed;
  final InputVariant variant;
  final EdgeInsetsGeometry? contentPadding;
  final BorderRadius? borderRadius;
  final Color? fillColor;
  final Color? borderColor;
  final double? borderWidth;
  final TextStyle? textStyle;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final bool autofocus;
  final FocusNode? focusNode;

  const CustomInput({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.onEditingComplete,
    this.validator,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.onSuffixIconPressed,
    this.variant = InputVariant.outlined,
    this.contentPadding,
    this.borderRadius,
    this.fillColor,
    this.borderColor,
    this.borderWidth,
    this.textStyle,
    this.labelStyle,
    this.hintStyle,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<CustomInput> {
  late bool _obscureText;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine border style based on variant
    InputBorder border;
    InputBorder focusedBorder;
    InputBorder errorBorder;
    Color? fillColorResolved;

    switch (widget.variant) {
      case InputVariant.outlined:
        border = OutlineInputBorder(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          borderSide: BorderSide(
            color: widget.borderColor ?? colorScheme.outline,
            width: widget.borderWidth ?? 1,
          ),
        );
        focusedBorder = OutlineInputBorder(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        );
        errorBorder = OutlineInputBorder(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2,
          ),
        );
        break;
      case InputVariant.filled:
        fillColorResolved =
            widget.fillColor ?? colorScheme.surfaceContainerHighest;
        border = OutlineInputBorder(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          borderSide: BorderSide.none,
        );
        focusedBorder = OutlineInputBorder(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        );
        errorBorder = OutlineInputBorder(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2,
          ),
        );
        break;
      case InputVariant.underlined:
        border = UnderlineInputBorder(
          borderSide: BorderSide(
            color: widget.borderColor ?? colorScheme.outline,
            width: widget.borderWidth ?? 1,
          ),
        );
        focusedBorder = UnderlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        );
        errorBorder = UnderlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2,
          ),
        );
        break;
    }

    Widget? suffixIconWidget;
    if (widget.obscureText) {
      suffixIconWidget = IconButton(
        icon: LayoutFixUtils.responsiveIcon(
          _obscureText ? Icons.visibility : Icons.visibility_off,
          context: context,
          color: colorScheme.onSurfaceVariant,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    } else if (widget.suffixIcon != null) {
      suffixIconWidget = IconButton(
        icon: LayoutFixUtils.responsiveIcon(
          widget.suffixIcon,
          context: context,
          color: colorScheme.onSurfaceVariant,
        ),
        onPressed: widget.onSuffixIconPressed,
      );
    } else if (widget.suffix != null) {
      suffixIconWidget = widget.suffix;
    }

    Widget? prefixIconWidget;
    if (widget.prefixIcon != null) {
      prefixIconWidget = LayoutFixUtils.responsiveIcon(
        widget.prefixIcon,
        context: context,
        color: _isFocused ? colorScheme.primary : colorScheme.onSurfaceVariant,
      );
    } else if (widget.prefix != null) {
      prefixIconWidget = widget.prefix;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          initialValue: widget.initialValue,
          focusNode: _focusNode,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          onFieldSubmitted: widget.onSubmitted,
          onEditingComplete: widget.onEditingComplete,
          validator: widget.validator,
          obscureText: _obscureText,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          inputFormatters: widget.inputFormatters,
          autofocus: widget.autofocus,
          style: widget.textStyle ?? theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: widget.labelStyle,
            hintText: widget.hint,
            hintStyle: widget.hintStyle,
            helperText: widget.helperText,
            errorText: widget.errorText,
            prefixIcon: prefixIconWidget,
            suffixIcon: suffixIconWidget,
            filled: widget.variant == InputVariant.filled,
            fillColor: fillColorResolved,
            border: border,
            enabledBorder: border,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: errorBorder,
            contentPadding: widget.contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            counterText: widget.maxLength != null ? null : '',
          ),
        ),
      ],
    );
  }
}

class SearchInput extends StatelessWidget {
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final FocusNode? focusNode;

  const SearchInput({
    super.key,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return CustomInput(
      hint: hint ?? 'Search...',
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      prefixIcon: Icons.search,
      suffixIcon: controller?.text.isNotEmpty == true ? Icons.clear : null,
      onSuffixIconPressed: onClear ?? () => controller?.clear(),
      variant: InputVariant.filled,
      textInputAction: TextInputAction.search,
      autofocus: autofocus,
      focusNode: focusNode,
    );
  }
}

class PasswordInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final FocusNode? focusNode;
  final InputVariant variant;

  const PasswordInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autofocus = false,
    this.focusNode,
    this.variant = InputVariant.outlined,
  });

  @override
  Widget build(BuildContext context) {
    return CustomInput(
      label: label ?? 'Password',
      hint: hint,
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      validator: validator,
      obscureText: true,
      prefixIcon: Icons.lock_outline,
      textInputAction: TextInputAction.done,
      autofocus: autofocus,
      focusNode: focusNode,
      variant: variant,
    );
  }
}

class EmailInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final FocusNode? focusNode;
  final InputVariant variant;

  const EmailInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autofocus = false,
    this.focusNode,
    this.variant = InputVariant.outlined,
  });

  @override
  Widget build(BuildContext context) {
    return CustomInput(
      label: label ?? 'Email',
      hint: hint,
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      validator: validator ?? _defaultEmailValidator,
      keyboardType: TextInputType.emailAddress,
      prefixIcon: Icons.email_outlined,
      textInputAction: TextInputAction.next,
      autofocus: autofocus,
      focusNode: focusNode,
      variant: variant,
    );
  }

  String? _defaultEmailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }
}

class PhoneInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final FocusNode? focusNode;
  final InputVariant variant;

  const PhoneInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autofocus = false,
    this.focusNode,
    this.variant = InputVariant.outlined,
  });

  @override
  Widget build(BuildContext context) {
    return CustomInput(
      label: label ?? 'Phone Number',
      hint: hint,
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      validator: validator,
      keyboardType: TextInputType.phone,
      prefixIcon: Icons.phone_outlined,
      textInputAction: TextInputAction.next,
      autofocus: autofocus,
      focusNode: focusNode,
      variant: variant,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
    );
  }
}

class TextAreaInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final bool autofocus;
  final FocusNode? focusNode;
  final InputVariant variant;

  const TextAreaInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.validator,
    this.minLines = 3,
    this.maxLines = 6,
    this.maxLength,
    this.autofocus = false,
    this.focusNode,
    this.variant = InputVariant.outlined,
  });

  @override
  Widget build(BuildContext context) {
    return CustomInput(
      label: label,
      hint: hint,
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      autofocus: autofocus,
      focusNode: focusNode,
      variant: variant,
    );
  }
}

class NumberInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool allowDecimals;
  final bool allowNegative;
  final int? maxLength;
  final bool autofocus;
  final FocusNode? focusNode;
  final InputVariant variant;

  const NumberInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.validator,
    this.allowDecimals = false,
    this.allowNegative = false,
    this.maxLength,
    this.autofocus = false,
    this.focusNode,
    this.variant = InputVariant.outlined,
  });

  @override
  Widget build(BuildContext context) {
    List<TextInputFormatter> formatters = [];

    if (allowDecimals) {
      formatters.add(FilteringTextInputFormatter.allow(
        RegExp(allowNegative ? r'^-?\d*\.?\d*' : r'^\d*\.?\d*'),
      ));
    } else {
      formatters.add(FilteringTextInputFormatter.allow(
        RegExp(allowNegative ? r'^-?\d*' : r'^\d*'),
      ));
    }

    if (maxLength != null) {
      formatters.add(LengthLimitingTextInputFormatter(maxLength!));
    }

    return CustomInput(
      label: label,
      hint: hint,
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      keyboardType: TextInputType.numberWithOptions(
        decimal: allowDecimals,
        signed: allowNegative,
      ),
      inputFormatters: formatters,
      autofocus: autofocus,
      focusNode: focusNode,
      variant: variant,
    );
  }
}




