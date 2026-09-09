import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:alive_flutter_app/constants/app_constants.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/payment_provider.dart';
import '../../models/donation_presentation_models.dart';
import 'widgets/donation_type_card.dart';
import 'widgets/impact_card.dart';
import 'widgets/giving_method_row.dart';
import 'widgets/project_card.dart';
import 'widgets/project_fund_update.dart';
import '../../models/donation_models.dart';
import '../../models/project_model.dart';
import '../../config/donation_defaults.dart';
import '../../utils/web_launch_params.dart';
import '../../providers/appwrite_auth_provider.dart';
import '../../widgets/custom_app_bar.dart';

class DonationScreen extends ConsumerStatefulWidget {
  const DonationScreen({super.key});

  @override
  ConsumerState<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<DonationScreen>
    with TickerProviderStateMixin {
  int get _ministryYears {
    final start = DateTime(2011, 3, 20);
    final now = DateTime.now();
    int years = now.year - start.year;
    if (now.month < start.month ||
        (now.month == start.month && now.day < start.day)) {
      years--;
    }
    return years;
  }

  final Set<String> _selectedFundDesignations = <String>{};
  final TextEditingController _customDesignationController =
      TextEditingController();
  final List<Project> _fallbackProjects = donationFallbackProjects;

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

  static const Map<String, List<DonationAmountOption>> _donationAmounts = {
    'USD': [
      DonationAmountOption(amount: 25, label: '\$25'),
      DonationAmountOption(amount: 50, label: '\$50'),
      DonationAmountOption(amount: 100, label: '\$100'),
    ],
    'NGN': [
      DonationAmountOption(amount: 20000, label: '\u20A620K'),
      DonationAmountOption(amount: 50000, label: '\u20A650K'),
      DonationAmountOption(amount: 100000, label: '\u20A6100K'),
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
    _fetchExchangeRate();
  }

  double _exchangeRate = 1650.0; // Default fallback
  Future<void> _fetchExchangeRate() async {
    try {
      final value = await ref
          .read(donationServiceProvider)
          .getAppSettingValue('usd_to_ngn_rate');
      final rate = double.tryParse(value ?? '');
      if (rate != null && rate > 0) {
        setState(() => _exchangeRate = rate);
        debugPrint('Using Appwrite exchange rate: $_exchangeRate');
        return;
      }
    } catch (e) {
      debugPrint('Appwrite exchange rate fetch failed: $e');
    }
    debugPrint('Using hardcoded fallback Exchange Rate: $_exchangeRate');
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
    final userAsync = ref.watch(appwriteUserStreamProvider);
    final isAuthenticated = userAsync.value != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const CustomAppBar(
        title: 'Support ALIVE',
        showBackButton: true,
        showThemeToggle: true,
        showLanguageToggle: true,
        showDonationButton: false, // Already on donation screen
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final hasStickyProject = _selectedProjectId != null;
          final hasStickyDesignation = _selectedFundDesignations.isNotEmpty;

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Sticky Top Bar for Selected Project & Fund Split Ratio
                  if (hasStickyProject || hasStickyDesignation)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasStickyProject)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.volunteer_activism,
                                      size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedProjectTitle != null
                                          ? 'Project: $_selectedProjectTitle'
                                          : 'Selected Project',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _clearSelectedProject,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Change', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          if (hasStickyProject && hasStickyDesignation)
                            const SizedBox(height: 6),
                          if (hasStickyDesignation)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 18, color: theme.colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedFundDesignations.length == 1
                                          ? 'Designated: ${_selectedFundDesignations.first} (100%)'
                                          : 'Split (${_selectedFundDesignations.length} areas): ${_selectedFundDesignations.join(', ')} (${(100.0 / _selectedFundDesignations.length).toStringAsFixed(0)}% each)',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSecondaryContainer,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => _selectedFundDesignations.clear()),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Reset', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: ResponsiveUtils.getResponsivePadding(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    if (_selectedProjectId != null)
                      FutureBuilder<Project?>(
                        future: ref
                            .read(donationServiceProvider)
                            .getProject(_selectedProjectId!),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data == null) {
                            return const SizedBox.shrink();
                          }
                          final data = snapshot.data!;
                          final goal = data.targetAmount;
                          final raised = data.raisedAmount;
                          if (goal <= 0) {
                            return const SizedBox.shrink();
                          }

                          double displayGoal = goal;
                          double displayRaised = raised;
                          if (_selectedCurrency == 'USD') {
                            displayGoal = goal / _exchangeRate;
                            displayRaised = raised / _exchangeRate;
                          }

                          return Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withValues(alpha: 0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      theme.shadowColor.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Project Goal',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      '${((raised / goal) * 100).toInt()}%',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: (raised / goal)
                                        .clamp(0.0, 1.0)
                                        .toDouble(),
                                    minHeight: 10,
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.colorScheme.secondary),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Raised: ${_selectedCurrency == 'USD' ? '\$' : '₦'}${_formatCompact(displayRaised)}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Goal: ${_selectedCurrency == 'USD' ? '\$' : '₦'}${_formatCompact(displayGoal)}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6)),
                                    ),
                                  ],
                                ),
                                ProjectFundUpdate(project: data),
                              ],
                            ),
                          );
                        },
                      ),
                    _buildHeader(context, theme, isDark),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 32)),
                    // 1. Where Your Support Goes (Impact Section) FIRST
                    _buildImpactSection(context, theme, isDark),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 32)),
                    // 2. Other Ways to Give SECOND
                    _buildOtherWaysToGive(context, theme, isDark),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 36)),
                    // 3. Giving Method & Amount Checkout THIRD
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
                  ],
                ),
              ),
            ),
          ],
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
                  theme.colorScheme.primary.withValues(alpha: 0.2),
                  theme.colorScheme.secondary.withValues(alpha: 0.1),
                ]
              : [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.colorScheme.secondary.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
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
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
          Text(
            'For more than $_ministryYears years, ALIVE Nigeria Ministries has helped connect thousands of people with God\'s word and established churches around Nigeria. We can help connect new generations to the life-changing wisdom of the Bible.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
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
          'Giving Method',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
        Row(
          children: [
            Expanded(
              child: DonationTypeCard(
                title: 'Monthly',
                icon: Icons.refresh,
                isSelected: _isMonthlySelected,
                onTap: () => setState(() => _isMonthlySelected = true),
              ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 8)),
            Expanded(
              child: DonationTypeCard(
                title: 'One-Time',
                icon: Icons.favorite,
                isSelected: !_isMonthlySelected,
                onTap: () => setState(() => _isMonthlySelected = false),
              ),
            ),
          ],
        ),
      ],
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildCurrencySelector(context, theme),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        _buildPresetAmounts(context, theme),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        _buildCustomAmountInput(context, theme),
        if (_selectedAmount > 0 && _selectedFundDesignations.length > 1) ...[
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
                Icon(Icons.call_split_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Split: ${_selectedCurrency == 'USD' ? '\$' : '₦'}${(_selectedAmount / _selectedFundDesignations.length).toStringAsFixed(2)} each across ${_selectedFundDesignations.length} designated areas (${(100.0 / _selectedFundDesignations.length).toStringAsFixed(0)}% each)',
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
      child: DropdownButton<String>(
        value: _selectedCurrency,
        underline: const SizedBox(),
        items: ['USD', 'NGN'].map((currency) {
          return DropdownMenuItem(
            value: currency,
            child: Text(
              currency,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
        final amount = amountData.amount;
        final label = amountData.label;
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
        TextField(
          controller: _customAmountController,
          keyboardType: TextInputType.number,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          decoration: InputDecoration(
            prefixText: _selectedCurrency == 'USD' ? '\$ ' : '₦ ',
            prefixStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
              activeColor: theme.colorScheme.primary,
            ),
            Expanded(
              child: Text(
                'I would like to add 3.5% to cover processing fees so that my donation goes a little further.',
                style: theme.textTheme.bodyMedium?.copyWith(
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
    final userAsync = ref.watch(appwriteUserStreamProvider);
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
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
            // Enable only when an amount is selected and, for guests, the
            // name/email details have been filled in.
            onPressed: isEnabled && (isAuthenticated || guestInfoValid)
                ? _handleDonateClick
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: Size(
                ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 140, tablet: 160, desktop: 180),
                ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 44, tablet: 48, desktop: 52),
              ),
              elevation: isEnabled ? 8 : 0,
              shadowColor: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            child: Text(
              _isMonthlySelected ? 'Start Monthly Giving' : 'Donate One-Time',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
        Text(
          'Your donation helps make the life-changing wisdom of the Bible accessible to all.',
          style: theme.textTheme.bodyMedium?.copyWith(
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
          style: theme.textTheme.titleMedium?.copyWith(
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
    const impactItems = [
      DonationImpact(
        icon: Icons.terrain,
        title: 'Rural Missions',
        description:
            'Send teams to remote communities with the Gospel and compassionate care.',
      ),
      DonationImpact(
        icon: Icons.location_city,
        title: 'Campus/City Missions',
        description:
            'Send teams to Campus/City communities with the Gospel and compassionate care.',
      ),
      DonationImpact(
        icon: Icons.school,
        title: 'Missionary Training',
        description:
            'Equip and train the next generation of Groundbreakers and Missionaries for effective witness.',
      ),
      DonationImpact(
        icon: Icons.local_hospital,
        title: 'Health Evangelism',
        description:
            'Provide medical care that opens hearts to the transforming power of the Gospel.',
      ),
      DonationImpact(
        icon: Icons.phonelink,
        title: 'Digital Ministry',
        description:
            'Leverage technology to share the Good News through tracts, podcasts, online events and discipleship.',
      ),
      DonationImpact(
        icon: Icons.people_outline,
        title: 'LTMs Stipends',
        description: 'Support the monthly upkeep of long-term field workers.',
      ),
      DonationImpact(
        icon: Icons.groups_outlined,
        title: 'STMs Stipends',
        description: 'Support the monthly upkeep of short-term field workers.',
      ),
      DonationImpact(
        icon: Icons.volunteer_activism,
        title: 'Volunteers',
        description:
            'Support the monthly upkeep of the volunteers at the mission field.',
      ),
      DonationImpact(
        icon: Icons.edit_note,
        title: 'Custom Purpose',
        description:
            'Specify your own custom ministry designation or special project.',
      ),
    ];

    final splitCount = _selectedFundDesignations.length;
    final splitPercent = splitCount > 1
        ? (100.0 / splitCount)
        : (splitCount == 1 ? 100.0 : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Where Your Support Goes',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap one or multiple areas to direct or split your donation ratio',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedFundDesignations.isNotEmpty)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _selectedFundDesignations.clear()),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Reset'),
              ),
          ],
        ),
        if (splitCount > 1) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pie_chart_rounded,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Split Donation: Allocated equally ($splitCount areas @ ${splitPercent!.toStringAsFixed(0)}% each)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Selected designations as wrapping chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _selectedFundDesignations.map((designation) {
                    return Chip(
                      label: Text(
                        designation,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        ...impactItems.map((item) {
          final isSelected = _selectedFundDesignations.contains(item.title);
          return ImpactCard(
            impact: item,
            isSelected: isSelected,
            splitPercent: isSelected ? splitPercent : null,
            selectionLabel: isSelected
                ? (splitCount > 1
                    ? 'Included in split (${splitPercent!.toStringAsFixed(0)}%)'
                    : 'Selected for this Gift (100%)')
                : null,
            onTap: () => _selectDesignation(item.title),
          );
        }),
      ],
    );
  }

  void _selectDesignation(String title) {
    if (title == 'Custom Purpose') {
      _showCustomDesignationDialog();
    } else {
      setState(() {
        if (_selectedFundDesignations.contains(title)) {
          _selectedFundDesignations.remove(title);
        } else {
          _selectedFundDesignations.add(title);
        }
        _selectedProjectId = null;
        _selectedProjectTitle = null;
      });
      final count = _selectedFundDesignations.length;
      final msg = count == 0
          ? 'Cleared designation (Will go where most needed)'
          : (count == 1
              ? 'Selected: ${_selectedFundDesignations.first} (100%)'
              : 'Selected $count areas (${(100.0 / count).toStringAsFixed(0)}% split each)');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCustomDesignationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Gift Purpose'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please specify how you would like your donation used:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customDesignationController,
              decoration: const InputDecoration(
                hintText: 'e.g. Ondo Medical Outreach, Tract printing',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _customDesignationController.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  _selectedFundDesignations.add(text);
                  _selectedProjectId = null;
                  _selectedProjectTitle = null;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Custom designation saved: $text'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Save Designation'),
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
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.colorScheme.secondary.withValues(alpha: 0.05),
                ]
              : [
                  theme.colorScheme.primary.withValues(alpha: 0.05),
                  theme.colorScheme.secondary.withValues(alpha: 0.02),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Other Ways to Give',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
          GivingMethodRow(
            onNonMonetary: () => context.go(AppConstants.nonMonetaryGiftRoute),
            onGiftInKind: () => context.go(AppConstants.giftInKindRoute),
            onProjects: _showProjectsPicker,
          ),
        ],
      ),
    );
  }

  void _handleDonateClick() {
    final userAsync = ref.read(appwriteUserStreamProvider);
    final isAuthenticated = userAsync.value != null;

    if (isAuthenticated) {
      _processDonation();
      return;
    }

    final hasName = _guestNameController.text.trim().isNotEmpty;
    final hasEmail = _guestEmailController.text.trim().isNotEmpty;

    if (hasName && hasEmail) {
      _processDonation();
      return;
    }

    // Prompt guest for their details
    showDialog(
      context: context,
      builder: (ctx) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Donor Details'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please provide your name and email to proceed with your donation:'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _guestNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _guestEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop();
                  _processDonation();
                }
              },
              child: const Text('Continue to Payment'),
            ),
          ],
        );
      },
    );
  }

  void _processDonation() async {
    final rootCtx = context;
    final amount = _selectedAmount;
    final currency = _selectedCurrency;
    final isMonthly = _isMonthlySelected;
    final userAsync = ref.read(appwriteUserStreamProvider);
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
    final donationService = ref.read(donationServiceProvider);
    final isValid = donationService.validateDonationAmount(type, amount,
        currency: currency);
    if (!isValid) {
      final min =
          donationService.getMinimumDonationAmount(type, currency: currency);
      ScaffoldMessenger.of(rootCtx).showSnackBar(
        SnackBar(
            content: Text(
                'Minimum donation is ${currency == 'USD' ? '\$' : '₦'}${min.toStringAsFixed(0)}')),
      );
      return;
    }

    // Adjust amount to include processing fees if selected
    final totalAmount = _coverProcessingFees ? (amount * 1.035) : amount;

    // Create donation record
    try {
      final designations = _selectedFundDesignations.toList();
      final designationSummary = designations.isEmpty
          ? null
          : (designations.length == 1
              ? designations.first
              : 'Split: ${designations.join(', ')} (${(100.0 / designations.length).toStringAsFixed(0)}% each)');

      // For general support, we use Paystack
      final donation = await donationService.createDonation(
        type: type,
        amount: totalAmount,
        currency: currency,
        paymentMethod: PaymentMethod.paystack,
        materialTitle: _selectedProjectTitle ?? designationSummary,
        notes: isMonthly
            ? 'Monthly giving${designationSummary != null ? ' - $designationSummary' : ''}'
            : 'One-time donation${designationSummary != null ? ' - $designationSummary' : ''}',
        metadata: {
          'recurring': isMonthly,
          'currency': currency,
          'source': 'donation_screen_v2',
          if (_selectedProjectId != null) 'project_id': _selectedProjectId,
          if (_selectedProjectTitle != null)
            'project_title': _selectedProjectTitle,
          if (designations.isNotEmpty) ...{
            'fund_designation': designationSummary,
            'fund_designations': designations,
            'split_count': designations.length,
            'split_percent': designations.length > 1
                ? (100.0 / designations.length).round()
                : 100,
          },
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

      final checkoutInitialized = paymentResult['initialized'] == true;
      if (paymentResult['success'] == true) {
        // Show success
        if (!rootCtx.mounted) return;
        showDialog(
          context: rootCtx,
          barrierDismissible: false,
          builder: (ctx) {
            final dialogTheme = Theme.of(ctx);
            return AlertDialog(
              backgroundColor: dialogTheme.dialogTheme.backgroundColor ??
                  dialogTheme.colorScheme.surface,
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
                    _selectedProjectTitle != null
                        ? 'Your donation for $_selectedProjectTitle was successful.'
                        : 'Your donation was successful.',
                    textAlign: TextAlign.center,
                    style: dialogTheme.textTheme.bodyLarge?.copyWith(
                      color: dialogTheme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reference: ${paymentResult['transaction_id'] ?? donation.id}',
                    style: dialogTheme.textTheme.labelSmall?.copyWith(
                      color: dialogTheme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A receipt will be emailed to you for your records.',
                    style: dialogTheme.textTheme.labelSmall?.copyWith(
                      color: dialogTheme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
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
      } else if (checkoutInitialized) {
        if (!rootCtx.mounted) return;
        showDialog(
          context: rootCtx,
          builder: (ctx) {
            final dialogTheme = Theme.of(ctx);
            final donationLabel =
                _selectedProjectTitle ?? 'your selected support';
            return AlertDialog(
              title: const Text('Checkout Started'),
              content: Text(
                'Your donation for $donationLabel has been initialized. Complete the payment to receive your confirmation email and recorded receipt.',
                style: dialogTheme.textTheme.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
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
      // Check for URL param first (robustness for external links)
      String? projectId;
      if (Uri.base.queryParameters.containsKey('projectId')) {
        projectId = Uri.base.queryParameters['projectId'];
      } else {
        projectId = getSelectedProjectId();
      }

      if (projectId == null || projectId == 'general_mission') return;
      _selectedProjectId = projectId;
      try {
        final data =
            await ref.read(donationServiceProvider).getProject(projectId);
        if (data != null) {
          _selectedProjectTitle = data.title;
        } else {
          _selectedProjectTitle = _fallbackProject(projectId)?.title;
        }
      } catch (_) {
        _selectedProjectTitle = _fallbackProject(projectId)?.title;
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

  /// Opens a bottom sheet listing ministry projects from Appwrite.
  /// User can tap "Donate to This Project" to pre-select that project and
  /// scroll down to the donation form.
  void _showProjectsPicker() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ConstrainedBox(
          // Sheet hugs its content instead of forcing a fixed 70% height,
          // which used to leave a long white area under the last project's
          // donate button.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ministry Projects',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: FutureBuilder<List<Project>>(
                  future: _fetchProjects(),
                  builder: (ctx3, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return SizedBox(
                        height: 240,
                        child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_off,
                                size: 48,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('No projects available at this time',
                                style: theme.textTheme.bodyLarge),
                          ],
                        ),
                        ),
                      );
                    }
                    final projects = snapshot.data!;
                    // Use SingleChildScrollView with Column to avoid scroll conflicts
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          for (int i = 0; i < projects.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            ProjectCard(
                              project: projects[i],
                              onDonate: () {
                                Navigator.of(ctx).pop();
                                setState(() {
                                  _selectedProjectId = projects[i].id;
                                  _selectedProjectTitle = projects[i].title;
                                });
                                setSelectedProjectId(projects[i].id);
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          ),
        ),
        ),
      ),
    );
  }

  /// Fetches projects ordered by 'priority' ascending.
  String _formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return value.toStringAsFixed(0);
  }

  /// Shows all statuses so users can see active, planning, and completed projects.
  Future<List<Project>> _fetchProjects() async {
    final projects =
        await ref.read(donationServiceProvider).getDonationProjects();
    if (projects.isNotEmpty) return projects;
    return _fallbackProjects;
  }

  Project? _fallbackProject(String id) {
    for (final project in _fallbackProjects) {
      if (project.id == id) return project;
    }
    return null;
  }
}
