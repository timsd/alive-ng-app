import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/app_models.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/layout_fix_utils.dart';
import '../../services/appwrite_storage_service.dart';
import '../../services/auth_service.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/custom_image.dart';
import '../../widgets/custom_app_bar.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile userProfile;

  const EditProfileScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
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
  late final TextEditingController _workContactController;
  late final TextEditingController _homeContactController;
  late final TextEditingController _generalInfoController;

  // Commitment controllers
  late final TextEditingController _localChapterController;

  late String _commitmentType;
  bool _isLoading = false;
  int _currentPage = 0;
  bool _hasChanges = false;

  // Profile picture upload variables
  String? _profilePictureUrl;
  bool _isUploadingPicture = false;

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
    _workContactController =
        TextEditingController(text: widget.userProfile.workContact ?? '');
    _homeContactController =
        TextEditingController(text: widget.userProfile.homeContact ?? '');
    _generalInfoController =
        TextEditingController(text: widget.userProfile.generalInfo ?? '');
    _localChapterController =
        TextEditingController(text: widget.userProfile.localChapter ?? '');

    _commitmentType = widget.userProfile.commitmentType ?? 'both';

    // Initialize profile picture URL
    _profilePictureUrl = widget.userProfile.avatarUrl;

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
      _workContactController,
      _homeContactController,
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
    _workContactController.dispose();
    _homeContactController.dispose();
    _generalInfoController.dispose();
    _localChapterController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create updated user profile
      final updatedProfile = widget.userProfile.copyWith(
        fullName: _fullNameController.text.trim(),
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
        workContact: _workContactController.text.trim().isNotEmpty
            ? _workContactController.text.trim()
            : null,
        homeContact: _homeContactController.text.trim().isNotEmpty
            ? _homeContactController.text.trim()
            : null,
        generalInfo: _generalInfoController.text.trim().isNotEmpty
            ? _generalInfoController.text.trim()
            : null,
        localChapter: _localChapterController.text.trim().isNotEmpty
            ? _localChapterController.text.trim()
            : null,
        commitmentType: _commitmentType,
        avatarUrl: _profilePictureUrl, // Add profile picture URL
        updatedAt: DateTime.now(),
      );

      // Save updated profile to database
      await AuthService.instance.updateUserProfile(updatedProfile);

      if (mounted) {
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
          actions: [
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _isLoading ? null : _saveProfile,
              ),
          ],
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
                  'Section ${_currentPage + 1} of 3',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),

              // Page content
              LayoutFixUtils.expanded(
                child: PageView(
                  controller: _pageController,
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
            'Update your profile details. This information is important for community engagement.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: _profilePictureUrl != null
                  ? ClipOval(
                      child: CustomImage(
                        imageUrl: _profilePictureUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: Icon(
                          Icons.person,
                          size: 40,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 40,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        _isUploadingPicture ? null : _uploadProfilePicture,
                    icon: _isUploadingPicture
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_isUploadingPicture
                        ? 'Uploading...'
                        : 'Upload Picture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  if (_profilePictureUrl != null) ...[
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 8)),
                    TextButton.icon(
                      onPressed: _removeProfilePicture,
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

  Future<void> _uploadProfilePicture() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.bytes == null) {
          ToastUtils.showError('Failed to read image file');
          return;
        }

        setState(() => _isUploadingPicture = true);

        try {
          final authService = AuthService.instance;
          final user = authService.currentUser;

          if (user == null) {
            ToastUtils.showError('User not authenticated');
            return;
          }

          // Generate unique filename
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = file.extension ?? 'jpg';
          final fileName = 'profile_${user.uid}_$timestamp.$extension';
          final contentType = switch (extension.toLowerCase()) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          };

          final publicUrl =
              await AppwriteStorageService.instance.uploadProfileFile(
            bytes: file.bytes!,
            fileName: 'profile-pictures/$fileName',
            contentType: contentType,
          );

          setState(() {
            _profilePictureUrl = publicUrl;
            _hasChanges = true;
          });

          ToastUtils.showSuccess('Profile picture uploaded successfully!');

          if (widget.userProfile.avatarUrl != null &&
              widget.userProfile.avatarUrl!.isNotEmpty) {
            try {
              await AppwriteStorageService.instance
                  .deleteFileByUrl(widget.userProfile.avatarUrl!);
            } catch (e) {
              // Ignore errors when deleting old file
            }
          }
        } catch (e) {
          ToastUtils.showError('Failed to upload profile picture: $e');
        } finally {
          setState(() => _isUploadingPicture = false);
        }
      }
    } catch (e) {
      ToastUtils.showError('Error selecting image: $e');
      setState(() => _isUploadingPicture = false);
    }
  }

  void _removeProfilePicture() {
    setState(() {
      _profilePictureUrl = null;
      _hasChanges = true;
    });
    ToastUtils.showSuccess('Profile picture removed');
  }
}
