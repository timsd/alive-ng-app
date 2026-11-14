import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/donation_models.dart';
import '../../services/donation_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_image.dart';

class DonationDialog extends StatefulWidget {
  final DownloadableMaterial material;
  final DonationType donationType;

  const DonationDialog({
    super.key,
    required this.material,
    required this.donationType,
  });

  @override
  State<DonationDialog> createState() => _DonationDialogState();
}

class _DonationDialogState extends State<DonationDialog> {
  final DonationService _donationService = DonationService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isProcessing = false;
  double _donationAmount = 0.0;
  String _selectedCurrency = 'NGN'; // NGN (Naira) or USD (Dollar)
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default to NGN with minimum donation
    _donationAmount = _minimumForCurrentCurrency;
    _amountController.text = _donationAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _minimumForCurrentCurrency {
    final serviceMin = _donationService.getMinimumDonationAmount(
      widget.donationType,
      currency: _selectedCurrency,
    );
    if (_selectedCurrency == 'NGN' &&
        widget.material.minimumDonation > serviceMin) {
      return widget.material.minimumDonation;
    }
    return serviceMin;
  }

  List<double> get _quickPresets {
    if (_selectedCurrency == 'NGN') {
      return [7500.0, 10000.0, 25000.0, 50000.0];
    } else {
      return [12.0, 25.0, 50.0, 100.0];
    }
  }

  void _switchCurrency(String currency) {
    if (_selectedCurrency == currency) return;
    setState(() {
      _errorMessage = null;
      _selectedCurrency = currency;
      _donationAmount = _minimumForCurrentCurrency;
      _amountController.text = _donationAmount.toStringAsFixed(2);
    });
  }

  void _updateAmount(String value) {
    final amount = double.tryParse(value) ?? 0.0;
    setState(() {
      _errorMessage = null;
      _donationAmount = amount;
    });
  }

  bool get _isValidAmount {
    return _donationAmount >= _minimumForCurrentCurrency;
  }

  String get _minimumAmountText {
    final symbol = _selectedCurrency == 'NGN' ? '₦' : '\$';
    return 'Minimum donation: $symbol${_minimumForCurrentCurrency.toStringAsFixed(2)}';
  }

  Future<void> _processDonation() async {
    if (!_formKey.currentState!.validate() || !_isValidAmount) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final symbol = _selectedCurrency == 'NGN' ? '₦' : '\$';
      // Create donation record categorized in finance area
      final donation = await _donationService.createDonation(
        type: widget.donationType,
        amount: _donationAmount,
        currency: _selectedCurrency,
        paymentMethod: PaymentMethod.paystack,
        materialId: widget.material.id,
        materialTitle: widget.material.title,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        metadata: {
          'category': 'tract_production',
          'purpose': 'Tract Production: ${widget.material.title}',
          'fund_designation': 'Tract Production: ${widget.material.title}',
          'donation_type': 'tractProduction',
          'material_id': widget.material.id,
          'material_title': widget.material.title,
          'currency': _selectedCurrency,
        },
      );

      if (!mounted) return;
      final paymentResult = await _donationService.processPaystackPayment(
        context: context,
        donationId: donation.id,
        amount: _donationAmount,
        currency: _selectedCurrency,
        email: donation.userEmail,
      );

      if (paymentResult['cancelled'] == true) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      if (paymentResult['success'] != true &&
          paymentResult['initialized'] != true) {
        throw Exception(paymentResult['message'] ?? 'Payment failed');
      }

      // Record download immediately upon payment confirmation/initialization
      await _donationService.recordDownload(
        widget.material.id,
        widget.material.title,
        donation.id,
        _donationAmount,
      );

      if (mounted) {
        Navigator.of(context).pop(true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paymentResult['initialized'] == true
                  ? 'Payment opened for $symbol${_donationAmount.toStringAsFixed(2)}. ${widget.material.title} is now available in your Downloaded area.'
                  : 'Thank you for your generous gift of $symbol${_donationAmount.toStringAsFixed(2)}! ${widget.material.title} is now in your Downloaded area.',
            ),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      final cleanMsg = ErrorHandler.getUserFriendlyMessage(
        e,
        'Payment could not be completed. Please check your internet connection and try again.',
      );
      setState(() {
        _isProcessing = false;
        _errorMessage = cleanMsg;
      });
    }
  }

  Widget _buildMaterialCover(String? coverUrl) {
    final effectiveCover = (coverUrl != null && coverUrl.trim().isNotEmpty)
        ? coverUrl.trim()
        : (widget.material.id.contains('lesson_1') ||
                widget.material.title
                    .toLowerCase()
                    .contains('something we can trust')
            ? 'assets/images/series/what_the_bible_says_lesson_1.jpg'
            : '');

    if (effectiveCover.isNotEmpty) {
      if (effectiveCover.startsWith('assets/')) {
        return Image.asset(
          effectiveCover,
          width: 72,
          height: 96,
          fit: BoxFit.cover,
        );
      }
      return CustomImage(
        imageUrl: effectiveCover,
        width: 72,
        height: 96,
        fit: BoxFit.cover,
      );
    }

    return Container(
      width: 72,
      height: 96,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.article_rounded,
          color: AppTheme.primaryColor,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildCurrencyOption(String code, String label) {
    final isSelected = _selectedCurrency == code;
    return InkWell(
      onTap: () => _switchCurrency(code),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbol = _selectedCurrency == 'NGN' ? '₦' : '\$';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 440.0,
            tablet: 520.0,
            desktop: 580.0,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header (Green Circle in user request)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.volunteer_activism,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support Tract Production',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Help us to create and distribute more tracts',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.65),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded, size: 22),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Material Info Card (Red Circle: Cover image on left, text on right)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover image on the side
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            _buildMaterialCover(widget.material.thumbnailUrl),
                      ),
                      const SizedBox(width: 12),
                      // Text on the other side
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.material.category.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.material.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    height: 1.25,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.material.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.material.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 11,
                                      height: 1.35,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Currency Selector & Label
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Amount ($_selectedCurrency)',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Currency Toggle: [ ₦ Naira ] [ $ USD ]
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCurrencyOption('NGN', '₦ Naira'),
                          _buildCurrencyOption('USD', '\$ USD'),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Amount Text Field
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    prefixText: '$symbol ',
                    prefixStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    hintText: 'Enter amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: !_isValidAmount && _donationAmount > 0
                        ? 'Amount below minimum required'
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter donation amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid amount';
                    }
                    if (amount < _minimumForCurrentCurrency) {
                      return _minimumAmountText;
                    }
                    return null;
                  },
                  onChanged: _updateAmount,
                ),

                const SizedBox(height: 6),
                Text(
                  _minimumAmountText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),

                const SizedBox(height: 10),

                // Quick Preset Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickPresets.map((preset) {
                      final isSelected =
                          (_donationAmount - preset).abs() < 0.01;
                      final label = '$symbol${preset.toInt()}';
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _errorMessage = null;
                                _donationAmount = preset;
                                _amountController.text =
                                    preset.toStringAsFixed(2);
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Paystack Secured Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Secured by Paystack',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Optional Message Input
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Message (Optional)',
                    hintText: 'Add a message with your donation...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _errorMessage = null),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 20),

                // 5. Action Buttons (Cancel and prominent Pay button)
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isProcessing || !_isValidAmount
                            ? null
                            : _processDonation,
                        icon: _isProcessing
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.payment_rounded, size: 18),
                        label: Text(
                          _isProcessing
                              ? 'Processing...'
                              : 'Pay $symbol${_donationAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
