import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:alive_flutter_app/constants/app_constants.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/responsive_utils.dart';
import '../../services/donation_service.dart';
import '../../models/donation_models.dart';
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
  static const List<Map<String, dynamic>> _fallbackProjects = [
    {
      'id': 'impact_hub_center',
      'title': 'Impact Hub Center',
      'summary': 'Community discipleship and outreach facility',
      'description':
          'A central hub for training, discipleship, and community engagement.',
      'goal': 35000000.0,
      'raised': 8000000.0,
      'currency': 'NGN',
      'status': 'active',
      'priority': 1,
      'cta_label': 'Donate for this item',
      'image_url':
          'https://images.unsplash.com/photo-1593914370442-49d414beca24?q=80&w=1031&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      'fund_update_title': 'Progress so far',
      'fund_update_text':
          'Seed funding has helped prepare the project scope, early planning, and ministry coordination for the hub.',
      'fund_update_images': <String>[],
    },
    {
      'id': 'vehicle_purchase',
      'title': 'Vehicle Purchase',
      'summary': 'Mission vehicle for outreach logistics',
      'description':
          'Reliable transportation for mission trips and logistics across Nigeria.',
      'goal': 18000000.0,
      'raised': 0.0,
      'currency': 'NGN',
      'status': 'active',
      'priority': 2,
      'cta_label': 'Donate for this item',
      'image_url':
          'https://images.unsplash.com/photo-1597685204565-110abf469a1e?q=80&w=870&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      'fund_update_title': '',
      'fund_update_text': '',
      'fund_update_images': <String>[],
    },
    {
      'id': 'media_studio_setup',
      'title': 'Media Studio Setup',
      'summary': 'Podcast and content production equipment',
      'description':
          'Equipping the ministry with high-quality media production capabilities.',
      'goal': 9000000.0,
      'raised': 0.0,
      'currency': 'NGN',
      'status': 'planning',
      'priority': 3,
      'cta_label': 'Donate for this item',
      'image_url':
          'https://images.unsplash.com/photo-1769699167906-a44d5ae50abb?q=80&w=387&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      'fund_update_title': '',
      'fund_update_text': '',
      'fund_update_images': <String>[],
    },
  ];

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
    _fetchExchangeRate();
  }

  double _exchangeRate = 1650.0; // Default fallback
  Future<void> _fetchExchangeRate() async {
    try {
      final value =
          await DonationService().getAppSettingValue('usd_to_ngn_rate');
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
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
                    if (_selectedProjectId != null)
                      FutureBuilder<Map<String, dynamic>?>(
                        future:
                            DonationService().getProject(_selectedProjectId!),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data == null) {
                            return const SizedBox.shrink();
                          }
                          final data = snapshot.data!;
                          final goal = (data['goal'] as num?)?.toDouble() ?? 0;
                          final raised =
                              (data['raised'] as num?)?.toDouble() ?? 0;
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
                                  color: Colors.black.withValues(alpha: 0.05),
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
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      '${((raised / goal) * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 14,
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
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Goal: ${_selectedCurrency == 'USD' ? '\$' : '₦'}${_formatCompact(displayGoal)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6)),
                                    ),
                                  ],
                                ),
                                _buildFundUpdateSection(context, data),
                              ],
                            ),
                          );
                        },
                      ),
                    _buildHeader(context, theme, isDark),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 16)),
                    // View Projects button — lets users donate to a specific project
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showProjectsPicker,
                        icon: const Icon(Icons.folder_special),
                        label: const Text('View Projects & Donate to a Cause'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.secondary,
                          side: BorderSide(
                              color: theme.colorScheme.secondary, width: 1.5),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveUtils.getResponsiveSpacing(
                                context, 14),
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
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
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
          Text(
            'For more than 14 years, ALIVE NG Ministries has helped connect thousands of people with God\'s word and established churches around Nigeria. We can help connect new generations to the life-changing wisdom of the Bible.',
            style: theme.textTheme.bodyLarge?.copyWith(
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
          'Choose Your Giving Method',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
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
        constraints: const BoxConstraints(minHeight: 176),
        padding: ResponsiveUtils.getResponsivePadding(context),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.iconTheme.color,
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 15,
                      tablet: 16,
                      desktop: 18,
                    ),
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 4)),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                    color: isSelected
                        ? theme.colorScheme.onPrimary.withValues(alpha: 0.84)
                        : theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
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
              style: theme.textTheme.titleLarge?.copyWith(
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 22,
                    ),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
            prefixStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
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
            onPressed: isEnabled && (isAuthenticated || guestInfoValid)
                ? _processDonation
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
          style: theme.textTheme.headlineSmall?.copyWith(
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
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: theme.colorScheme.primary,
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                Text(
                  item['description'] as String,
                  style: theme.textTheme.bodyMedium?.copyWith(
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
            style: theme.textTheme.headlineSmall?.copyWith(
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
              color: theme.colorScheme.primary,
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
        currency: currency,
        paymentMethod: PaymentMethod.paystack,
        materialTitle: _selectedProjectTitle,
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
                      color: dialogTheme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A receipt will be emailed to you for your records.',
                    style: TextStyle(
                      fontSize: 12,
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
        final data = await DonationService().getProject(projectId);
        if (data != null) {
          _selectedProjectTitle =
              (data['title'] as String?) ?? (data['name'] as String?);
        } else {
          final fallback =
              _fallbackProjects.cast<Map<String, dynamic>?>().firstWhere(
                    (project) => project?['id'] == projectId,
                    orElse: () => null,
                  );
          _selectedProjectTitle = fallback?['title'] as String?;
        }
      } catch (_) {
        final fallback =
            _fallbackProjects.cast<Map<String, dynamic>?>().firstWhere(
                  (project) => project?['id'] == projectId,
                  orElse: () => null,
                );
        _selectedProjectTitle = fallback?['title'] as String?;
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
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx2, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchProjects(),
                  builder: (ctx3, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return Center(
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
                      );
                    }
                    final projects = snapshot.data!;
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: projects.length,
                      itemBuilder: (ctx4, i) {
                        final project = projects[i];
                        final id = project['id'] as String? ?? '';
                        final title =
                            (project['title'] as String?) ?? 'Unnamed Project';
                        // 'summary' is short caption, 'description' is full text — matching web modal
                        final summary = (project['summary'] as String?) ?? '';
                        final description =
                            (project['description'] as String?) ?? '';
                        final goal = project['goal'] as num?;
                        final raised = (project['raised'] as num?) ?? 0;
                        final status = (project['status'] as String?) ?? '';
                        final imageUrl = project['image_url'] as String?;
                        final ctaLabel = (project['cta_label'] as String?) ??
                            'Donate for this item';

                        // Badge color per status (mirrors web badges)
                        Color statusColor;
                        switch (status.toLowerCase()) {
                          case 'active':
                            statusColor = theme.colorScheme.tertiary;
                            break;
                          case 'planning':
                            statusColor = theme.colorScheme.secondary;
                            break;
                          case 'completed':
                            statusColor = theme.colorScheme.primary;
                            break;
                          default:
                            statusColor = theme.colorScheme.outline;
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Project image — matches web modal's image display
                              if (imageUrl != null && imageUrl.isNotEmpty)
                                Image.network(
                                  imageUrl,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title + status badge row
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(title,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                        ),
                                        if (status.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                  alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                  color: statusColor.withValues(
                                                      alpha: 0.4)),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: statusColor),
                                            ),
                                          ),
                                      ],
                                    ),
                                    // Summary (short caption)
                                    if (summary.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(summary,
                                          style: theme.textTheme.bodyMedium,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                    // Full description
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(description,
                                          style: theme.textTheme.bodySmall,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                    // Goal / raised progress bar (NGN currency — same as web modal)
                                    if (goal != null && goal > 0) ...[
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: (raised / goal)
                                              .clamp(0.0, 1.0)
                                              .toDouble(),
                                          minHeight: 6,
                                          backgroundColor: theme
                                              .colorScheme.onSurface
                                              .withValues(alpha: 0.15),
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        // Goal and raised are stored in NGN — matching web formatCurrency()
                                        '₦${_formatCompact(raised.toDouble())} raised of ₦${_formatCompact(goal.toDouble())}',
                                        style: theme.textTheme.labelMedium,
                                      ),
                                    ],
                                    _buildFundUpdateSection(context, project),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          setState(() {
                                            _selectedProjectId = id;
                                            _selectedProjectTitle = title;
                                          });
                                          setSelectedProjectId(id);
                                        },
                                        icon: const Icon(
                                            Icons.volunteer_activism),
                                        label: Text(ctaLabel),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              theme.colorScheme.secondary,
                                          foregroundColor:
                                              theme.colorScheme.onSecondary,
                                          minimumSize:
                                              const Size(double.infinity, 48),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  /// Fetches projects ordered by 'priority' ascending.
  /// Shows all statuses so users can see active, planning, and completed projects.
  Future<List<Map<String, dynamic>>> _fetchProjects() async {
    final projects = await DonationService().getDonationProjects();
    if (projects.isNotEmpty) return projects;
    return _fallbackProjects;
  }

  Widget _buildFundUpdateSection(
      BuildContext context, Map<String, dynamic> project) {
    final theme = Theme.of(context);
    final title = (project['fund_update_title'] ?? '').toString().trim();
    final text = (project['fund_update_text'] ?? '').toString().trim();
    final imageUrls = _fundUpdateImages(project['fund_update_images']);

    if (title.isEmpty && text.isEmpty && imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.34 : 0.56,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title.isNotEmpty ? title : 'What your giving has done',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
              if (imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: imageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrls[index],
                          width: 112,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 112,
                            height: 88,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<String> _fundUpdateImages(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(10)
          .toList();
    }
    return value
        .toString()
        .split(RegExp(r'[\r\n,]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(10)
        .toList();
  }

  /// Formats a number with compact suffix
  String _formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return value.toStringAsFixed(0);
  }
}
