import 'package:flutter/material.dart';
import '../../../models/donation_presentation_models.dart';
import '../../../utils/responsive_utils.dart';
import '../../../widgets/modern_dropdown.dart';

class DonationAmountSelector extends StatelessWidget {
  final String title;
  final String selectedCurrency;
  final double selectedAmount;
  final List<DonationAmountOption> presetAmounts;
  final TextEditingController customAmountController;
  final int selectedDesignationCount;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<double> onPresetAmountSelected;
  final ValueChanged<String> onCustomAmountChanged;

  const DonationAmountSelector({
    super.key,
    required this.title,
    required this.selectedCurrency,
    required this.selectedAmount,
    required this.presetAmounts,
    required this.customAmountController,
    required this.selectedDesignationCount,
    required this.onCurrencyChanged,
    required this.onPresetAmountSelected,
    required this.onCustomAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildCurrencySelector(context, theme),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        _buildPresetAmounts(context, theme),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        _buildCustomAmountInput(context, theme),
        if (selectedAmount > 0 && selectedDesignationCount > 1) ...[
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.call_split_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Split: ${selectedCurrency == 'USD' ? '\$' : '₦'}${(selectedAmount / selectedDesignationCount).toStringAsFixed(2)} each across $selectedDesignationCount designated areas (${(100.0 / selectedDesignationCount).toStringAsFixed(0)}% each)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCurrencySelector(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: ModernDropdownButton<String>(
        value: selectedCurrency,
        sheetTitle: 'Currency',
        underline: const SizedBox(),
        items: ['USD', 'NGN'].map((currency) {
          return DropdownMenuItem(
            value: currency,
            child: Text(
              currency,
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 14,
                  tablet: 16,
                  desktop: 18,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            onCurrencyChanged(value);
          }
        },
      ),
    );
  }

  Widget _buildPresetAmounts(BuildContext context, ThemeData theme) {
    return Wrap(
      spacing: ResponsiveUtils.getResponsiveSpacing(context, 12),
      runSpacing: ResponsiveUtils.getResponsiveSpacing(context, 12),
      children: presetAmounts.map((amountData) {
        final amount = amountData.amount;
        final label = amountData.label;
        final isSelected = selectedAmount == amount;

        return GestureDetector(
          onTap: () => onPresetAmountSelected(amount),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 24,
                tablet: 28,
                desktop: 32,
              ),
              vertical: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16,
                tablet: 18,
                desktop: 20,
              ),
            ),
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.dividerColor.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomAmountInput(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Other Amount',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
        TextField(
          controller: customAmountController,
          keyboardType: TextInputType.number,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            prefixText: selectedCurrency == 'USD' ? '\$ ' : '₦ ',
            prefixStyle: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            hintText: 'Enter amount',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
            filled: true,
            fillColor: theme.cardColor,
          ),
          onChanged: onCustomAmountChanged,
        ),
      ],
    );
  }
}
