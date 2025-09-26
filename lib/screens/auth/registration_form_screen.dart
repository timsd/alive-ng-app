import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../utils/mobile_utils.dart';

class RegistrationFormScreen extends StatefulWidget {
  const RegistrationFormScreen({super.key});

  @override
  State<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  
  // Basic info controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  
  // Verification controllers
  final _localChapterController = TextEditingController();
  final _localChurchController = TextEditingController();
  final _conferenceController = TextEditingController();
  
  // Commitment controllers
  final _financialCommitmentController = TextEditingController();
  final _availabilityController = TextEditingController();
  
  String _commitmentType = 'financial';
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
    _addressController.dispose();
    _bioController.dispose();
    _localChapterController.dispose();
    _localChurchController.dispose();
    _conferenceController.dispose();
    _financialCommitmentController.dispose();
    _availabilityController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create user account
      final authResult = await AuthService.instance.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
      );

      if (authResult.isSuccess && authResult.user != null) {
        // Update user profile with additional information
        final updatedProfile = UserProfile(
          id: authResult.user!.id,
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          phoneNumber: _phoneController.text.trim().isNotEmpty 
              ? _phoneController.text.trim() 
              : null,
          address: _addressController.text.trim().isNotEmpty 
              ? _addressController.text.trim() 
              : null,
          bio: _bioController.text.trim().isNotEmpty 
              ? _bioController.text.trim() 
              : null,
          
          // Verification fields
          localChapter: _localChapterController.text.trim().isNotEmpty 
              ? _localChapterController.text.trim() 
              : null,
          localChurch: _localChurchController.text.trim().isNotEmpty 
              ? _localChurchController.text.trim() 
              : null,
          conference: _conferenceController.text.trim().isNotEmpty 
              ? _conferenceController.text.trim() 
              : null,
          
          // Commitment tracking
          commitmentType: _commitmentType,
          financialCommitment: _commitmentType == 'financial' || _commitmentType == 'both'
              ? double.tryParse(_financialCommitmentController.text.trim())
              : null,
          availabilityCommitment: _commitmentType == 'active_availability' || _commitmentType == 'both'
              ? _availabilityController.text.trim()
              : null,
          
          // Admin approval fields (defaults)
          isApproved: false,
          approvalStatus: 'pending',
          
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await AuthService.instance.updateUserProfile(updatedProfile);

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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: MobileUtils.getResponsiveIconSize(context, 64),
            ),
            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
            const Text(
              'Your registration has been submitted successfully. '
              'An administrator will review your application and approve your access to the platform.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to auth screen
            },
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

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: MobileUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(
              fontSize: MobileUtils.getResponsiveFontSize(context, 24), 
              fontWeight: FontWeight.bold
            ),
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
          Text(
            'Please provide your basic information to create your account.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: MobileUtils.getResponsiveFontSize(context, 14),
            ),
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 24)),
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Full name is required';
              }
              return null;
            },
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bio',
              hintText: 'Tell us a little about yourself...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationPage() {
    return SingleChildScrollView(
      padding: MobileUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification Details',
            style: TextStyle(
              fontSize: MobileUtils.getResponsiveFontSize(context, 24), 
              fontWeight: FontWeight.bold
            ),
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
          Text(
            'Please provide your church and organizational details for verification.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: MobileUtils.getResponsiveFontSize(context, 14),
            ),
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 24)),
          TextFormField(
            controller: _localChapterController,
            decoration: const InputDecoration(
              labelText: 'Local Chapter *',
              hintText: 'e.g., Lagos 1, Abuja Central, etc.',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.group),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Local chapter is required';
              }
              return null;
            },
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _localChurchController,
            decoration: const InputDecoration(
              labelText: 'Local Church *',
              hintText: 'Name of your local church',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.church),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Local church is required';
              }
              return null;
            },
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _conferenceController,
            decoration: const InputDecoration(
              labelText: 'Conference *',
              hintText: 'Your conference or district',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Conference is required';
              }
              return null;
            },
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 24)),
          Container(
            padding: MobileUtils.getResponsivePadding(context),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(MobileUtils.getResponsiveBorderRadius(context, 8)),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: MobileUtils.getResponsiveSpacing(context, 8)),
                    Text(
                      'Verification Process',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: MobileUtils.getResponsiveFontSize(context, 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
                Text(
                  'Your provided information will be verified by our administrators to ensure you are a legitimate member of the ALIVE organization.',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: MobileUtils.getResponsiveFontSize(context, 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitmentPage() {
    return SingleChildScrollView(
      padding: MobileUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commitment to Growth',
            style: TextStyle(
              fontSize: MobileUtils.getResponsiveFontSize(context, 24), 
              fontWeight: FontWeight.bold
            ),
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
          Text(
            'Please specify your commitment to organizational growth.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: MobileUtils.getResponsiveFontSize(context, 14),
            ),
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 24)),
          Text(
            'Commitment Type *',
            style: TextStyle(
              fontSize: MobileUtils.getResponsiveFontSize(context, 16), 
              fontWeight: FontWeight.w500
            ),
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
          RadioGroup<String>(
            groupValue: _commitmentType,
            onChanged: (value) => setState(() => _commitmentType = value!),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Financial Commitment'),
                  subtitle: const Text('Contribute financially to organizational growth'),
                  value: 'financial',
                ),
                RadioListTile<String>(
                  title: const Text('Active Availability'),
                  subtitle: const Text('Contribute time and skills to organizational activities'),
                  value: 'active_availability',
                ),
                RadioListTile<String>(
                  title: const Text('Both Financial and Active'),
                  subtitle: const Text('Contribute both financially and through active participation'),
                  value: 'both',
                ),
              ],
            ),
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          if (_commitmentType == 'financial' || _commitmentType == 'both') ...[
            TextFormField(
              controller: _financialCommitmentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monthly Financial Commitment (USD)',
                hintText: 'Enter amount you can commit monthly',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (value) {
                if ((_commitmentType == 'financial' || _commitmentType == 'both') &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Financial commitment amount is required';
                }
                if (value != null && value.isNotEmpty) {
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                }
                return null;
              },
            ),
            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          ],
          if (_commitmentType == 'active_availability' || _commitmentType == 'both') ...[
            TextFormField(
              controller: _availabilityController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Availability Details',
                hintText: 'Describe your availability (days, hours, skills, etc.)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
              ),
              validator: (value) {
                if ((_commitmentType == 'active_availability' || _commitmentType == 'both') &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Availability details are required';
                }
                return null;
              },
            ),
            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          ],
          Container(
            padding: MobileUtils.getResponsivePadding(context),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(MobileUtils.getResponsiveBorderRadius(context, 8)),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.volunteer_activism, color: Colors.green),
                    SizedBox(width: MobileUtils.getResponsiveSpacing(context, 8)),
                    Text(
                      'Your Commitment Matters',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: MobileUtils.getResponsiveFontSize(context, 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
                Text(
                  'Your commitment helps us plan and allocate resources effectively for the growth and development of the ALIVE organization.',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: MobileUtils.getResponsiveFontSize(context, 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: MobileUtils.getResponsivePadding(context),
              child: Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: MobileUtils.getResponsiveSpacing(context, 4),
                        decoration: BoxDecoration(
                          color: i <= _currentPage ? Colors.blue : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(MobileUtils.getResponsiveBorderRadius(context, 2)),
                        ),
                      ),
                    ),
                    if (i < 2) SizedBox(width: MobileUtils.getResponsiveSpacing(context, 8)),
                  ],
                ],
              ),
            ),
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildBasicInfoPage(),
                  _buildVerificationPage(),
                  _buildCommitmentPage(),
                ],
              ),
            ),
            // Navigation buttons
            Container(
              padding: MobileUtils.getResponsivePadding(context),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentPage > 0) SizedBox(width: MobileUtils.getResponsiveSpacing(context, 16)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _currentPage < 2
                              ? _nextPage
                              : _submitRegistration,
                      child: _isLoading
                          ? SizedBox(
                              height: MobileUtils.getResponsiveSpacing(context, 20),
                              width: MobileUtils.getResponsiveSpacing(context, 20),
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_currentPage < 2 ? 'Next' : 'Submit Registration'),
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
}



