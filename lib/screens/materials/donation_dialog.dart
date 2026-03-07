import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/donation_models.dart';
import '../../services/donation_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';

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

  PaymentMethod _selectedPaymentMethod = PaymentMethod.paystack;
  bool _isProcessing = false;
  double _donationAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _donationAmount = widget.material.minimumDonation;
    _amountController.text = _donationAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateAmount(String value) {
    final amount = double.tryParse(value) ?? 0.0;
    setState(() {
      _donationAmount = amount;
    });
  }

  bool get _isValidAmount {
    return _donationService.validateDonationAmount(
        widget.donationType, _donationAmount);
  }

  String get _minimumAmountText {
    final minimum =
        _donationService.getMinimumDonationAmount(widget.donationType);
    return 'Minimum donation: \$${minimum.toStringAsFixed(2)}';
  }

  Future<void> _processDonation() async {
    if (!_formKey.currentState!.validate() || !_isValidAmount) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Create donation record
      final donation = await _donationService.createDonation(
        type: widget.donationType,
        amount: _donationAmount,
        paymentMethod: _selectedPaymentMethod,
        materialId: widget.material.id,
        materialTitle: widget.material.title,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      // Process payment based on selected method
      Map<String, dynamic> paymentResult;

      if (_selectedPaymentMethod == PaymentMethod.paystack) {
        // Check if widget is still mounted before using context
        if (!mounted) return;

        // Paystack payment is handled directly by PaystackService
        paymentResult = await _donationService.processPaystackPayment(
          context: context,
          donationId: donation.id,
          amount: _donationAmount,
          currency: 'NGN',
          email: donation.userEmail,
        );

        // Check if payment was successful
        if (paymentResult['success'] == true) {
          // Payment was processed successfully
          // The PaystackService handles the payment flow and database updates
          // No need for additional simulation or manual status updates
        } else {
          throw Exception(paymentResult['message'] ?? 'Payment failed');
        }
      }

      if (mounted) {
        Navigator.of(context)
            .pop(true); // Return true to indicate successful donation

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Thank you for your donation! You can now download ${widget.material.title}.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: context.responsiveBorderRadius,
      ),
      child: Container(
        constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 400.0,
          tablet: 500.0,
          desktop: 600.0,
        )),
        padding: context.responsivePadding,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.volunteer_activism,
                    color: AppTheme.primaryColor,
                    size: context.responsiveIconSize(28),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0,
                  )),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support Our Ministry',
                          style: TextStyle(
                            fontSize: context.responsiveFontSize(20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Help us spread the gospel forward',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: context.responsiveFontSize(14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 24.0,
                tablet: 28.0,
                desktop: 32.0,
              )),

              // Material Info
              Container(
                padding: context.responsivePadding,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: context.responsiveBorderRadius,
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Material: ${widget.material.title}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: context.responsiveFontSize(16),
                      ),
                    ),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 4.0,
                      tablet: 6.0,
                      desktop: 8.0,
                    )),
                    Text(
                      widget.material.category,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: context.responsiveFontSize(14),
                      ),
                    ),
                    if (widget.material.description.isNotEmpty) ...[
                      SizedBox(
                          height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 8.0,
                        tablet: 10.0,
                        desktop: 12.0,
                      )),
                      Text(
                        widget.material.description,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: context.responsiveFontSize(13),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 24.0,
                tablet: 28.0,
                desktop: 32.0,
              )),

              // Donation Amount
              Text(
                'Donation Amount (USD)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              )),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  hintText: 'Enter amount',
                  border: OutlineInputBorder(
                    borderRadius: context.responsiveBorderRadius,
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
                  if (!_donationService.validateDonationAmount(
                      widget.donationType, amount)) {
                    return _minimumAmountText;
                  }
                  return null;
                },
                onChanged: _updateAmount,
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 4.0,
                tablet: 6.0,
                desktop: 8.0,
              )),
              Text(
                _minimumAmountText,
                style: TextStyle(
                  fontSize: context.responsiveFontSize(12),
                  color: Colors.grey[600],
                ),
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 20.0,
                tablet: 24.0,
                desktop: 28.0,
              )),

              // Payment Method
              Text(
                'Payment Method',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              )),
              Column(
                children: [
                  RadioGroup<PaymentMethod>(
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPaymentMethod = value);
                      }
                    },
                    child: Column(
                      children: PaymentMethod.values.map((method) {
                        return RadioListTile<PaymentMethod>(
                          title: Text(_getPaymentMethodName(method)),
                          subtitle: Text(_getPaymentMethodDescription(method)),
                          value: method,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 20.0,
                tablet: 24.0,
                desktop: 28.0,
              )),

              // Optional Notes
              Text(
                'Message (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              )),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add a message with your donation...',
                  border: OutlineInputBorder(
                    borderRadius: context.responsiveBorderRadius,
                  ),
                ),
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 24.0,
                tablet: 28.0,
                desktop: 32.0,
              )),

              // Ministry Support Message
              Container(
                padding: context.responsivePadding,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: context.responsiveBorderRadius,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      color: AppTheme.primaryColor,
                      size: context.responsiveIconSize(20),
                    ),
                    SizedBox(
                        width: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    )),
                    Expanded(
                      child: Text(
                        'Your donation helps us continue spreading the gospel and supporting our ministry efforts.',
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(12),
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 24.0,
                tablet: 28.0,
                desktop: 32.0,
              )),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0,
                  )),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isProcessing || !_isValidAmount
                          ? null
                          : _processDonation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 12.0,
                            tablet: 14.0,
                            desktop: 16.0,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: context.responsiveBorderRadius,
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Donate \$${_donationAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
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
    );
  }

  String _getPaymentMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.paystack:
        return 'Paystack (Nigeria & International)';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.mobileMoney:
        return 'Mobile Money';
      case PaymentMethod.paypal:
        return 'PayPal';
    }
  }

  String _getPaymentMethodDescription(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.paystack:
        return 'Pay with Nigerian banks, cards, and international payments';
      case PaymentMethod.bankTransfer:
        return 'Direct bank transfer';
      case PaymentMethod.mobileMoney:
        return 'Mobile money services';
      case PaymentMethod.paypal:
        return 'Secure payment with PayPal';
    }
  }
}
