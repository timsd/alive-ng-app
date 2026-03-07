import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/responsive_utils.dart';
import '../../utils/layout_fix_utils.dart';
import '../../providers/language_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/validation_utils.dart';

class GiftInKindFormScreen extends ConsumerStatefulWidget {
  const GiftInKindFormScreen({super.key});

  @override
  ConsumerState<GiftInKindFormScreen> createState() => _GiftInKindFormScreenState();
}

class _GiftInKindFormScreenState extends ConsumerState<GiftInKindFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();
  final _valueController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedItemType;
  String _deliveryPreference = 'Pickup';

  final List<String> _itemTypes = const [
    'Ministry Bus',
    'Land',
    'Sound System',
    'Foldable Chairs',
    'Tent',
    'Floodlight',
    'Generator',
    'Projector',
    'Public Address System',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _valueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final rootCtx = context;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final itemType = _selectedItemType ?? 'Other';
    final quantity = _quantityController.text.trim();
    final location = _locationController.text.trim();
    final value = _valueController.text.trim();
    final preference = _deliveryPreference;
    final description = _descriptionController.text.trim();

    final subject = Uri.encodeComponent('Specific Item Donation: $itemType');
    final body = Uri.encodeComponent(
      'Name: $name\n'
      'Email: $email\n'
      'Phone: $phone\n'
      'Item Type: $itemType\n'
      'Quantity: $quantity\n'
      'Estimated Value: $value\n'
      'Delivery Preference: $preference\n'
      'Location: $location\n'
      'Description: $description\n'
    );

    final mailto = Uri.parse('mailto:alivenigeria2011@gmail.com?subject=$subject&body=$body');
    if (await canLaunchUrl(mailto)) {
      await launchUrl(mailto);
      if (!rootCtx.mounted) return;
      ScaffoldMessenger.of(rootCtx).showSnackBar(
        const SnackBar(
            content:
                Text('Opening email to send your donation details...')),
      );
      rootCtx.pop();
    } else {
      if (!rootCtx.mounted) return;
      ScaffoldMessenger.of(rootCtx).showSnackBar(
        const SnackBar(
            content: Text(
                'Could not open email app. Please email alivenigeria2011@gmail.com.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final translate = ref.watch(languageProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: translate('gift_in_kind'),
        showBackButton: true,
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: LayoutFixUtils.safeColumn(
          children: [
            Container(
              width: double.infinity,
              padding: ResponsiveUtils.getResponsivePadding(context),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('donate_specific_items'),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20, tablet: 22, desktop: 24),
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                  Text(
                    translate('gik_intro'),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 15, desktop: 16),
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 20)),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(context, controller: _nameController, label: translate('full_name'), keyboardType: TextInputType.name),
                  _buildTextField(context, controller: _emailController, label: translate('email'), keyboardType: TextInputType.emailAddress),
                  _buildTextField(context, controller: _phoneController, label: translate('phone'), keyboardType: TextInputType.phone),
                  _buildDropdownField(context),
                  _buildTextField(context, controller: _quantityController, label: translate('quantity'), keyboardType: TextInputType.number),
                  _buildTextField(context, controller: _valueController, label: translate('estimated_value_optional'), keyboardType: TextInputType.number),
                  _buildDeliveryPreference(context),
                  _buildTextField(context, controller: _locationController, label: translate('location'), keyboardType: TextInputType.text),
                  _buildMultilineField(context),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.email_outlined),
                      label: Text(translate('submit_and_email')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                          horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 18, desktop: 20),
                        ),
                      ),
                      onPressed: _submitForm,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
  }) {
    final theme = Theme.of(context);
    final tr = ref.read(languageProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveSpacing(context, 12)),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (label == tr('estimated_value_optional')) return null;
          if (value == null || value.trim().isEmpty) {
            return 'Please enter $label';
          }
          if (label == tr('email') && !ValidationUtils.isValidEmail(value.trim())) {
            return 'Please enter a valid email';
          }
          if (label == tr('phone') && !ValidationUtils.isValidPhone(value.trim())) {
            return 'Please enter a valid phone number';
          }
          if (label == tr('quantity')) {
            final qty = int.tryParse(value.trim());
            if (qty == null || qty <= 0) {
              return 'Please enter a valid quantity';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildMultilineField(BuildContext context) {
    final theme = Theme.of(context);
    final tr = ref.read(languageProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveSpacing(context, 12)),
      child: TextFormField(
        controller: _descriptionController,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: tr('description_optional'),
          helperText: tr('helper_additional_details'),
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildDropdownField(BuildContext context) {
    final theme = Theme.of(context);
    final tr = ref.read(languageProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveSpacing(context, 12)),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: tr('item_type'),
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedItemType,
            items: _itemTypes
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _selectedItemType = val),
            isExpanded: true,
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryPreference(BuildContext context) {
    final theme = Theme.of(context);
    final tr = ref.read(languageProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveSpacing(context, 12)),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: tr('delivery_preference'),
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            ChoiceChip(
              label: Text(tr('pickup')),
              selected: _deliveryPreference == 'Pickup',
              onSelected: (_) => setState(() => _deliveryPreference = 'Pickup'),
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              label: Text(tr('drop_off')),
              selected: _deliveryPreference == 'Delivery',
              onSelected: (_) => setState(() => _deliveryPreference = 'Delivery'),
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}
