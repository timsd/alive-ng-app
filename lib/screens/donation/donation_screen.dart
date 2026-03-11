import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:alive_flutter_app/constants/app_constants.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/responsive_utils.dart';
import '../../services/donation_service.dart';
import '../../models/donation_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/web_launch_params.dart';
import '../../providers/firebase_auth_provider.dart';

class DonationScreen extends ConsumerStatefulWidget {
  const DonationScreen({super.key});

  @override
  ConsumerState<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<DonationScreen>
    with TickerProviderStateMixin {
  bool _isMonthlySelected = true;
  String _selectedCurrency = 'USD';
  double _selectedAmount = 0;
  bool _coverProcessingFees = false;
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _guestEmailController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Map<String, List<Map<String, dynamic>>> _donationAmounts = {
    'USD': [
      {'amount': 25, 'label': '\$25'},
      {'amount': 50, 'label': '\$50'},
      {'amount': 100, 'label': '\$100'},
    ],
    'NGN': [
      {'amount': 20000, 'label': '\u20A620K'},
      {'amount': 50000, 'label': '\u20A650K'},
      {'amount': 100000, 'label': '\u20A6100K'},
    ],
  };

  String? _selectedProjectId;
  String? _selectedProjectTitle;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();

    _loadSelectedProject();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _customAmountController.dispose();
    _guestNameController.dispose();
    _guestEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userAsync = ref.watch(firebaseUserProvider);
    final isAuthenticated = userAsync.value != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Support ALIVE',
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 20,
              tablet: 22,
              desktop: 24,
            ),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        foregroundColor:
            theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedProjectId != null)
                      Container(
                        padding: EdgeInsets.all(
                            ResponsiveUtils.getResponsiveValue(
                                context: context,
                                mobile: 12,
                                tablet: 14,
                                desktop: 16)),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.volunteer_activism,
                                color: Theme.of(context).colorScheme.primary),
                            SizedBox(
                                width: ResponsiveUtils.getResponsiveSpacing(
                                    context, 8)),
                            Expanded(
                              child: Text(
                                _selectedProjectTitle != null
                                    ? 'You are donating to: $_selectedProjectTitle'
                                    : 'You are donating to: Selected Project',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: context.responsiveFontSize(14),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _clearSelectedProject,
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                      ),
                    _buildHeader(context, theme, isDark),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 32)),
                    _buildDonationTypeSelector(context, theme),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 24)),
                    _buildAmountSelector(context, theme),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 24)),
                    if (!isAuthenticated) _buildGuestInfoForm(context, theme),
                    if (!isAuthenticated)
                      SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                              context, 16)),
                    _buildProcessingFeeOption(context, theme),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 32)),
                    _buildDonateButton(context, theme),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 40)),
                    _buildImpactSection(context, theme, isDark),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 32)),
                    _buildOtherWaysToGive(context, theme, isDark),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.primaryColor.withValues(alpha: 0.2),
                  theme.colorScheme.secondary.withValues(alpha: 0.1),
                ]
              : [
                  theme.primaryColor.withValues(alpha: 0.1),
                  theme.colorScheme.secondary.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ALIVE Logo
          SvgPicture.asset(
            'assets/images/alive_logo.svg',
            width: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 80,
              tablet: 100,
              desktop: 120,
            ),
            height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 80,
              tablet: 100,
              desktop: 120,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          Text(
            'You Can Be a Part of Something Bigger.',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 24,
                tablet: 28,
                desktop: 32,
              ),
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
          Text(
            'For more than 14 years, ALIVE NG Ministries has helped connect thousands of people with God\'s word and established churches around Nigeria. We can help connect new generations to the life-changing wisdom of the Bible.',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16,
                tablet: 18,
                desktop: 20,
              ),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationTypeSelector(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Giving Method',
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 20,
              tablet: 22,
              desktop: 24,
            ),
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        Row(
          children: [
            Expanded(
              child: _buildTypeCard(
                context,
                theme,
                'Give Monthly',
                'Sustain our mission',
                Icons.refresh,
                _isMonthlySelected,
                () => setState(() => _isMonthlySelected = true),
              ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 12)),
            Expanded(
              child: _buildTypeCard(
                context,
                theme,
                'One-Time Donation',
                'Make an impact today',
                Icons.favorite,
                !_isMonthlySelected,
                () => setState(() => _isMonthlySelected = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeCard(BuildContext context, ThemeData theme, String title,
      String subtitle, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: ResponsiveUtils.getResponsivePadding(context),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withValues(alpha: 0.1)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : theme.dividerColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? theme.primaryColor : theme.iconTheme.color,
              size: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 32,
                tablet: 36,
                desktop: 40,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? theme.primaryColor
                    : theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 4)),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                ),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSelector(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isMonthlySelected
                  ? 'Enter an amount to give monthly'
                  : 'Enter an amount to give one time',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            _buildCurrencySelector(context, theme),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        _buildPresetAmounts(context, theme),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        _buildCustomAmountInput(context, theme),
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
      child: DropdownButton<String>(
        value: _selectedCurrency,
        underline: const SizedBox(),
        items: ['USD', 'NGN'].map((currency) {
          return DropdownMenuItem(
            value: currency,
            child: Text(
              currency,
              style: TextStyle(
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
            setState(() {
              _selectedCurrency = value;
              _selectedAmount = 0;
              _customAmountController.clear();
            });
          }
        },
      ),
    );
  }

  Widget _buildPresetAmounts(BuildContext context, ThemeData theme) {
    final amounts = _donationAmounts[_selectedCurrency] ?? [];

    return Wrap(
      spacing: ResponsiveUtils.getResponsiveSpacing(context, 12),
      runSpacing: ResponsiveUtils.getResponsiveSpacing(context, 12),
      children: amounts.map((amountData) {
        final amount = (amountData['amount'] as num).toDouble();
        final label = amountData['label'] as String;
        final isSelected = _selectedAmount == amount;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedAmount = amount;
              _customAmountController.clear();
            });
          },
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
              color: isSelected ? theme.primaryColor : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.primaryColor
                    : theme.dividerColor.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
                fontWeight: FontWeight.bold,
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
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
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            ),
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
        TextField(
          controller: _customAmountController,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 18,
              tablet: 20,
              desktop: 22,
            ),
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            prefixText: _selectedCurrency == 'USD' ? '\$ ' : '₦ ',
            prefixStyle: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
            hintText: 'Enter amount',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: theme.cardColor,
          ),
          onChanged: (value) {
            final amount = double.tryParse(value);
            setState(() {
              _selectedAmount = amount ?? 0;
            });
          },
        ),
      ],
    );
  }

  Widget _buildProcessingFeeOption(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _coverProcessingFees = !_coverProcessingFees),
      child: Container(
        padding: ResponsiveUtils.getResponsivePadding(context),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _coverProcessingFees,
              onChanged: (value) =>
                  setState(() => _coverProcessingFees = value ?? false),
              activeColor: theme.primaryColor,
            ),
            Expanded(
              child: Text(
                'I would like to add 3.5% to cover processing fees so that my donation goes a little further.',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 14,
                    tablet: 16,
                    desktop: 18,
                  ),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonateButton(BuildContext context, ThemeData theme) {
    final isEnabled = _selectedAmount > 0;
    final totalAmount =
        _coverProcessingFees ? _selectedAmount * 1.035 : _selectedAmount;
    final userAsync = ref.watch(firebaseUserProvider);
    final isAuthenticated = userAsync.value != null;
    final guestInfoValid = _guestEmailController.text.trim().isNotEmpty &&
        _guestNameController.text.trim().isNotEmpty;

    return Column(
      children: [
        if (isEnabled && _coverProcessingFees)
          Padding(
            padding: EdgeInsets.only(
                bottom: ResponsiveUtils.getResponsiveSpacing(context, 8)),
            child: Text(
              'Total: ${_selectedCurrency == 'USD' ? '\$' : '₦'}${totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 56,
            tablet: 60,
            desktop: 64,
          ),
          child: ElevatedButton(
            onPressed: isEnabled && (isAuthenticated || guestInfoValid)
                ? _processDonation
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: isEnabled ? 8 : 0,
              shadowColor: theme.primaryColor.withValues(alpha: 0.3),
            ),
            child: Text(
              _isMonthlySelected ? 'Start Monthly Giving' : 'Donate One-Time',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
        Text(
          'Your donation helps make the life-changing wisdom of the Bible accessible to all.',
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 14,
              tablet: 16,
              desktop: 18,
            ),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildGuestInfoForm(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Details',
          style: TextStyle(
            fontSize: context.responsiveFontSize(18),
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
        TextField(
          controller: _guestNameController,
          textCapitalization: TextCapitalization.words,
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
          controller: _guestEmailController,
          keyboardType: TextInputType.emailAddress,
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

  Widget _buildImpactSection(
      BuildContext context, ThemeData theme, bool isDark) {
    final impactItems = [
      {
        'icon': Icons.public,
        'title': 'Reach the World',
        'description':
            'Provide devotionals, books, and courses to believers across the globe who cannot afford a subscription.',
      },
      {
        'icon': Icons.lightbulb,
        'title': 'Be a Light to the World',
        'description':
            'Share God globally with outreach programs like The Untold Truth, which involves a year mission activities in an unentered area and biblical materials to remote villages and cities.',
      },
      {
        'icon': Icons.favorite,
        'title': 'Provide Hope to the Lost',
        'description':
            'Help put tract resources in correction centers in Nigeria',
      },
      {
        'icon': Icons.translate,
        'title': 'Break Language Barriers',
        'description':
            'Create, translate, and offer biblically based courses in various languages',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Gift Will:',
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 24,
              tablet: 26,
              desktop: 28,
            ),
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 20)),
        ...impactItems.map((item) => _buildImpactCard(context, theme, item)),
      ],
    );
  }

  Widget _buildImpactCard(
      BuildContext context, ThemeData theme, Map<String, dynamic> item) {
    return Container(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 16)),
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: theme.primaryColor,
              size: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 24,
                tablet: 28,
                desktop: 32,
              ),
            ),
          ),
          SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] as String,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 22,
                    ),
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                Text(
                  item['description'] as String,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherWaysToGive(
      BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.primaryColor.withValues(alpha: 0.1),
                  theme.colorScheme.secondary.withValues(alpha: 0.05),
                ]
              : [
                  theme.primaryColor.withValues(alpha: 0.05),
                  theme.colorScheme.secondary.withValues(alpha: 0.02),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Other Ways to Give',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 22,
                tablet: 24,
                desktop: 26,
              ),
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          _buildOtherGivingOption(
            context,
            theme,
            'Non-Monetary Gifts',
            'Share your skills and time with our ministry',
            Icons.volunteer_activism,
            onTap: () => context.go(AppConstants.nonMonetaryGiftRoute),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
          _buildOtherGivingOption(
            context,
            theme,
            'Gift in Kind',
            'We have a list of items on our website (ALIVENIGERIA.ORG) that as the Lord lay it in your heart you can give',
            Icons.card_giftcard,
            onTap: () => context.go(AppConstants.giftInKindRoute),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherGivingOption(BuildContext context, ThemeData theme,
      String title, String description, IconData icon,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: ResponsiveUtils.getResponsivePadding(context),
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: theme.primaryColor,
              size: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 24,
                tablet: 28,
                desktop: 32,
              ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 16,
                        tablet: 18,
                        desktop: 20,
                      ),
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(context, 4)),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 14,
                        tablet: 16,
                        desktop: 18,
                      ),
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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

  void _processDonation() async {
    final rootCtx = context;
    final amount = _selectedAmount;
    final currency = _selectedCurrency;
    final isMonthly = _isMonthlySelected;
    final userAsync = ref.read(firebaseUserProvider);
    final isAuthenticated = userAsync.value != null;

    if (amount <= 0) {
      ScaffoldMessenger.of(rootCtx).showSnackBar(
        const SnackBar(content: Text('Please select or enter a valid amount')),
      );
      return;
    }

    // Determine donation type:
    // Route project donations through existing donation channel with metadata
    final DonationType type = _selectedProjectId != null
        ? DonationType.ministrySupport
        : DonationType.generalSupport;

    // Validate minimums
    final donationService = DonationService();
    final isValid = donationService.validateDonationAmount(type, amount);
    if (!isValid) {
      final min = donationService.getMinimumDonationAmount(type);
      ScaffoldMessenger.of(rootCtx).showSnackBar(
        SnackBar(
            content: Text(
                'Minimum donation is ${currency == 'USD' ? '\$' : '₦'}${min.toStringAsFixed(2)}')),
      );
      return;
    }

    // Adjust amount to include processing fees if selected
    final totalAmount = _coverProcessingFees ? (amount * 1.035) : amount;

    // Create donation record
    try {
      // For general support, we use Paystack
      final donation = await donationService.createDonation(
        type: type,
        amount: totalAmount,
        paymentMethod: PaymentMethod.paystack,
        notes: isMonthly ? 'Monthly giving' : 'One-time donation',
        metadata: {
          'recurring': isMonthly,
          'currency': currency,
          'source': 'donation_screen_v2',
          if (_selectedProjectId != null) 'project_id': _selectedProjectId,
          if (_selectedProjectTitle != null)
            'project_title': _selectedProjectTitle,
        },
        guestName: isAuthenticated ? null : _guestNameController.text.trim(),
        guestEmail: isAuthenticated ? null : _guestEmailController.text.trim(),
      );

      // Process payment via Paystack
      if (!rootCtx.mounted) return;
      final paymentResult = await donationService.processPaystackPayment(
        context: rootCtx,
        donationId: donation.id,
        amount: totalAmount,
        currency: currency,
        email: donation.userEmail,
        isRecurringMonthly: isMonthly,
      );

      if (paymentResult['success'] == true) {
        // Show success
        if (!rootCtx.mounted) return;
        showDialog(
          context: rootCtx,
          barrierDismissible: false,
          builder: (ctx) {
            final dialogTheme = Theme.of(ctx);
            return AlertDialog(
              backgroundColor: dialogTheme.dialogBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Thank You!',
                style: TextStyle(
                  color: dialogTheme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dialogTheme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_outline,
                        color: dialogTheme.colorScheme.primary, size: 60),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your donation was successful.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dialogTheme.colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reference: ${paymentResult['transaction_id'] ?? donation.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: dialogTheme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      rootCtx.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dialogTheme.colorScheme.primary,
                      foregroundColor: dialogTheme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        // Show error
        if (!rootCtx.mounted) return;
        ScaffoldMessenger.of(rootCtx).showSnackBar(
          SnackBar(
              content: Text(paymentResult['message'] ?? 'Donation failed')),
        );
      }
    } catch (e) {
      if (!rootCtx.mounted) return;
      ScaffoldMessenger.of(rootCtx).showSnackBar(
        SnackBar(content: Text('Error processing donation: $e')),
      );
    }
  }

  Future<void> _loadSelectedProject() async {
    try {
      final projectId = getSelectedProjectId();
      if (projectId == null) return;
      _selectedProjectId = projectId;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .get();
        final data = doc.data();
        if (data != null) {
          _selectedProjectTitle =
              (data['title'] as String?) ?? (data['name'] as String?);
        }
      } catch (_) {
        // ignore fetch errors; will still proceed with projectId only
      }
      setState(() {});
      clearSelectedProjectId();
    } catch (_) {
      // ignore
    }
  }

  void _clearSelectedProject() {
    setState(() {
      _selectedProjectId = null;
      _selectedProjectTitle = null;
    });
  }
}
