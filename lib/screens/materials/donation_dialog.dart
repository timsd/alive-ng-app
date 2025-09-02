import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/donation_models.dart';
import '../../services/donation_service.dart';
import '../../utils/app_constants.dart';

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
  
  PaymentMethod _selectedPaymentMethod = PaymentMethod.stripe;
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
    return _donationService.validateDonationAmount(widget.donationType, _donationAmount);
  }

  String get _minimumAmountText {
    final minimum = _donationService.getMinimumDonationAmount(widget.donationType);
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
      
      if (_selectedPaymentMethod == PaymentMethod.stripe) {
        paymentResult = await _donationService.processStripePayment(
          donationId: donation.id,
          amount: _donationAmount,
          currency: 'USD',
        );
        
        // In a real app, you would integrate with Stripe SDK here
        await _showPaymentInstructions(
          'Stripe Payment',
          'Please complete your payment using the Stripe checkout.',
          paymentResult['authorization_url'] ?? '',
        );
      } else {
        // Paystack for Nigerian users
        paymentResult = await _donationService.processPaystackPayment(
          donationId: donation.id,
          amount: _donationAmount,
          currency: 'NGN',
          email: donation.userEmail,
        );
        
        await _showPaymentInstructions(
          'Paystack Payment',
          'Please complete your payment using Paystack.',
          paymentResult['authorization_url'] ?? '',
        );
      }

      // For demo purposes, we'll simulate successful payment
      await Future.delayed(const Duration(seconds: 2));
      
      // Update donation status to completed (in real app, this would be done via webhook)
      await _donationService.updateDonationStatus(
        donation.id,
        DonationStatus.completed,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate successful donation
        
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

  Future<void> _showPaymentInstructions(
    String title,
    String message,
    String? url,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (url != null && url.isNotEmpty) ..[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url));
                  }
                },
                child: const Text('Open Payment Page'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
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
                    color: AppConstants.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Support Our Ministry',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Help us spread the gospel forward',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
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
              
              const SizedBox(height: 24),
              
              // Material Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Material: ${widget.material.title}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.material.category,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    if (widget.material.description.isNotEmpty) ..[
                      const SizedBox(height: 8),
                      Text(
                        widget.material.description,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Donation Amount
              Text(
                'Donation Amount (USD)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  hintText: 'Enter amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
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
                  if (!_donationService.validateDonationAmount(widget.donationType, amount)) {
                    return _minimumAmountText;
                  }
                  return null;
                },
                onChanged: _updateAmount,
              ),
              const SizedBox(height: 4),
              Text(
                _minimumAmountText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Payment Method
              Text(
                'Payment Method',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: PaymentMethod.values.map((method) {
                  return RadioListTile<PaymentMethod>(
                    title: Text(_getPaymentMethodName(method)),
                    subtitle: Text(_getPaymentMethodDescription(method)),
                    value: method,
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPaymentMethod = value);
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              
              // Optional Notes
              Text(
                'Message (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add a message with your donation...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Ministry Support Message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      color: AppConstants.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your donation helps us continue spreading the gospel and supporting our ministry efforts.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
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
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isProcessing || !_isValidAmount 
                          ? null 
                          : _processDonation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
      case PaymentMethod.stripe:
        return 'Credit/Debit Card (Stripe)';
      case PaymentMethod.paystack:
        return 'Paystack (Nigeria)';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.mobileMoney:
        return 'Mobile Money';
    }
  }

  String _getPaymentMethodDescription(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.stripe:
        return 'Secure payment with Visa, Mastercard, etc.';
      case PaymentMethod.paystack:
        return 'Pay with Nigerian banks and cards';
      case PaymentMethod.bankTransfer:
        return 'Direct bank transfer';
      case PaymentMethod.mobileMoney:
        return 'Mobile money services';
    }
  }
}
