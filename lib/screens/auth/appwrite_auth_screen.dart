import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/text_formatter.dart';

import '../../providers/appwrite_auth_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/guest_provider.dart';
import '../../constants/app_constants.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/admin_notification_service.dart';
import '../../utils/responsive_utils.dart';
import '../../models/app_models.dart';
import '../../models/auth_models.dart';
import '../../utils/layout_fix_utils.dart';
import 'package:flutter/foundation.dart';

class AppwriteAuthScreen extends ConsumerStatefulWidget {
  const AppwriteAuthScreen({super.key});

  @override
  ConsumerState<AppwriteAuthScreen> createState() => _AppwriteAuthScreenState();
}

class _AppwriteAuthScreenState extends ConsumerState<AppwriteAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _localChurchController = TextEditingController();
  final _occupationController = TextEditingController();
  final _skillsController = TextEditingController();
  final _previouslocalChapterController = TextEditingController();
  final _tojoinChapterController = TextEditingController();
  final _financialCommitmentController = TextEditingController();
  final _availabilityController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _isGoogleSigningIn = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _commitmentType = 'both';
  String _selectedCategory = 'member'; // 'member', 'coordinator', 'guest'
  String _coordinatorRole = 'coordinator'; // 'coordinator', 'leader'
  int _currentStage = 0;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  /// Tracks whether the current sign-in flow was email/password (vs Google/guest)
  /// so the biometric setup prompt only triggers for email/password logins.
  bool _isEmailPasswordSignIn = false;
  static const String _biometricDismissedKey = 'biometric_setup_dismissed';
  final BiometricAuthService _biometricService = BiometricAuthService.instance;

  @override
  void initState() {
    super.initState();
    debugPrint('AppwriteAuthScreen init');
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _localChurchController.dispose();
    _occupationController.dispose();
    _skillsController.dispose();
    _previouslocalChapterController.dispose();
    _tojoinChapterController.dispose();
    _financialCommitmentController.dispose();
    _availabilityController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      if (kIsWeb) {
        if (mounted) {
          setState(() {
            _isBiometricAvailable = false;
            _isBiometricEnabled = false;
          });
        }
        return;
      }
      final isAvailable = await _biometricService.isBiometricAvailable();
      final isEnabled = await _biometricService.isBiometricEnabled();

      if (mounted) {
        setState(() {
          _isBiometricAvailable = isAvailable;
          _isBiometricEnabled = isEnabled;
        });
      }
    } catch (e) {
      // Biometric not available
      if (mounted) {
        setState(() {
          _isBiometricAvailable = false;
          _isBiometricEnabled = false;
        });
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      // Check if biometric is enabled for any user
      if (!_isBiometricEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Biometric authentication is not set up. Please sign in normally first.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      // Authenticate with biometrics and get stored credentials
      final credentials = await _biometricService.authenticateWithBiometrics();

      if (credentials != null) {
        // Sign in with the retrieved credentials
        final authProvider = ref.read(signInControllerProvider.notifier);
        await authProvider.signInWithEmailAndPassword(
          credentials['email']!,
          credentials['password']!,
        );

        // Navigate to home on successful authentication
        if (mounted) {
          context.go('/home');
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Biometric authentication was not successful. Please sign in with your email and password.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('AppwriteAuthScreen build');
    final translate = ref.watch(translationProvider);
    final signInState = ref.watch(signInControllerProvider);

    // Listen to auth state changes
    ref.listen<AsyncValue<void>>(signInControllerProvider, (previous, next) {
      next.when(
        data: (_) {
          // Success - offer biometric setup at the ideal, non-intrusive time:
          // after a successful email/password sign-in, before navigating home.
          if (mounted) {
            ref.read(isGuestModeProvider.notifier).state = false;
            if (_isEmailPasswordSignIn &&
                _isBiometricAvailable &&
                !_isBiometricEnabled) {
              _isEmailPasswordSignIn = false;
              _maybeOfferBiometricSetup();
            } else {
              context.go('/');
            }
          }
        },
        error: (error, _) {
          _isEmailPasswordSignIn = false;
          if (!mounted) return;
          // Show a user-facing message instead of raw exception text
          final rawError = error.toString().toLowerCase();
          String displayMsg;
          if (rawError.contains('popup-blocked') ||
              rawError.contains('popup_blocked_by_browser')) {
            displayMsg =
                'Google Sign-In popup was blocked. Please allow popups for this site in your browser settings, then try again.';
          } else if (rawError.contains('unauthorized_client') ||
              rawError.contains('unauthorized-domain') ||
              rawError.contains('auth/unauthorized')) {
            displayMsg =
                'This domain is not authorized for Google Sign-In. Please contact the app admin.';
          } else if (rawError.contains('rate_limit_exceeded') ||
              rawError.contains('rate limit') ||
              rawError.contains('429')) {
            displayMsg =
                'Too many attempts. Rate limit reached — please wait a few minutes before trying again.';
          } else if (rawError.contains('user_already_exists') ||
              rawError.contains('user already exists') ||
              rawError.contains('409')) {
            displayMsg =
                'An account with this email already exists. Please switch to Sign In.';
          } else if (rawError.contains('invalid_credentials') ||
              rawError.contains('user_invalid_credentials') ||
              rawError.contains('invalid credentials')) {
            displayMsg =
                'Incorrect email or password. Please check your credentials and try again.';
          } else if (rawError.contains('smtp') ||
              rawError.contains('failed to send email')) {
            displayMsg =
                'Email server connection issue. Please try again later or contact app@alivenigeria.org.';
          } else if (rawError.contains('network-request-failed') ||
              rawError.contains('network')) {
            displayMsg =
                'No internet connection. Please check your network and try again.';
          } else {
            // Strip Dart exception type prefix if present
            displayMsg = error
                .toString()
                .replaceAll('Exception: ', '')
                .replaceAll('AppException: ', '')
                .replaceAll('AuthException: ', '')
                .replaceAll('AppwriteException: ', '');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(displayMsg),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 6),
            ),
          );
        },
        loading: () {},
      );
    });

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: context.responsivePadding,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 20.0,
                          tablet: 30.0,
                          desktop: 40.0,
                        ),
                      ),

                      // App Logo and Title
                      _buildHeader(context, translate),

                      SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 32.0,
                          tablet: 40.0,
                          desktop: 48.0,
                        ),
                      ),

                      // Auth Form (Inputs + Submit Button immediately below!)
                      _buildAuthForm(context, translate, signInState),

                      SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 24.0,
                          tablet: 32.0,
                          desktop: 40.0,
                        ),
                      ),

                      // Social Sign In Options
                      _buildSocialSignInOptions(
                        context,
                        translate,
                        signInState,
                      ),

                      SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 16.0,
                          tablet: 20.0,
                          desktop: 24.0,
                        ),
                      ),

                      // Biometric Authentication (if available and enabled)
                      if (_isBiometricAvailable && _isBiometricEnabled)
                        _buildBiometricButton(context, translate),

                      const Spacer(),

                      // Guest Access
                      _buildGuestAccessButton(context, translate, signInState),

                      SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 16.0,
                          tablet: 20.0,
                          desktop: 24.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String Function(String) translate) {
    return Column(
      children: [
        // Logo - simplified design like the old auth screen
        SvgPicture.asset(
          'assets/images/alive_logo.svg',
          width: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 80.0,
            tablet: 90.0,
            desktop: 100.0,
          ),
          height: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 80.0,
            tablet: 90.0,
            desktop: 100.0,
          ),
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.primary,
            BlendMode.srcIn,
          ),
        ),

        SizedBox(
          height: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 16.0,
            tablet: 18.0,
            desktop: 20.0,
          ),
        ),

        // App Name
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 28.0,
                  tablet: 32.0,
                  desktop: 36.0,
                ),
              ),
        ),

        SizedBox(
          height: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 8.0,
            tablet: 10.0,
            desktop: 12.0,
          ),
        ),

        // Welcome Message
        Text(
          translate('welcome'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
                height: 1.4,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
          softWrap: true,
        ),
      ],
    );
  }

  Widget _buildModeTogglePrompt(
    BuildContext context,
    String Function(String) translate,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isSignUp
                ? 'Already have an account? '
                : 'Don\'t have an account? ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          GestureDetector(
            onTap: _isLoading
                ? null
                : () => setState(() {
                    _isSignUp = !_isSignUp;
                    _currentStage = 0;
                  }),
            child: Text(
              _isSignUp ? translate('sign_in') : translate('sign_up'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int get _totalStages => _selectedCategory == 'guest' ? 2 : 3;

  Widget _buildAuthForm(
    BuildContext context,
    String Function(String) translate,
    AsyncValue<void> signInState,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isSignUp) ...[
            // ── SIGN IN MODE ──
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: translate('email'),
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return translate('email_required');
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return translate('invalid_email');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: translate('password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return translate('password_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            _buildForgotPasswordButton(context, translate),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading || signInState.isLoading
                  ? null
                  : _handleDirectSignIn,
              icon: _isLoading || signInState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login),
              label: Text(
                _isLoading || signInState.isLoading
                    ? 'Please wait...'
                    : translate('sign_in'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ] else ...[
            // ── SIGN UP MODE (CATEGORIZED & STAGED) ──
            _buildCategorySelector(context),
            const SizedBox(height: 18),
            _buildStageIndicator(context),
            const SizedBox(height: 18),

            if (_currentStage == 0)
              _buildStageZeroFields(context, translate)
            else if (_currentStage == 1)
              _buildStageOneFields(context, translate)
            else
              _buildStageTwoFields(context, translate),

            const SizedBox(height: 22),
            _buildStageNavigationButtons(context, translate, signInState),
          ],

          _buildModeTogglePrompt(context, translate),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = [
      {
        'id': 'member',
        'title': 'Member',
        'subtitle': 'ALIVE Member',
        'icon': Icons.person_outline,
      },
      {
        'id': 'coordinator',
        'title': 'Staff/Coord',
        'subtitle': 'Staff / Leader',
        'icon': Icons.badge_outlined,
      },
      {
        'id': 'guest',
        'title': 'Non-Member',
        'subtitle': 'Guest Access',
        'icon': Icons.explore_outlined,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registration Category',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat['id'];
            return Expanded(
              child: GestureDetector(
                onTap: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _selectedCategory = cat['id'] as String;
                          if (_currentStage >= _totalStages) {
                            _currentStage = _totalStages - 1;
                          }
                        });
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.2),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 22,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cat['title'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        cat['subtitle'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.8)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStageIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final stages = _selectedCategory == 'guest'
        ? ['Credentials', 'Profile & Welcome']
        : ['Credentials', 'Church & Details', 'Commitment'];

    return Column(
      children: [
        Row(
          children: List.generate(stages.length * 2 - 1, (index) {
            if (index.isOdd) {
              final stepBefore = index ~/ 2;
              final isDone = _currentStage > stepBefore;
              return Expanded(
                child: Container(
                  height: 2,
                  color: isDone
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              );
            }
            final stepIndex = index ~/ 2;
            final isActive = _currentStage == stepIndex;
            final isPassed = _currentStage > stepIndex;

            return Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPassed
                    ? theme.colorScheme.primary
                    : isActive
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: isActive || isPassed
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: isPassed
                    ? Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: stages.asMap().entries.map((entry) {
            final idx = entry.key;
            final title = entry.value;
            final isActive = _currentStage == idx;
            return Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStageZeroFields(BuildContext context, String Function(String) translate) {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: _signupDecoration(context, translate('full_name'), Icons.person_outline),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return translate('name_required');
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _signupDecoration(context, translate('email'), Icons.email_outlined),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return translate('email_required');
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return translate('invalid_email');
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: _signupDecoration(
            context,
            _selectedCategory == 'guest' ? 'Phone Number (Optional)' : 'Phone Number *',
            Icons.phone_outlined,
          ),
          validator: (value) {
            if (_selectedCategory != 'guest' && (value == null || value.trim().isEmpty)) {
              return 'Phone number is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _locationController,
          decoration: _signupDecoration(context, 'Location (City / State)', Icons.location_on_outlined),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: translate('password'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return translate('password_required');
            }
            if (value.length < 6) {
              return translate('password_too_short');
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: translate('confirm_password'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          validator: (value) {
            if (value != _passwordController.text) {
              return translate('passwords_dont_match');
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStageOneFields(BuildContext context, String Function(String) translate) {
    final theme = Theme.of(context);

    if (_selectedCategory == 'guest') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Welcome to ALIVE Nigeria! As a guest, you will have access to daily verses, Bible study, health lessons, library, podcasts, testimonies, and books.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _localChurchController,
            decoration: _signupDecoration(context, 'Local Church (Optional)', Icons.church_outlined),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _occupationController,
            decoration: _signupDecoration(context, 'Occupation / Interest (Optional)', Icons.work_outline),
          ),
        ],
      );
    }

    // Member & Staff Stage 1
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedCategory == 'coordinator') ...[
          DropdownButtonFormField<String>(
            initialValue: _coordinatorRole,
            decoration: _signupDecoration(context, 'Staff / Coordinator Role', Icons.admin_panel_settings_outlined),
            items: const [
              DropdownMenuItem(value: 'coordinator', child: Text('Chapter Coordinator')),
              DropdownMenuItem(value: 'leader', child: Text('Ministry Staff / Leader')),
            ],
            onChanged: (val) => setState(() => _coordinatorRole = val ?? 'coordinator'),
          ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: _localChurchController,
          decoration: _signupDecoration(context, 'Local Church *', Icons.church_outlined),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Local church name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _tojoinChapterController,
          decoration: _signupDecoration(
            context,
            'To Join Chapter (Optional)',
            Icons.group_add_outlined,
            helperText: 'Optional: Leave empty if you serve generally or across chapters',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _previouslocalChapterController,
          decoration: _signupDecoration(context, 'Previous Local Chapter (Optional)', Icons.groups_outlined),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _occupationController,
          decoration: _signupDecoration(context, 'Occupation (Optional)', Icons.work_outline),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _skillsController,
          decoration: _signupDecoration(context, 'Skills / Ministry Gifts (Optional)', Icons.handyman_outlined),
        ),
      ],
    );
  }

  Widget _buildStageTwoFields(BuildContext context, String Function(String) translate) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Commitment to ALIVE Mission',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select how you would like to actively support ALIVE Nigeria ministry.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _commitmentType,
          decoration: _signupDecoration(context, 'Commitment Type', Icons.volunteer_activism_outlined),
          items: const [
            DropdownMenuItem(value: 'both', child: Text('Both Financial & Active Availability')),
            DropdownMenuItem(value: 'financial', child: Text('Financial Commitment')),
            DropdownMenuItem(value: 'active_availability', child: Text('Active Availability Commitment')),
          ],
          onChanged: (value) => setState(() => _commitmentType = value ?? 'both'),
        ),
        const SizedBox(height: 14),
        if (_commitmentType == 'financial' || _commitmentType == 'both') ...[
          TextFormField(
            controller: _financialCommitmentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _signupDecoration(
              context,
              'Monthly Financial Commitment (NGN or USD)',
              Icons.payments_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your monthly financial commitment';
              }
              if (double.tryParse(value.trim()) == null) {
                return 'Please enter a valid amount';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
        ],
        if (_commitmentType == 'active_availability' || _commitmentType == 'both') ...[
          TextFormField(
            controller: _availabilityController,
            decoration: _signupDecoration(
              context,
              'Availability Commitment (hours or ministry areas)',
              Icons.schedule_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please specify your ministry availability';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
        ],
        if (_selectedCategory == 'coordinator') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, color: Colors.amber.shade800, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Administrative Approval: Staff and Coordinator registrations will go through review before coordinator privileges are unlocked. You can access member features immediately.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: theme.colorScheme.onSurface,
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

  Widget _buildStageNavigationButtons(
    BuildContext context,
    String Function(String) translate,
    AsyncValue<void> signInState,
  ) {
    final isLastStage = _currentStage == _totalStages - 1;

    return Row(
      children: [
        if (_currentStage > 0) ...[
          Expanded(
            flex: 1,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : () => setState(() => _currentStage--),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isLoading || signInState.isLoading
                ? null
                : () {
                    if (isLastStage) {
                      _handleDirectSignUp();
                    } else {
                      _advanceStage(translate);
                    }
                  },
            icon: _isLoading || signInState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(isLastStage ? Icons.check_circle_outline : Icons.arrow_forward),
            label: Text(
              _isLoading || signInState.isLoading
                  ? 'Please wait...'
                  : (isLastStage
                      ? (_selectedCategory == 'guest'
                          ? 'Create Guest Account'
                          : 'Complete Registration')
                      : 'Continue'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  void _advanceStage(String Function(String) translate) {
    if (_currentStage == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showFormError(translate('name_required'));
        return;
      }
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        _showFormError(translate('email_required'));
        return;
      }
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _showFormError(translate('invalid_email'));
        return;
      }
      if (_selectedCategory != 'guest' && _phoneController.text.trim().isEmpty) {
        _showFormError('Phone number is required');
        return;
      }
      if (_passwordController.text.length < 6) {
        _showFormError(translate('password_too_short'));
        return;
      }
      if (_confirmPasswordController.text != _passwordController.text) {
        _showFormError(translate('passwords_dont_match'));
        return;
      }
      setState(() => _currentStage = 1);
    } else if (_currentStage == 1) {
      if (_selectedCategory != 'guest' && _localChurchController.text.trim().isEmpty) {
        _showFormError('Local church name is required');
        return;
      }
      setState(() => _currentStage = 2);
    }
  }

  void _showFormError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildForgotPasswordButton(
    BuildContext context,
    String Function(String) translate,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          _showForgotPasswordDialog(context, translate);
        },
        child: Text(
          translate('forgot_password'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 14.0,
              tablet: 16.0,
              desktop: 18.0,
            ),
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  InputDecoration _signupDecoration(
    BuildContext context,
    String label,
    IconData icon, {
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildSocialSignInOptions(
    BuildContext context,
    String Function(String) translate,
    AsyncValue<void> signInState,
  ) {
    return Column(
      children: [
        // Divider with "OR" text
        Row(
          children: [
            Expanded(
              child: Divider(color: Theme.of(context).colorScheme.outline),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
              ),
              child: LayoutFixUtils.safeText(
                translate('or'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 14.0,
                        tablet: 16.0,
                        desktop: 18.0,
                      ),
                    ),
              ),
            ),
            Expanded(
              child: Divider(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),

        SizedBox(
          height: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 20.0,
            tablet: 24.0,
            desktop: 28.0,
          ),
        ),

        // Google Sign In Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isGoogleSigningIn || signInState.isLoading ? null : _handleGoogleSignIn,
            icon: _isGoogleSigningIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : SvgPicture.asset(
                    'assets/images/google_logo.svg',
                    width: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 20.0,
                      tablet: 22.0,
                      desktop: 24.0,
                    ),
                    height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 20.0,
                      tablet: 22.0,
                      desktop: 24.0,
                    ),
                  ),
            label: Text(
              _isGoogleSigningIn
                  ? 'Signing in...'
                  : TextFormatter.formatAction(translate('continue_with_google')),
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
              ),
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricButton(
    BuildContext context,
    String Function(String) translate,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(
        top: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 16.0,
          tablet: 20.0,
          desktop: 24.0,
        ),
      ),
      child: OutlinedButton.icon(
        onPressed: _authenticateWithBiometrics,
        icon: Icon(
          Icons.fingerprint,
          size: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 24.0,
            tablet: 26.0,
            desktop: 28.0,
          ),
        ),
        label: Text(
          translate('use_biometric_auth'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            ),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            ),
          ),
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
          foregroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildGuestAccessButton(
    BuildContext context,
    String Function(String) translate,
    AsyncValue<void> signInState,
  ) {
    return TextButton(
      onPressed: signInState.isLoading ? null : _handleGuestAccess,
      child: Text(
        TextFormatter.formatAction(translate('continue_as_guest')),
        style: TextStyle(
          fontSize: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 14.0,
            tablet: 16.0,
            desktop: 18.0,
          ),
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _handleDirectSignIn() async {
    if (_isSignUp) {
      setState(() {
        _isSignUp = false;
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isEmailPasswordSignIn = true;
    });

    try {
      await ref
          .read(signInControllerProvider.notifier)
          .signInWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDirectSignUp() async {
    if (!_isSignUp) {
      setState(() {
        _isSignUp = true;
        _currentStage = 0;
      });
      return;
    }

    final category = _selectedCategory;
    final translate = ref.read(translationProvider);

    // Validate Stage 0 credentials
    if (_nameController.text.trim().isEmpty) {
      setState(() => _currentStage = 0);
      _showFormError(translate('name_required'));
      return;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _currentStage = 0);
      _showFormError(translate('email_required'));
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _currentStage = 0);
      _showFormError(translate('invalid_email'));
      return;
    }
    if (category != 'guest' && _phoneController.text.trim().isEmpty) {
      setState(() => _currentStage = 0);
      _showFormError('Phone number is required');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _currentStage = 0);
      _showFormError(translate('password_too_short'));
      return;
    }
    if (_confirmPasswordController.text != _passwordController.text) {
      setState(() => _currentStage = 0);
      _showFormError(translate('passwords_dont_match'));
      return;
    }

    // Validate Stage 1 credentials
    if (category != 'guest' && _localChurchController.text.trim().isEmpty) {
      setState(() => _currentStage = 1);
      _showFormError('Local church name is required');
      return;
    }

    // Validate Stage 2 credentials for Member/Staff
    if (category != 'guest') {
      if ((_commitmentType == 'financial' || _commitmentType == 'both') &&
          _financialCommitmentController.text.trim().isEmpty) {
        setState(() => _currentStage = 2);
        _showFormError('Please enter your monthly financial commitment');
        return;
      }
      if ((_commitmentType == 'active_availability' || _commitmentType == 'both') &&
          _availabilityController.text.trim().isEmpty) {
        setState(() => _currentStage = 2);
        _showFormError('Please specify your ministry availability');
        return;
      }
    }

    String role;
    String? requestedRole;
    bool isApproved;
    String approvalStatus;

    if (category == 'guest') {
      role = 'guest';
      isApproved = true;
      approvalStatus = 'approved';
    } else if (category == 'coordinator') {
      role = _coordinatorRole;
      requestedRole = _coordinatorRole;
      isApproved = false; // Requires administrator review and approval!
      approvalStatus = 'pending';
    } else {
      role = 'member';
      isApproved = true;
      approvalStatus = 'approved';
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref
          .read(signInControllerProvider.notifier)
          .signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
        profile: SignupProfile(
          phoneNumber: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          location: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          localChurch: _localChurchController.text.trim().isNotEmpty
              ? _localChurchController.text.trim()
              : null,
          occupation: _occupationController.text.trim().isNotEmpty
              ? _occupationController.text.trim()
              : null,
          skills: _skillsController.text.trim().isNotEmpty
              ? _skillsController.text.trim()
              : null,
          previouslocalChapter: _previouslocalChapterController.text.trim().isNotEmpty
              ? _previouslocalChapterController.text.trim()
              : null,
          tojoinChapter: _tojoinChapterController.text.trim().isNotEmpty
              ? _tojoinChapterController.text.trim()
              : null,
          commitmentType: category == 'guest' ? 'none' : _commitmentType,
          financialCommitment: (category != 'guest' &&
                  (_commitmentType == 'financial' || _commitmentType == 'both') &&
                  _financialCommitmentController.text.trim().isNotEmpty)
              ? double.tryParse(_financialCommitmentController.text.trim())
              : null,
          availabilityCommitment: (category != 'guest' &&
                  (_commitmentType == 'active_availability' || _commitmentType == 'both') &&
                  _availabilityController.text.trim().isNotEmpty)
              ? _availabilityController.text.trim()
              : null,
          role: role,
          requestedRole: requestedRole,
          isApproved: isApproved,
          approvalStatus: approvalStatus,
        ),
      );

      // Notify admin of new signup (best-effort)
      try {
        final currentUid =
            ref.read(authGatewayProvider).currentUser?.uid ?? '';
        final newProfile = UserProfile(
          id: currentUid,
          email: _emailController.text.trim(),
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          localChurch: _localChurchController.text.trim(),
          commitmentType: category == 'guest' ? 'none' : _commitmentType,
          role: role,
          requestedRole: requestedRole,
          isApproved: isApproved,
          approvalStatus: approvalStatus,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await AdminNotificationService.instance
            .notifyAdminOfNewSignup(newProfile);
      } catch (_) {
        // Best-effort — don't fail signup
      }

      // Show customized in-app welcome SnackBar
      if (mounted) {
        final name = _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : _emailController.text.split('@').first;
        String welcomeMsg;
        if (category == 'coordinator') {
          welcomeMsg = 'Welcome to ALIVE Nigeria, $name! Your ${requestedRole == 'leader' ? 'Staff' : 'Coordinator'} registration has been submitted for admin approval.';
        } else if (category == 'guest') {
          welcomeMsg = 'Welcome to ALIVE Nigeria, $name! You now have access to the ALIVE guest area.';
        } else {
          welcomeMsg = 'Welcome to ALIVE Nigeria, $name! 🎉';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(welcomeMsg),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // Prevent multiple concurrent sign-in requests
    if (_isGoogleSigningIn) return;
    setState(() => _isGoogleSigningIn = true);
    try {
      await ref.read(signInControllerProvider.notifier).signInWithGoogle();

      // Post sign-in routing is handled centrally by the router's redirect
      // guard (`routerProvider`), which covers every auth provider and sends
      // first-time users to the profile setup flow.
      if (!mounted) return;
      final user = ref.read(appwriteUserStreamProvider).value;
      if (user != null) {
        if (!mounted) return;
        // Show welcome back message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${user.displayName ?? user.email.split("@").first}! 👋'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleSigningIn = false);
    }
  }

  Future<void> _handleGuestAccess() async {
    // Enable guest mode instead of anonymous sign-in
    ref.read(isGuestModeProvider.notifier).state = true;
    if (mounted) {
      context.go('/home');
    }
  }

  void _showForgotPasswordDialog(
    BuildContext context,
    String Function(String) translate,
  ) {
    final emailController = TextEditingController();
    final rootCtx = context;

    showDialog(
      context: rootCtx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(translate('reset_password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(translate('reset_password_message')),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: translate('email'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  SnackBar(
                    content: Text(translate('invalid_email')),
                    backgroundColor: Theme.of(dialogCtx).colorScheme.error,
                  ),
                );
                return;
              }
              Navigator.of(dialogCtx).pop();
              try {
                await ref
                    .read(signInControllerProvider.notifier)
                    .resetPassword(email);
              } catch (_) {
                // Keep neutral response to prevent user enumeration
              }
              if (rootCtx.mounted) {
                ScaffoldMessenger.of(rootCtx).showSnackBar(
                  SnackBar(content: Text(translate('reset_email_sent'))),
                );
              }
            },
            child: Text(translate('send')),
          ),
        ],
      ),
    );
  }

  /// Checks user preference and shows biometric setup dialog if not dismissed.
  Future<void> _maybeOfferBiometricSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_biometricDismissedKey) ?? false;
      if (dismissed) {
        // User previously chose "Don't ask again" — go straight home.
        if (mounted) context.go('/');
        return;
      }
    } catch (_) {
      // If prefs fail, just navigate.
      if (mounted) context.go('/');
      return;
    }
    if (!mounted) return;
    _showBiometricSetupDialog();
  }

  void _showBiometricSetupDialog() {
    final translate = ref.read(translationProvider);
    final rootContext = context;

    showDialog(
      context: rootContext,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.fingerprint, color: Theme.of(dialogCtx).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(translate('enable_biometric_auth'))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(dialogCtx).colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fingerprint,
                size: 56,
                color: Theme.of(dialogCtx).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              translate('biometric_setup_message'),
              textAlign: TextAlign.center,
              style: Theme.of(dialogCtx).textTheme.bodyMedium?.copyWith(
                color: Theme.of(dialogCtx).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          // "Don't ask again" — persists preference
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(_biometricDismissedKey, true);
              } catch (_) {}
              if (rootContext.mounted) rootContext.go('/');
            },
            child: Text(
              translate('dont_ask_again'),
              style: TextStyle(
                color: Theme.of(dialogCtx).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  if (rootContext.mounted) rootContext.go('/');
                },
                child: Text(translate('skip')),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.fingerprint, size: 18),
                onPressed: () async {
                  Navigator.of(dialogCtx).pop();
                  await _setupBiometricAuth();
                  if (rootContext.mounted) rootContext.go('/');
                },
                label: Text(translate('enable')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(dialogCtx).colorScheme.primary,
                  foregroundColor: Theme.of(dialogCtx).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setupBiometricAuth() async {
    final translate = ref.read(translationProvider);

    try {
      final success = await _biometricService.enableBiometricAuth(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _isBiometricEnabled = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(translate('biometric_enabled_success')),
              backgroundColor: Theme.of(context).colorScheme.tertiary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(translate('biometric_setup_failed')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translate('biometric_setup_failed')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
