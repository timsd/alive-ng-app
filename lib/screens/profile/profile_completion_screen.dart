import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_models.dart';
import '../../providers/appwrite_auth_provider.dart';
import '../../services/appwrite_profile_service.dart';
import '../../providers/profile_setup_provider.dart';
import '../../widgets/profile_page_cues.dart';
import '../../widgets/custom_app_bar.dart';

/// Shown after Google / social sign-in when the user profile is missing key
/// fields (phone, church, location, occupation).  Follows Material 3 stepper
/// conventions so it feels like a standard onboarding flow.
class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSaving = false;

  // Controllers
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _localChurchController = TextEditingController();
  final _occupationController = TextEditingController();
  final _skillsController = TextEditingController();
  final _chapterController = TextEditingController();
  String _commitmentType = 'both';
  final _financialController = TextEditingController();
  final _availabilityController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _locationController.dispose();
    _localChurchController.dispose();
    _occupationController.dispose();
    _skillsController.dispose();
    _chapterController.dispose();
    _financialController.dispose();
    _availabilityController.dispose();
    super.dispose();
  }

  List<Step> _buildSteps(BuildContext context) {
    final theme = Theme.of(context);
    return [
      // ── Step 1: Contact info ────────────────────────────────────────────
      Step(
        title: Text('Contact Info',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            _field(_phoneController, 'Phone Number', Icons.phone_outlined,
                type: TextInputType.phone),
            const SizedBox(height: 14),
            _field(_locationController, 'City / State', Icons.location_on_outlined),
          ],
        ),
      ),
      // ── Step 2: Church & chapter ────────────────────────────────────────
      Step(
        title: Text('Church & Chapter',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            _field(_localChurchController, 'Local Church', Icons.church_outlined),
            const SizedBox(height: 14),
            _field(_chapterController, 'Chapter You Wish to Join',
                Icons.group_add_outlined),
          ],
        ),
      ),
      // ── Step 3: Professional info ────────────────────────────────────────
      Step(
        title: Text('Occupation & Skills',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            _field(_occupationController, 'Occupation', Icons.work_outline),
            const SizedBox(height: 14),
            _field(_skillsController, 'Skills (optional)', Icons.handyman_outlined),
          ],
        ),
      ),
      // ── Step 4: Commitment ───────────────────────────────────────────────
      Step(
        title: Text('Commitment',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        isActive: _currentStep >= 3,
        state: StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _commitmentType,
              decoration: _decoration('Commitment Type',
                  Icons.volunteer_activism_outlined),
              items: const [
                DropdownMenuItem(value: 'financial', child: Text('Financial')),
                DropdownMenuItem(
                    value: 'active_availability',
                    child: Text('Active Availability')),
                DropdownMenuItem(value: 'both', child: Text('Both')),
              ],
              onChanged: (v) => setState(() => _commitmentType = v ?? 'both'),
            ),
            if (_commitmentType == 'financial' ||
                _commitmentType == 'both') ...[
              const SizedBox(height: 14),
              _field(_financialController,
                  'Monthly Financial Commitment (₦, optional)',
                  Icons.payments_outlined,
                  type: const TextInputType.numberWithOptions(decimal: true)),
            ],
            if (_commitmentType == 'active_availability' ||
                _commitmentType == 'both') ...[
              const SizedBox(height: 14),
              _field(_availabilityController,
                  'Availability (e.g. weekends, evenings)', Icons.schedule_outlined),
            ],
          ],
        ),
      ),
    ];
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      );

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: type,
        decoration: _decoration(label, icon),
      );

        /// Marks setup as handled for this account and moves on to the main app.
  Future<void> _skipProfileSetup() async {
    try {
      final user = ref.read(appwriteUserStreamProvider).value;
      await completeProfileSetup();
      if (user != null) {
        ref.invalidate(profileSetupRequiredProvider(user.uid));
      }
    } catch (e) {
      debugPrint('Could not record skipped profile setup: $e');
    }
    if (mounted) context.go('/home');
  }

  // Pre-fill fields from any existing profile data so returning users (e.g.
  // after Google sign-in with partial data) don't see a blank form.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingProfile();
    });
  }

  Future<void> _loadExistingProfile() async {
    final user = ref.read(appwriteUserStreamProvider).value;
    if (user == null) return;
    final profileService = ref.read(appwriteProfileServiceProvider);
    UserProfile? profile;
    try {
      profile = await profileService.getUserProfileModel(user.uid);
    } catch (e) {
      debugPrint('ProfileCompletion: could not load existing profile: $e');
    }
    if (profile == null || !mounted) return;
    if (_phoneController.text.isEmpty) {
      _phoneController.text = profile.phoneNumber ?? '';
    }
    if (_locationController.text.isEmpty) {
      _locationController.text = profile.location ?? '';
    }
    if (_localChurchController.text.isEmpty) {
      _localChurchController.text = profile.localChurch ?? '';
    }
    if (_chapterController.text.isEmpty) {
      _chapterController.text = profile.localChapter ?? '';
    }
    if (_occupationController.text.isEmpty) {
      _occupationController.text = profile.occupation ?? '';
    }
    if (_skillsController.text.isEmpty) {
      _skillsController.text = profile.skills ?? '';
    }
    if (profile.commitmentType != null &&
        ['financial', 'active_availability', 'both'].contains(profile.commitmentType)) {
      _commitmentType = profile.commitmentType!;
    }
    if (_financialController.text.isEmpty &&
        profile.financialCommitment != null) {
      _financialController.text = profile.financialCommitment!.toStringAsFixed(0);
    }
    if (_availabilityController.text.isEmpty) {
      _availabilityController.text = profile.availabilityCommitment ?? '';
    }
    if (mounted) setState(() {});
  }

  /// Auto-advances to the next step once the current step's required fields are
  /// filled, or saves on the final step. Shows a hint if required fields are
  /// empty so the flow can never be completed with blank required sections.
    void _advanceOrSave() {
    if (!mounted) return;
    final steps = _buildSteps(context);
    final isLastStep = _currentStep == steps.length - 1;
    final currentValid = _isStepComplete(_currentStep);
    if (isLastStep) {
      _saveProfile();
    } else if (currentValid) {
      setState(() => _currentStep++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_nextRequiredField(_currentStep)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Fields each step is considered "complete" for auto-advance. Steps 0–2 are
  /// the required-data steps; step 3 (Commitment) is always valid to advance.
  bool _isStepComplete(int step) {
    if (step >= 3) return true;
    switch (step) {
      case 0:
        return _phoneController.text.trim().isNotEmpty;
      case 1:
        return _localChurchController.text.trim().isNotEmpty ||
            _chapterController.text.trim().isNotEmpty;
      case 2:
        return _occupationController.text.trim().isNotEmpty;
    }
    return false;
  }

  String _nextRequiredField(int step) {
    switch (step) {
      case 0:
        return 'Please enter a phone number to continue.';
      case 1:
        return 'Please enter a local church or chapter to continue.';
      case 2:
        return 'Please enter your occupation to continue.';
      default:
        return 'Complete the required fields to continue.';
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = ref.read(appwriteUserStreamProvider).value;
      if (user == null) {
        context.go('/home');
        return;
      }

      final profileService = ref.read(appwriteProfileServiceProvider);

      final profileData = <String, dynamic>{
        if (_phoneController.text.trim().isNotEmpty)
          'phone_number': _phoneController.text.trim(),
        if (_locationController.text.trim().isNotEmpty)
          'location': _locationController.text.trim(),
        if (_localChurchController.text.trim().isNotEmpty)
          'local_church': _localChurchController.text.trim(),
        if (_chapterController.text.trim().isNotEmpty)
          'local_chapter': _chapterController.text.trim(),
        if (_occupationController.text.trim().isNotEmpty)
          'occupation': _occupationController.text.trim(),
        if (_skillsController.text.trim().isNotEmpty)
          'skills': _skillsController.text.trim(),
        'commitment_type': _commitmentType,
        if ((_commitmentType == 'financial' || _commitmentType == 'both') &&
            _financialController.text.trim().isNotEmpty)
          'financial_commitment':
              double.tryParse(_financialController.text.trim()),
        if ((_commitmentType == 'active_availability' ||
                _commitmentType == 'both') &&
            _availabilityController.text.trim().isNotEmpty)
          'availability_commitment': _availabilityController.text.trim(),
      };

      await profileService.updateUserProfile(
        userId: user.uid,
        profileData: profileData,
      );

      // Record completion so the router guard releases the user into the main
      // app instead of redirecting straight back to this screen.
      await completeProfileSetup();
      ref.invalidate(profileSetupRequiredProvider(user.uid));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile saved — welcome to ALIVE Nigeria! 🎉'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save profile: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps(context);
    final theme = Theme.of(context);
    final isLastStep = _currentStep == steps.length - 1;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Complete Your Profile',
        showBackButton: false,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _skipProfileSetup,
            child: Text(
              'Skip',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.colorScheme.secondary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${_currentStep + 1} of ${steps.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / steps.length,
                    minHeight: 6,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary),
                  ),
                ),
                // Horizontal-swipe affordance: dots + hint so users know the
                // setup steps are paged sideways, not just listed vertically.
                ProfilePageCues(index: _currentStep, count: steps.length),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: Stepper(
                currentStep: _currentStep,
                onStepTapped: (s) => setState(() => _currentStep = s),
                type: StepperType.vertical,
                steps: steps,
                controlsBuilder: (context, details) => Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: [
                                            FilledButton(
                        onPressed: _isSaving ? null : _advanceOrSave,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isLastStep ? 'Finish & Save' : 'Continue'),
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _currentStep--),
                          child: const Text('Back'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
