import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/text_formatter.dart';

import '../../providers/firebase_auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/guest_provider.dart';
import '../../constants/app_constants.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/admin_notification_service.dart';
import '../../utils/responsive_utils.dart';
import '../../models/app_models.dart';
import '../../utils/layout_fix_utils.dart';
import 'package:flutter/foundation.dart';

class FirebaseAuthScreen extends ConsumerStatefulWidget {
  const FirebaseAuthScreen({super.key});

  @override
  ConsumerState<FirebaseAuthScreen> createState() => _FirebaseAuthScreenState();
}

class _FirebaseAuthScreenState extends ConsumerState<FirebaseAuthScreen> {
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
  final _localChapterController = TextEditingController();
  final _conferenceController = TextEditingController();
  final _financialCommitmentController = TextEditingController();
  final _availabilityController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _isGoogleSigningIn = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _commitmentType = 'both';
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  final BiometricAuthService _biometricService = BiometricAuthService.instance;

  @override
  void initState() {
    super.initState();
    debugPrint('FirebaseAuthScreen init');
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
    _localChapterController.dispose();
    _conferenceController.dispose();
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
                  'Biometric authentication is not set up. Please sign in normally first.'),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric authentication failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('FirebaseAuthScreen build');
    final translate = ref.watch(translationProvider);
    final signInState = ref.watch(signInControllerProvider);

    // Listen to auth state changes
    ref.listen<AsyncValue<void>>(signInControllerProvider, (previous, next) {
      next.when(
        data: (_) {
          // Success - navigate to home
          if (mounted) {
            context.go('/');
          }
        },
        error: (error, _) {
          if (!mounted) return;
          // Show a user-facing message instead of raw exception text
          final rawError = error.toString();
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
          } else if (rawError.contains('network-request-failed') ||
              rawError.contains('network')) {
            displayMsg =
                'No internet connection. Please check your network and try again.';
          } else {
            // Strip Dart exception type prefix if present
            displayMsg = rawError
                .replaceAll('Exception: ', '')
                .replaceAll('AppException: ', '')
                .replaceAll('AuthException: ', '');
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
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
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
                      )),

                      // App Logo and Title
                      _buildHeader(context, translate),

                      SizedBox(
                          height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 32.0,
                        tablet: 40.0,
                        desktop: 48.0,
                      )),

                      // Auth Buttons Row (Sign In / Sign Up)
                      _buildAuthButtonsRow(context, translate),

                      SizedBox(
                          height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 24.0,
                        tablet: 32.0,
                        desktop: 40.0,
                      )),

                      // Auth Form
                      _buildAuthForm(context, translate, signInState),

                      SizedBox(
                          height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 16.0,
                        tablet: 20.0,
                        desktop: 24.0,
                      )),

                      // Forgot Password (smaller, only for sign in)
                      if (!_isSignUp)
                        _buildForgotPasswordButton(context, translate),

                      SizedBox(
                          height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 24.0,
                        tablet: 32.0,
                        desktop: 40.0,
                      )),

                      // Social Sign In Options
                      _buildSocialSignInOptions(
                          context, translate, signInState),

                      SizedBox(
                          height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 16.0,
                        tablet: 20.0,
                        desktop: 24.0,
                      )),

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
                      )),
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
        )),

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
        )),

        // Welcome Message
        Text(
          translate('welcome 🤗'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
                height: 1.4,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
          softWrap: true,
        ),
      ],
    );
  }

  Widget _buildAuthButtonsRow(
      BuildContext context, String Function(String) translate) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _handleDirectSignIn(),
            icon: Icon(
              Icons.login,
              size: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 20.0,
                tablet: 22.0,
                desktop: 24.0,
              ),
            ),
            label: Text(
              translate('sign_in'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
        SizedBox(
            width: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 12.0,
          tablet: 16.0,
          desktop: 20.0,
        )),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _handleDirectSignUp(),
            icon: Icon(
              Icons.person_add,
              size: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 20.0,
                tablet: 22.0,
                desktop: 24.0,
              ),
            ),
            label: Text(
              translate('sign_up'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm(BuildContext context, String Function(String) translate,
      AsyncValue<void> signInState) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Name field (only for sign up)
          if (_isSignUp) ...[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: translate('full_name'),
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              validator: (value) {
                if (_isSignUp && (value == null || value.trim().isEmpty)) {
                  return translate('name_required');
                }
                return null;
              },
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            )),
            _buildSignUpProfileFields(context),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            )),
          ],

          // Email field
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
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return translate('invalid_email');
              }
              return null;
            },
          ),

          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 16.0,
            tablet: 18.0,
            desktop: 20.0,
          )),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: translate('password'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off),
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
              if (_isSignUp && value.length < 6) {
                return translate('password_too_short');
              }
              return null;
            },
          ),

          // Confirm password field (only for sign up)
          if (_isSignUp) ...[
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            )),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: translate('confirm_password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              validator: (value) {
                if (_isSignUp && value != _passwordController.text) {
                  return translate('passwords_dont_match');
                }
                return null;
              },
            ),
          ],

          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 24.0,
            tablet: 28.0,
            desktop: 32.0,
          )),

          // Submit button removed - authentication now happens directly from sign-in/sign-up buttons
        ],
      ),
    );
  }

  Widget _buildForgotPasswordButton(
      BuildContext context, String Function(String) translate) {
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

  Widget _buildSignUpProfileFields(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: _signupDecoration(context, 'Phone Number', Icons.phone_outlined),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        TextFormField(
          controller: _locationController,
          decoration: _signupDecoration(context, 'Location', Icons.location_on_outlined),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        TextFormField(
          controller: _localChurchController,
          decoration: _signupDecoration(context, 'Local Church', Icons.church_outlined),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        TextFormField(
          controller: _occupationController,
          decoration: _signupDecoration(context, 'Occupation', Icons.work_outline),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        TextFormField(
          controller: _skillsController,
          decoration: _signupDecoration(context, 'Skills', Icons.handyman_outlined),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        TextFormField(
          controller: _localChapterController,
          decoration: _signupDecoration(context, 'Local Chapter', Icons.groups_outlined),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        TextFormField(
          controller: _conferenceController,
          decoration: _signupDecoration(context, 'Conference', Icons.event_outlined),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        DropdownButtonFormField<String>(
          initialValue: _commitmentType,
          decoration: _signupDecoration(context, 'Commitment Type', Icons.volunteer_activism_outlined),
          items: [
            DropdownMenuItem(value: 'financial', child: Text('Financial', style: Theme.of(context).textTheme.bodyMedium)),
            DropdownMenuItem(value: 'active_availability', child: Text('Active Availability', style: Theme.of(context).textTheme.bodyMedium)),
            DropdownMenuItem(value: 'both', child: Text('Both', style: Theme.of(context).textTheme.bodyMedium)),
          ],
          onChanged: (value) => setState(() => _commitmentType = value ?? 'both'),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        if (_commitmentType == 'financial' || _commitmentType == 'both') ...[
          TextFormField(
            controller: _financialCommitmentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _signupDecoration(
                context, 'Financial Commitment (Optional)', Icons.payments_outlined),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        ],
        if (_commitmentType == 'active_availability' || _commitmentType == 'both')
          TextFormField(
            controller: _availabilityController,
            decoration: _signupDecoration(
                context, 'Availability Commitment (Optional)', Icons.schedule_outlined),
          ),
      ],
    );
  }

  InputDecoration _signupDecoration(
      BuildContext context, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildSocialSignInOptions(BuildContext context,
      String Function(String) translate, AsyncValue<void> signInState) {
    return Column(
      children: [
        // Divider with "OR" text
        Row(
          children: [
            Expanded(
                child: Divider(color: Theme.of(context).colorScheme.outline)),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16.0,
                tablet: 20.0,
                desktop: 24.0,
              )),
              child: LayoutFixUtils.safeText(
                translate('or'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
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
                child: Divider(color: Theme.of(context).colorScheme.outline)),
          ],
        ),

        SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 20.0,
          tablet: 24.0,
          desktop: 28.0,
        )),

        // Google Sign In Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: signInState.isLoading ? null : _handleGoogleSignIn,
            icon: SvgPicture.asset(
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
              TextFormatter.formatAction(translate('continue_with_google')),
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
      BuildContext context, String Function(String) translate) {
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

  Widget _buildGuestAccessButton(BuildContext context,
      String Function(String) translate, AsyncValue<void> signInState) {
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSignUp = false;
      _isLoading = true;
    });

    try {
      await ref
          .read(signInControllerProvider.notifier)
          .signInWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );

      // After successful sign-in, offer biometric setup if available and not already enabled
      if (_isBiometricAvailable && !_isBiometricEnabled) {
        _showBiometricSetupDialog();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDirectSignUp() async {
    setState(() {
      _isSignUp = true;
    });

    if (!_formKey.currentState!.validate()) return;

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
            profileData: {
              if (_phoneController.text.trim().isNotEmpty)
                'phone_number': _phoneController.text.trim(),
              if (_locationController.text.trim().isNotEmpty)
                'location': _locationController.text.trim(),
              if (_localChurchController.text.trim().isNotEmpty)
                'local_church': _localChurchController.text.trim(),
              if (_occupationController.text.trim().isNotEmpty)
                'occupation': _occupationController.text.trim(),
              if (_skillsController.text.trim().isNotEmpty)
                'skills': _skillsController.text.trim(),
              if (_localChapterController.text.trim().isNotEmpty)
                'local_chapter': _localChapterController.text.trim(),
              if (_conferenceController.text.trim().isNotEmpty)
                'conference': _conferenceController.text.trim(),
              'commitment_type': _commitmentType,
              if ((_commitmentType == 'financial' || _commitmentType == 'both') &&
                  _financialCommitmentController.text.trim().isNotEmpty)
                'financial_commitment':
                    double.tryParse(_financialCommitmentController.text.trim()),
              if ((_commitmentType == 'active_availability' ||
                      _commitmentType == 'both') &&
                  _availabilityController.text.trim().isNotEmpty)
                'availability_commitment':
                    _availabilityController.text.trim(),
              'is_approved': false,
              'approval_status': 'pending',
            },
          );

    // Notify admin of new signup (best-effort, don't block UI)
    try {
      await AdminNotificationService.instance.notifyAdminOfNewSignup(
        UserProfile(
          id: '',
          email: _emailController.text.trim(),
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          localChurch: _localChurchController.text.trim(),
          commitmentType: _commitmentType,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Best-effort notification — don't fail signup
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
      BuildContext context, String Function(String) translate) {
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
              if (emailController.text.trim().isNotEmpty) {
                Navigator.of(dialogCtx).pop();
                await ref.read(signInControllerProvider.notifier).resetPassword(
                      emailController.text.trim(),
                    );
                if (rootCtx.mounted) {
                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                    SnackBar(
                      content: Text(translate('reset_email_sent')),
                    ),
                  );
                }
              }
            },
            child: Text(translate('send')),
          ),
        ],
      ),
    );
  }

  void _showBiometricSetupDialog() {
    final translate = ref.read(translationProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translate('enable_biometric_auth')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fingerprint,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(translate('biometric_setup_message')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(translate('skip')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _setupBiometricAuth();
            },
            child: Text(translate('enable')),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${translate('biometric_setup_error')}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
