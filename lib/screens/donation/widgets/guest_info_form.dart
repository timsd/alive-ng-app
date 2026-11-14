import 'package:flutter/material.dart';
import '../../../utils/responsive_utils.dart';

class GuestInfoForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final VoidCallback? onChanged;

  const GuestInfoForm({
    super.key,
    required this.nameController,
    required this.emailController,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Details',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged?.call(),
          decoration: InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
            filled: true,
            fillColor: theme.cardColor,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => onChanged?.call(),
          decoration: InputDecoration(
            labelText: 'Email Address',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
            filled: true,
            fillColor: theme.cardColor,
          ),
        ),
      ],
    );
  }
}
