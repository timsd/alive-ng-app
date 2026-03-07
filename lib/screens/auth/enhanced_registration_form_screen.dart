import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_database_service.dart';
import '../../services/admin_notification_service.dart';
import '../../utils/layout_fix_utils.dart';
import '../../utils/responsive_utils.dart';

class EnhancedRegistrationFormScreen extends StatefulWidget {
  const EnhancedRegistrationFormScreen({super.key});

  @override
  State<EnhancedRegistrationFormScreen> createState() =>
      _EnhancedRegistrationFormScreenState();
}

class _EnhancedRegistrationFormScreenState
    extends State<EnhancedRegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Basic info controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  // Enhanced profile controllers
  final _locationController = TextEditingController();
  final _localChurchController = TextEditingController();
  final _occupationController = TextEditingController();
  final _skillsController = TextEditingController();
  final _workContactController = TextEditingController();
  final _homeContactController = TextEditingController();
  final _generalInfoController = TextEditingController();

  // Commitment controllers
  final _localChapterController = TextEditingController();
  final _conferenceController = TextEditingController();

  String _commitmentType = 'both';
  bool _isLoading = false;
  int _currentPage = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _localChurchController.dispose();
    _occupationController.dispose();
    _skillsController.dispose();
    _workContactController.dispose();
    _homeContactController.dispose();
    _generalInfoController.dispose();
    _localChapterController.dispose();
    _conferenceController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create user account with Firebase
      final authResult =
          await FirebaseAuthService.instance.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
      );

      if (authResult.isSuccess && authResult.user != null) {
        // Create enhanced user profile
        final userProfile = UserProfile(
          id: authResult.user!.uid,
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          phoneNumber: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,

          // Enhanced profile fields
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
          workContact: _workContactController.text.trim().isNotEmpty
              ? _workContactController.text.trim()
              : null,
          homeContact: _homeContactController.text.trim().isNotEmpty
              ? _homeContactController.text.trim()
              : null,
          generalInfo: _generalInfoController.text.trim().isNotEmpty
              ? _generalInfoController.text.trim()
              : null,

          // Verification fields
          localChapter: _localChapterController.text.trim().isNotEmpty
              ? _localChapterController.text.trim()
              : null,
          conference: _conferenceController.text.trim().isNotEmpty
              ? _conferenceController.text.trim()
              : null,

          // Commitment tracking
          commitmentType: _commitmentType,

          // Admin approval fields (defaults)
          isApproved: false,
          approvalStatus: 'pending',

          // User statistics start date (when they register)
          statsStartDate: DateTime.now(),

          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Save user profile to database
        await FirebaseDatabaseService.instance.createUserProfile(userProfile);

        // Send admin notification for new user registration
        try {
          await AdminNotificationService.instance
              .notifyAdminOfNewSignup(userProfile);
        } catch (e) {
          // Log error but don't fail registration
          debugPrint('Failed to send admin notification: $e');
        }

        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        throw Exception(authResult.error ?? 'Registration failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registration Submitted'),
        content: LayoutFixUtils.safeColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: ResponsiveUtils.getResponsiveIconSize(context, 64),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
            LayoutFixUtils.safeText(
              'Your registration has been submitted successfully!\n\n'
              'An administrator will review your application and approve your access to the platform.\n\n'
              'Please note: This platform is for active engagement in your local chapter or community. '
              'We encourage you to be available and support financially or through service as the Lord blesses you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to auth screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: LayoutFixUtils.safeColumn(
          children: [
            // Progress indicator
            Container(
              padding:
                  ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / 3,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),

            // Page indicator
            Container(
              padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 8),
              child: Text(
                'Step ${_currentPage + 1} of 3',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
                  color: Colors.grey.shade600,
                ),
              ),
            ),

            // Page content
            LayoutFixUtils.expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildBasicInfoPage(),
                  _buildProfileDetailsPage(),
                  _buildCommitmentPage(),
                ],
              ),
            ),

            // Navigation buttons
            Container(
              padding:
                  ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
              child: LayoutFixUtils.safeRow(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    ElevatedButton(
                      onPressed: _previousPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Previous'),
                    )
                  else
                    const SizedBox.shrink(),
                  if (_currentPage < 2)
                    ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Next'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Submit Registration'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
      child: LayoutFixUtils.safeColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, 24),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.headlineMedium?.color,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
          LayoutFixUtils.safeText(
            'Please provide your basic information to create your account.',
            style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(alpha: 0.7),
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Full name is required';
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.email),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
              suffixIcon: IconButton(
                icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.phone),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailsPage() {
    return SingleChildScrollView(
      padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
      child: LayoutFixUtils.safeColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Details',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, 24),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.headlineMedium?.color,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
          LayoutFixUtils.safeText(
            'Please provide additional details for admin approval. This information helps us understand your background and how you can contribute to the community.',
            style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(alpha: 0.7),
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Location (City, State, Country) *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_on),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Location is required';
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _localChurchController,
            decoration: InputDecoration(
              labelText: 'Local Church *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.church),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Local church is required';
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _occupationController,
            decoration: InputDecoration(
              labelText: 'Occupation/Business *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.work),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Occupation is required';
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _skillsController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Skills & Talents *',
              hintText: 'What skills can you contribute to the community?',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.star),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please describe your skills';
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _workContactController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Work Contact',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.business),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _homeContactController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Home Contact',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.home),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _generalInfoController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Additional Information',
              hintText: 'Any other information you\'d like to share...',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.info),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitmentPage() {
    return SingleChildScrollView(
      padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
      child: LayoutFixUtils.safeColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commitment & Engagement',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, 24),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.headlineMedium?.color,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
          LayoutFixUtils.safeText(
            'This platform is designed for active engagement in your local chapter or community. '
            'Please indicate how you plan to contribute and be involved.',
            style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(alpha: 0.7),
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

          // Important Notice
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding:
                  ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
              child: LayoutFixUtils.safeColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutFixUtils.safeRow(
                    children: [
                      Icon(Icons.info, color: Colors.orange.shade700),
                      SizedBox(
                          width:
                              ResponsiveUtils.getResponsiveSpacing(context, 8)),
                      LayoutFixUtils.expanded(
                        child: Text(
                          'Important Notice',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context, 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                  LayoutFixUtils.safeText(
                    'This platform is not for dormant members. We expect active engagement in your local chapter or community, '
                    'whether through availability, financial support, or both, as the Lord blesses you.',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

          TextFormField(
            controller: _localChapterController,
            decoration: InputDecoration(
              labelText: 'Local Chapter/Conference',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.group),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),

          TextFormField(
            controller: _conferenceController,
            decoration: InputDecoration(
              labelText: 'Conference/Union',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.account_balance),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

          Text(
            'How do you plan to contribute?',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.headlineMedium?.color,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),

          LayoutFixUtils.safeColumn(
            children: [
              RadioGroup<String>(
                groupValue: _commitmentType,
                onChanged: (value) => setState(() => _commitmentType = value!),
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      title: Text('Financial Support'),
                      subtitle: Text(
                          'I plan to contribute financially as the Lord blesses me'),
                      value: 'financial',
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: Text('Active Availability'),
                      subtitle: Text(
                          'I plan to be actively available for service and activities'),
                      value: 'active_availability',
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: Text('Both Financial & Active Support'),
                      subtitle: Text(
                          'I plan to contribute both financially and through active service'),
                      value: 'both',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

          // Final commitment statement
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding:
                  ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
              child: LayoutFixUtils.safeColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutFixUtils.safeRow(
                    children: [
                      Icon(Icons.handshake, color: Colors.green.shade700),
                      SizedBox(
                          width:
                              ResponsiveUtils.getResponsiveSpacing(context, 8)),
                      LayoutFixUtils.expanded(
                        child: Text(
                          'Our Commitment',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context, 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                  LayoutFixUtils.safeText(
                    'By registering, you acknowledge that this platform is designed for active members who are committed to '
                    'engaging with their local chapter and supporting the mission through their availability, resources, or both.',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
