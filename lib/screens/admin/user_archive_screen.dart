// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as appwrite_models;
import 'package:flutter/material.dart';
import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../utils/logger.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_image.dart';

class UserArchiveScreen extends StatefulWidget {
  const UserArchiveScreen({super.key});

  @override
  State<UserArchiveScreen> createState() => _UserArchiveScreenState();
}

class _UserArchiveScreenState extends State<UserArchiveScreen> {
  late final Databases _databases = Databases(appwriteClient);
  final Logger _logger = Logger('UserArchiveScreen');
  bool _isLoading = true;
  bool _hasAccess = false;
  appwrite_models.User? _currentUser;
  List<UserProfile> _archivedUsers = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final user = AuthService.instance.currentUser;
      _currentUser = user;
      if (user != null) {
        // For now, allow access - role checking should be implemented with UserProfile
        _hasAccess = true;

        if (_hasAccess) {
          await _loadArchivedUsers();
        }
      }
    } catch (e) {
      _hasAccess = false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadArchivedUsers() async {
    try {
      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.usersCollectionId,
        queries: [
          Query.equal('is_archived', true),
          Query.orderDesc('updated_at'),
          Query.limit(100),
        ],
      );

      final List<UserProfile> archivedUsers = [];
      for (final doc in response.documents) {
        try {
          archivedUsers.add(UserProfile.fromJson({
            ...doc.data,
            'id': doc.$id,
          }));
        } catch (e) {
          _logger.error('Error parsing user data', e);
        }
      }

      setState(() {
        _archivedUsers = archivedUsers;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading archived users: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  List<UserProfile> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _archivedUsers;
    }
    return _archivedUsers.where((user) {
      final name = user.fullName?.toLowerCase() ?? '';
      final email = user.email?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: CustomAppBar(
          title: 'Access Denied',
          showBackButton: true,
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.archive_outlined,
                size: ResponsiveUtils.getResponsiveIconSize(context, 80),
                color: theme.colorScheme.error,
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
              Text(
                'Access Denied',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 24),
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              Text(
                'You do not have permission to access archived users.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              Text(
                'This section is restricted to Leaders,\nCoordinators, and Administrators only.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Archived Users',
        showBackButton: true,
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadArchivedUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search archived users...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getResponsiveBorderRadiusValue(
                          context, 10)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getResponsiveBorderRadiusValue(
                          context, 10)),
                  borderSide:
                      BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Info Card
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getResponsivePaddingValue(context)),
            child: Card(
              color:
                  theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(
                    ResponsiveUtils.getResponsiveSpacing(context, 12)),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    SizedBox(
                        width:
                            ResponsiveUtils.getResponsiveSpacing(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Archived Users',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                          Text(
                            'Users who have left the organization. Found ${_filteredUsers.length} archived users.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),

          // Archived Users List
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.archive_outlined,
                          size: ResponsiveUtils.getResponsiveIconSize(
                              context, 64),
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.4),
                        ),
                        SizedBox(
                            height: ResponsiveUtils.getResponsiveSpacing(
                                context, 16)),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No archived users found'
                              : 'No users match your search',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context, 18),
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(
                            height: ResponsiveUtils.getResponsiveSpacing(
                                context, 8)),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Users who leave the organization will appear here'
                              : 'Try adjusting your search terms',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            ResponsiveUtils.getResponsivePaddingValue(context)),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return _buildArchivedUserCard(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedUserCard(UserProfile user) {
    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 12)),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          backgroundImage: user.avatarUrl != null
              ? CustomImage.provider(user.avatarUrl!)
              : null,
          child: user.avatarUrl == null
              ? Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.onSecondary,
                )
              : null,
        ),
        title: Text(
          user.fullName ?? 'Unknown User',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email ?? 'No email',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 4)),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        ResponsiveUtils.getResponsiveSpacing(context, 8),
                    vertical: ResponsiveUtils.getResponsiveSpacing(context, 2),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getResponsiveBorderRadiusValue(
                            context, 12)),
                  ),
                  child: Text(
                    'ARCHIVED',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                  ),
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                Text(
                  user.role.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (user.isNewConvert) ...[
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          ResponsiveUtils.getResponsiveSpacing(context, 6),
                      vertical:
                          ResponsiveUtils.getResponsiveSpacing(context, 2),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveBorderRadiusValue(
                              context, 10)),
                    ),
                    child: Text(
                      'NC',
                      style: TextStyle(
                        fontSize:
                            ResponsiveUtils.getResponsiveFontSize(context, 9),
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Phone', user.phoneNumber ?? 'Not provided'),
                _buildDetailRow('Address', user.address ?? 'Not provided'),
                _buildDetailRow('Chapter', user.chapterId ?? 'Not assigned'),
                _buildDetailRow('Bio', user.bio ?? 'No bio available'),
                _buildDetailRow(
                  'Archived Date',
                  user.updatedAt.toString().split(' ')[0],
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 16)),

                // Action Buttons
                if (_currentUser != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _restoreUser(user),
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore User'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.tertiary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onTertiary,
                          ),
                        ),
                      ),
                      SizedBox(
                          width: ResponsiveUtils.getResponsiveSpacing(
                              context, 12)),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _permanentlyDeleteUser(user),
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            foregroundColor:
                                Theme.of(context).colorScheme.onError,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ResponsiveUtils.getResponsiveSpacing(context, 80),
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreUser(UserProfile user) async {
    try {
      // Update user profile to unarchive them
      // Store context in local variable before async gap
      final messenger = ScaffoldMessenger.of(context);
      final theme = Theme.of(context);

      await _databases.updateDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.usersCollectionId,
        documentId: user.id,
        data: {
          'is_archived': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text('${user.fullName} has been restored'),
          backgroundColor: theme.colorScheme.tertiary,
        ),
      );
      await _loadArchivedUsers();
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error restoring user: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _permanentlyDeleteUser(UserProfile user) async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanent Deletion'),
        content: Text(
          'Are you sure you want to permanently delete ${user.fullName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Future.wait([
          _deleteUserRows(
            AppwriteBackendConfig.prayerRequestsCollectionId,
            user.id,
          ),
          _deleteUserRows(
            AppwriteBackendConfig.healthTrackingCollectionId,
            user.id,
          ),
          _deleteUserRows(
            AppwriteBackendConfig.userMissionsCollectionId,
            user.id,
          ),
          _deleteUserRows(
            AppwriteBackendConfig.studyProgressCollectionId,
            user.id,
          ),
        ]);
        await _databases.deleteDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.usersCollectionId,
          documentId: user.id,
        );

        // Store context in local variable before async gap
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('${user.fullName} has been permanently deleted'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        await _loadArchivedUsers();
      } catch (e) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting user: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteUserRows(String collectionId, String userId) async {
    final response = await _databases.listDocuments(
      databaseId: AppwriteBackendConfig.databaseId,
      collectionId: collectionId,
      queries: [
        Query.equal('user_id', userId),
        Query.limit(100),
      ],
    );

    await Future.wait(
      response.documents.map(
        (doc) => _databases.deleteDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: collectionId,
          documentId: doc.$id,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
