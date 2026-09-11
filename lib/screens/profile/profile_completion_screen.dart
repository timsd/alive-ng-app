import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/appwrite_auth_provider.dart';
import '../../services/appwrite_profile_service.dart';
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
            onPressed: _isSaving ? null : () => context.go('/home'),
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
                        onPressed: _isSaving
                            ? null
                            : () async {
                                if (isLastStep) {
                                  await _saveProfile();
                                } else {
                                  setState(() => _currentStep++);
                                }
                              },
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
