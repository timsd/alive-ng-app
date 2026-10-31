import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_models.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/error_detail.dart';
import '../../utils/layout_fix_utils.dart';
import '../../services/appwrite_storage_service.dart';
import '../../services/appwrite_profile_service.dart';
import '../../services/role_access_service.dart';
import '../../providers/appwrite_auth_provider.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/custom_image.dart';
import '../../widgets/profile_page_cues.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/channel_membership_sync_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserProfile userProfile;

  const EditProfileScreen({
    super.key,
    required this.userProfile,
  });

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Basic info controllers
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;

  // Enhanced profile controllers
  late final TextEditingController _locationController;
  late final TextEditingController _localChurchController;
  late final TextEditingController _occupationController;
  late final TextEditingController _skillsController;
  late final TextEditingController _generalInfoController;

  // Commitment controllers
  late final TextEditingController _localChapterController;

  late String _commitmentType;
  late String _maritalStatus;
  bool _isLoading = false;
  int _currentPage = 0;
  bool _hasChanges = false;

  // Profile picture upload variables
  String? _profilePictureUrl;
  bool _isUploadingPicture = false;

  /// Local bytes of the most recently uploaded picture. Rendering these keeps
  /// the new image visible instantly without waiting for a network round trip.
  Uint8List? _pendingPictureBytes;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data
    _fullNameController =
        TextEditingController(text: widget.userProfile.fullName);
    _phoneController =
        TextEditingController(text: widget.userProfile.phoneNumber ?? '');
    _locationController =
        TextEditingController(text: widget.userProfile.location ?? '');
    _localChurchController =
        TextEditingController(text: widget.userProfile.localChurch ?? '');
    _occupationController =
        TextEditingController(text: widget.userProfile.occupation ?? '');
    _skillsController =
        TextEditingController(text: widget.userProfile.skills ?? '');
    _generalInfoController =
        TextEditingController(text: widget.userProfile.generalInfo ?? '');
    _localChapterController =
        TextEditingController(text: widget.userProfile.localChapter ?? '');

    _commitmentType = widget.userProfile.commitmentType ?? 'both';
    _maritalStatus =
        (widget.userProfile.maritalStatus ?? 'single').toLowerCase();
    if (_maritalStatus != 'married') _maritalStatus = 'single';

    // Initialize profile picture URL from either avatarUrl or photoUrl
    _profilePictureUrl = (widget.userProfile.avatarUrl != null &&
            widget.userProfile.avatarUrl!.trim().isNotEmpty)
        ? widget.userProfile.avatarUrl!.trim()
        : ((widget.userProfile.photoUrl != null &&
                widget.userProfile.photoUrl!.trim().isNotEmpty)
            ? widget.userProfile.photoUrl!.trim()
            : null);

    // Add listeners to detect changes
    _addChangeListeners();
  }

  void _addChangeListeners() {
    final controllers = [
      _fullNameController,
      _phoneController,
      _locationController,
      _localChurchController,
      _occupationController,
      _skillsController,
      _generalInfoController,
      _localChapterController,
    ];

    for (final controller in controllers) {
      controller.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _localChurchController.dispose();
    _occupationController.dispose();
    _skillsController.dispose();
    _generalInfoController.dispose();
    _localChapterController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Moves to the page holding the first invalid field and says what is
  /// wrong, so a failed save is never silent.
  void _showValidationError() {
    final missing = <String>[];
    if (_fullNameController.text.trim().isEmpty) missing.add('Full name');

    final fieldOrder = <String, int>{
      'Full name': 0,
    };
    for (final label in missing) {
      final page = fieldOrder[label] ?? 0;
      if (_currentPage != page) {
        _currentPage = page;
        _pageController.animateToPage(
          page,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        break;
      }
    }

    final detail = missing.isEmpty
        ? 'Please correct the highlighted fields.'
        : 'Please fill in: ${missing.join(', ')}.';
    ToastUtils.showError('Profile not saved. $detail');
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showValidationError();
      return;
    }

    setState(() => _isLoading = true);

    try {
      String field(TextEditingController c) => c.text.trim();
      final resolvedAvatar = _profilePictureUrl?.trim() ?? '';

      // Create updated user profile
      final updatedProfile = widget.userProfile.copyWith(
        fullName: field(_fullNameController),
        phoneNumber: field(_phoneController),
        location: field(_locationController),
        localChurch: field(_localChurchController),
        occupation: field(_occupationController),
        skills: field(_skillsController),
        generalInfo: field(_generalInfoController),
        localChapter: field(_localChapterController),
        maritalStatus: _maritalStatus,
        commitmentType: _commitmentType,
        avatarUrl: resolvedAvatar,
        photoUrl: resolvedAvatar,
        updatedAt: DateTime.now(),
      );

      // Save updated profile to database via AppwriteProfileService
      final profileService = ref.read(appwriteProfileServiceProvider);
      await profileService.updateUserProfile(
        userId: updatedProfile.id,
        fullName: updatedProfile.fullName,
        profileData: profileService.userProfileToAppwriteData(updatedProfile),
      );

      // Keep reactive avatar state and role cache in sync
      ref.read(uploadedAvatarUrlProvider.notifier).state = resolvedAvatar;
      RoleAccessService.instance.clearCache();

      // Automatically sync/migrate chat channels (e.g. Single -> Married)
      try {
        await ChannelMembershipSyncService.instance
            .syncUserChannels(updatedProfile);
      } catch (e) {
        debugPrint('Channel sync after profile save note: $e');
      }

      // Invalidate current user profile provider so all screens reflect updates
      ref.invalidate(currentUserProfileProvider);

      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
        Navigator.of(context).pop(updatedProfile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  void _goToPage(int page) {
    if (page >= 0 && page < 3 && _pageController.hasClients) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < 2 && _pageController.hasClients) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0 && _pageController.hasClients) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _sectionTitle(int index) {
    switch (index) {
      case 0:
        return 'Basic Information';
      case 1:
        return 'Profile Details';
      default:
        return 'Commitment';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: CustomAppBar(
          title: 'Edit Profile',
          showBackButton: true,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isLoading ? null : _saveProfile,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          icon: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                )
              : const Icon(Icons.save),
          label: Text(_hasChanges ? 'Save Changes' : 'Done'),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              // Progress indicator
              Container(
                padding:
                    ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / 3,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary),
                ),
              ),

              // Page indicator
              Container(
                padding:
                    ResponsiveUtils.getResponsivePaddingWithBase(context, 8),
                child: Text(
                  'Section ${_currentPage + 1} of 3: ${_sectionTitle(_currentPage)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),

              // Swipe affordance: dots + helper text with direct tap navigation
              ProfilePageCues(
                index: _currentPage,
                count: 3,
                onPageSelected: _goToPage,
              ),

              // Page content with responsive physics
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics:
                      const PageScrollPhysics(parent: BouncingScrollPhysics()),
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
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
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurface,
                        ),
                        child: const Text('Previous'),
                      )
                    else
                      const SizedBox.shrink(),
                    if (_currentPage < 2)
                      ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                        child: const Text('Next'),
                      )
                    else
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.onPrimary),
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
          LayoutFixUtils.safeText(
            'Update your basic information. Note: Email cannot be changed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

          // Profile Picture Section
          _buildProfilePictureSection(),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

          // Email (read-only)
          TextFormField(
            initialValue: widget.userProfile.email,
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Email Address',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.email),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),

          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.phone),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),

          DropdownButtonFormField<String>(
            initialValue: _maritalStatus,
            decoration: InputDecoration(
              labelText: 'Marital Status',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.favorite),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
              helperText:
                  'Connects you automatically to Singles or Married Fellowship.',
            ),
            items: const [
              DropdownMenuItem(value: 'single', child: Text('Single')),
              DropdownMenuItem(value: 'married', child: Text('Married')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _maritalStatus = val;
                  _hasChanges = true;
                });
              }
            },
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
          LayoutFixUtils.safeText(
            'Update your profile details. This information helps connect you with your local community.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Location (City, State, Country)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_on),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _localChurchController,
            decoration: InputDecoration(
              labelText: 'Local Church',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.church),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _occupationController,
            decoration: InputDecoration(
              labelText: 'Occupation/Business',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.work),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          TextFormField(
            controller: _skillsController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Skills & Talents',
              hintText: 'What skills can you contribute to the community?',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.star),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
          LayoutFixUtils.safeText(
            'Update your commitment and engagement preferences.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
          TextFormField(
            controller: _localChapterController,
            decoration: InputDecoration(
              labelText: 'Local Chapter',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.group),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          Text(
            'How do you plan to contribute?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          LayoutFixUtils.safeColumn(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'financial',
                    label: Text('Financial Support'),
                    icon: Icon(Icons.payments),
                  ),
                  ButtonSegment<String>(
                    value: 'active_availability',
                    label: Text('Active Availability'),
                    icon: Icon(Icons.volunteer_activism),
                  ),
                  ButtonSegment<String>(
                    value: 'both',
                    label: Text('Both'),
                    icon: Icon(Icons.handshake),
                  ),
                ],
                selected: <String>{_commitmentType},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _commitmentType = newSelection.first;
                    _onFieldChanged();
                  });
                },
                showSelectedIcon: false,
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
              LayoutFixUtils.safeText(
                _commitmentType == 'financial'
                    ? 'I plan to contribute financially as the Lord blesses me'
                    : _commitmentType == 'active_availability'
                        ? 'I plan to be actively available for service and activities'
                        : 'I plan to contribute both financially and through active service',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    final hasImage = _pendingPictureBytes != null ||
        (_profilePictureUrl != null && _profilePictureUrl!.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Picture',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
        Row(
          children: [
            // Profile picture preview
            GestureDetector(
              onTap: _isUploadingPicture ? null : _showImageSourcePicker,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: hasImage
                    ? ClipOval(
                        child: _pendingPictureBytes != null
                            ? Image.memory(
                                _pendingPictureBytes!,
                                key: ValueKey(_pendingPictureBytes.hashCode),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPicturePlaceholder(),
                              )
                            : CustomImage(
                                key: ValueKey(_profilePictureUrl),
                                imageUrl: _profilePictureUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: _buildPicturePlaceholder(),
                              ),
                      )
                    : _buildPicturePlaceholder(),
              ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        _isUploadingPicture ? null : _showImageSourcePicker,
                    icon: _isUploadingPicture
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera),
                    label: Text(_isUploadingPicture
                        ? 'Saving picture...'
                        : 'Change Picture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  if (hasImage) ...[
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 8)),
                    TextButton.icon(
                      onPressed:
                          _isUploadingPicture ? null : _removeProfilePicture,
                      icon: Icon(Icons.delete,
                          color: Theme.of(context).colorScheme.error),
                      label: Text('Remove Picture',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showImageSourcePicker() async {
    if (kIsWeb) {
      await _pickAndUploadImage(ImageSource.gallery);
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Change Profile Photo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Photo Gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Detects a safe, Appwrite-allowed image file extension from magic bytes
  /// or fallback extension string.
  static String _detectImageExtension(Uint8List bytes, String rawExt) {
    if (bytes.length >= 4) {
      // PNG: 89 50 4E 47
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'png';
      }
      // JPEG: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'jpg';
      }
      // GIF: 47 49 46 38
      if (bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x38) {
        return 'gif';
      }
      // WEBP: RIFF....WEBP
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'webp';
      }
    }
    final cleaned = rawExt.trim().toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
    if (allowed.contains(cleaned)) return cleaned;
    return 'jpg';
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      Uint8List? imageBytes;
      String rawExt = 'jpg';

      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (pickedFile != null) {
          imageBytes = await pickedFile.readAsBytes();
          if (pickedFile.name.contains('.')) {
            rawExt = pickedFile.name.split('.').last.toLowerCase();
          } else if (pickedFile.mimeType != null &&
              pickedFile.mimeType!.contains('/')) {
            rawExt = pickedFile.mimeType!.split('/').last.toLowerCase();
          }
        }
      } catch (pickerErr) {
        debugPrint('[ProfilePicture] ImagePicker fallback: $pickerErr');
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final f = result.files.first;
          if (f.bytes != null) {
            imageBytes = f.bytes;
          } else if (f.path != null && !kIsWeb) {
            imageBytes = await io.File(f.path!).readAsBytes();
          }
          if (f.extension != null) rawExt = f.extension!.toLowerCase();
        }
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        return; // User cancelled
      }

      final extension = _detectImageExtension(imageBytes, rawExt);

      // Show local bytes immediately while uploading
      setState(() {
        _pendingPictureBytes = imageBytes;
        _isUploadingPicture = true;
      });

      try {
        final userId = widget.userProfile.id;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'profile_${userId}_$timestamp.$extension';
        final contentType = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          _ => 'image/jpeg',
        };

        final previousUrl = _profilePictureUrl;
        final publicUrl =
            await AppwriteStorageService.instance.uploadProfileFile(
          bytes: imageBytes,
          fileName: fileName,
          contentType: contentType,
        );

        // Update database with the durable URL
        await ref.read(appwriteProfileServiceProvider).updateUserProfile(
              userId: widget.userProfile.id,
              email: widget.userProfile.email,
              fullName: _fullNameController.text.trim().isNotEmpty
                  ? _fullNameController.text.trim()
                  : widget.userProfile.fullName,
              profileData: {
                'avatar_url': publicUrl,
                'photo_url': publicUrl,
              },
            );

        // Immediately propagate the new avatar URL to all screens (Home, Profile, etc.)
        ref.read(uploadedAvatarUrlProvider.notifier).state = publicUrl;
        RoleAccessService.instance.clearCache();

        if (!mounted) return;
        setState(() {
          _profilePictureUrl = publicUrl;
        });

        try {
          if (previousUrl != null && previousUrl.isNotEmpty) {
            await CachedNetworkImageProvider(previousUrl).evict();
          }
          await CachedNetworkImageProvider(publicUrl).evict();
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        } catch (_) {}

        ref.invalidate(currentUserProfileProvider);

        ToastUtils.showSuccess('Profile photo updated successfully!');

        if (previousUrl != null &&
            previousUrl.isNotEmpty &&
            previousUrl != publicUrl) {
          try {
            await AppwriteStorageService.instance.deleteFileByUrl(previousUrl);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[ProfilePicture] upload error: ${describeError(e)}');
        if (mounted) {
          setState(() {
            _pendingPictureBytes = null;
          });
        }
        ToastUtils.showError('Upload failed: ${describeError(e)}');
      } finally {
        if (mounted) setState(() => _isUploadingPicture = false);
      }
    } catch (e) {
      debugPrint('[ProfilePicture] selection error: ${describeError(e)}');
      ToastUtils.showError('Could not process that image: ${describeError(e)}');
      if (mounted) setState(() => _isUploadingPicture = false);
    }
  }

  Widget _buildPicturePlaceholder() {
    final name = _fullNameController.text.trim().isNotEmpty
        ? _fullNameController.text.trim()
        : (widget.userProfile.fullName ?? '').trim();
    if (name.isNotEmpty) {
      return Center(
        child: Text(
          name[0].toUpperCase(),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      );
    }
    return Icon(
      Icons.person,
      size: 40,
      color: Theme.of(context).colorScheme.onPrimary,
    );
  }

  Future<void> _removeProfilePicture() async {
    final previousUrl = _profilePictureUrl;
    if ((previousUrl == null || previousUrl.isEmpty) &&
        _pendingPictureBytes == null) {
      return;
    }

    setState(() {
      _profilePictureUrl = null;
      _pendingPictureBytes = null;
    });

    try {
      await ref.read(appwriteProfileServiceProvider).updateUserProfile(
            userId: widget.userProfile.id,
            profileData: {'avatar_url': '', 'photo_url': ''},
          );
      ref.read(uploadedAvatarUrlProvider.notifier).state = '';
      RoleAccessService.instance.clearCache();
      try {
        if (previousUrl != null && previousUrl.isNotEmpty) {
          await CachedNetworkImageProvider(previousUrl).evict();
        }
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}
      ref.invalidate(currentUserProfileProvider);
      if (previousUrl != null && previousUrl.isNotEmpty) {
        try {
          await AppwriteStorageService.instance.deleteFileByUrl(previousUrl);
        } catch (_) {}
      }
      if (mounted) ToastUtils.showSuccess('Profile picture removed');
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('Failed to remove profile picture: $e');
      }
    }
  }
}
