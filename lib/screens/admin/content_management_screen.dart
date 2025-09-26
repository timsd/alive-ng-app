import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/toast_utils.dart';
import '../../utils/text_formatter.dart';

class ContentManagementScreen extends StatefulWidget {
  final String? contentType;
  
  const ContentManagementScreen({
    super.key,
    this.contentType,
  });

  @override
  State<ContentManagementScreen> createState() => _ContentManagementScreenState();
}

class _ContentManagementScreenState extends State<ContentManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _supabaseService = SupabaseService.instance;
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _contentPages = [];
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _appSettings = [];
  List<Map<String, dynamic>> _featuredContent = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllContent();
    
    // Set initial tab based on content type
    if (widget.contentType != null) {
      switch (widget.contentType) {
        case 'announcements':
          _tabController.index = 1;
          break;
        case 'settings':
          _tabController.index = 2;
          break;
        case 'featured':
          _tabController.index = 3;
          break;
        default:
          _tabController.index = 0;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllContent() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadContentPages(),
        _loadAnnouncements(),
        _loadAppSettings(),
        _loadFeaturedContent(),
      ]);
    } catch (e) {
      ToastUtils.showError('Error loading content: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContentPages() async {
    try {
      final response = await _supabaseService.client
          .from('content_pages')
          .select()
          .order('created_at', ascending: false);
      
      setState(() {
        _contentPages = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading content pages: $e');
    }
  }

  Future<void> _loadAnnouncements() async {
    try {
      final response = await _supabaseService.client
          .from('announcements')
          .select()
          .order('created_at', ascending: false);
      
      setState(() {
        _announcements = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading announcements: $e');
    }
  }

  Future<void> _loadAppSettings() async {
    try {
      final response = await _supabaseService.client
          .from('app_settings')
          .select()
          .order('category', ascending: true);
      
      setState(() {
        _appSettings = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading app settings: $e');
    }
  }

  Future<void> _loadFeaturedContent() async {
    try {
      final response = await _supabaseService.client
          .from('featured_content')
          .select()
          .order('created_at', ascending: false);
      
      setState(() {
        _featuredContent = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading featured content: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleVisibility(
      allowedRoles: const ['admin', 'super_admin', 'content_manager'],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Content Management'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'Pages', icon: Icon(Icons.article)),
              Tab(text: 'Announcements', icon: Icon(Icons.campaign)),
              Tab(text: 'Settings', icon: Icon(Icons.settings)),
              Tab(text: 'Featured', icon: Icon(Icons.star)),
            ],
          ),
        ),
        body: _isLoading
            ? const LoadingWidget()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildContentPagesTab(),
                  _buildAnnouncementsTab(),
                  _buildAppSettingsTab(),
                  _buildFeaturedContentTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildContentPagesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Content Pages (${_contentPages.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showContentPageDialog(),
                icon: const Icon(Icons.add),
                label: const Text('New Page'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _contentPages.isEmpty
              ? const Center(
                  child: Text(
                    'No content pages found.\nCreate your first page!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _contentPages.length,
                  itemBuilder: (context, index) {
                    final page = _contentPages[index];
                    return _buildContentPageCard(page);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildContentPageCard(Map<String, dynamic> page) {
    final isPublished = page['is_published'] ?? false;
    final publishDate = page['publish_date'] != null 
        ? DateTime.parse(page['publish_date']) 
        : null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPublished ? Colors.green : Colors.orange,
          child: Icon(
            isPublished ? Icons.public : Icons.drafts,
            color: Colors.white,
          ),
        ),
        title: Text(
          page['title'] ?? 'Untitled',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(page['slug'] ?? ''),
            const SizedBox(height: 4),
            Text(
              isPublished 
                  ? 'Published${publishDate != null ? ' on ${publishDate.day}/${publishDate.month}/${publishDate.year}' : ''}'
                  : 'Draft',
              style: TextStyle(
                color: isPublished ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: isPublished ? 'unpublish' : 'publish',
              child: ListTile(
                leading: Icon(isPublished ? Icons.visibility_off : Icons.visibility),
                title: Text(isPublished ? 'Unpublish' : 'Publish'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) => _handleContentPageAction(value, page),
        ),
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Announcements (${_announcements.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAnnouncementDialog(),
                icon: const Icon(Icons.add),
                label: const Text('New Announcement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _announcements.isEmpty
              ? const Center(
                  child: Text(
                    'No announcements found.\nCreate your first announcement!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _announcements.length,
                  itemBuilder: (context, index) {
                    final announcement = _announcements[index];
                    return _buildAnnouncementCard(announcement);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final isActive = announcement['is_active'] ?? false;
    final priority = announcement['priority'] ?? 'normal';
    final targetAudience = announcement['target_audience'] ?? 'all';
    
    Color priorityColor = Colors.blue;
    if (priority == 'high') priorityColor = Colors.red;
    if (priority == 'urgent') priorityColor = Colors.deepOrange;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green : Colors.grey,
          child: Icon(
            Icons.campaign,
            color: Colors.white,
          ),
        ),
        title: Text(
          announcement['title'] ?? 'Untitled',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(announcement['content'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Target: ${TextFormatter.formatRole(targetAudience).toUpperCase()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: isActive ? 'deactivate' : 'activate',
              child: ListTile(
                leading: Icon(isActive ? Icons.pause : Icons.play_arrow),
                title: Text(isActive ? 'Deactivate' : 'Activate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) => _handleAnnouncementAction(value, announcement),
        ),
      ),
    );
  }

  Widget _buildAppSettingsTab() {
    final groupedSettings = <String, List<Map<String, dynamic>>>{};
    for (final setting in _appSettings) {
      final category = setting['category'] ?? 'General';
      groupedSettings.putIfAbsent(category, () => []).add(setting);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'App Settings (${_appSettings.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAppSettingDialog(),
                icon: const Icon(Icons.add),
                label: const Text('New Setting'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: groupedSettings.isEmpty
              ? const Center(
                  child: Text(
                    'No app settings found.\nCreate your first setting!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: groupedSettings.keys.length,
                  itemBuilder: (context, index) {
                    final category = groupedSettings.keys.elementAt(index);
                    final settings = groupedSettings[category]!;
                    return _buildSettingsCategoryCard(category, settings);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsCategoryCard(String category, List<Map<String, dynamic>> settings) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ExpansionTile(
        leading: const Icon(Icons.settings, color: Colors.green),
        title: Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${settings.length} settings'),
        children: settings.map((setting) => _buildSettingTile(setting)).toList(),
      ),
    );
  }

  Widget _buildSettingTile(Map<String, dynamic> setting) {
    final isPublic = setting['is_public'] ?? false;
    
    return ListTile(
      leading: Icon(
        isPublic ? Icons.public : Icons.lock,
        color: isPublic ? Colors.green : Colors.orange,
        size: 20,
      ),
      title: Text(setting['key'] ?? ''),
      subtitle: Text(setting['description'] ?? ''),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: Colors.white)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        onSelected: (value) => _handleAppSettingAction(value, setting),
      ),
    );
  }

  Widget _buildFeaturedContentTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Featured Content (${_featuredContent.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showFeaturedContentDialog(),
                icon: const Icon(Icons.add),
                label: const Text('New Featured'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _featuredContent.isEmpty
              ? const Center(
                  child: Text(
                    'No featured content found.\nCreate your first featured item!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _featuredContent.length,
                  itemBuilder: (context, index) {
                    final content = _featuredContent[index];
                    return _buildFeaturedContentCard(content);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFeaturedContentCard(Map<String, dynamic> content) {
    final isActive = content['is_active'] ?? false;
    final contentType = content['content_type'] ?? 'general';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green : Colors.grey,
          child: Icon(
            Icons.star,
            color: Colors.white,
          ),
        ),
        title: Text(
          content['title'] ?? 'Untitled',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content['description'] ?? ''),
            const SizedBox(height: 4),
            Text(
              'Type: ${TextFormatter.formatCategory(contentType).toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: isActive ? 'deactivate' : 'activate',
              child: ListTile(
                leading: Icon(isActive ? Icons.pause : Icons.play_arrow),
                title: Text(isActive ? 'Deactivate' : 'Activate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) => _handleFeaturedContentAction(value, content),
        ),
      ),
    );
  }

  // Action handlers
  void _handleContentPageAction(String action, Map<String, dynamic> page) {
    switch (action) {
      case 'edit':
        _showContentPageDialog(page: page);
        break;
      case 'publish':
        _toggleContentPagePublish(page, true);
        break;
      case 'unpublish':
        _toggleContentPagePublish(page, false);
        break;
      case 'delete':
        _deleteContentPage(page);
        break;
    }
  }

  void _handleAnnouncementAction(String action, Map<String, dynamic> announcement) {
    switch (action) {
      case 'edit':
        _showAnnouncementDialog(announcement: announcement);
        break;
      case 'activate':
        _toggleAnnouncementActive(announcement, true);
        break;
      case 'deactivate':
        _toggleAnnouncementActive(announcement, false);
        break;
      case 'delete':
        _deleteAnnouncement(announcement);
        break;
    }
  }

  void _handleAppSettingAction(String action, Map<String, dynamic> setting) {
    switch (action) {
      case 'edit':
        _showAppSettingDialog(setting: setting);
        break;
      case 'delete':
        _deleteAppSetting(setting);
        break;
    }
  }

  void _handleFeaturedContentAction(String action, Map<String, dynamic> content) {
    switch (action) {
      case 'edit':
        _showFeaturedContentDialog(content: content);
        break;
      case 'activate':
        _toggleFeaturedContentActive(content, true);
        break;
      case 'deactivate':
        _toggleFeaturedContentActive(content, false);
        break;
      case 'delete':
        _deleteFeaturedContent(content);
        break;
    }
  }

  // Dialog methods (placeholder implementations)
  void _showContentPageDialog({Map<String, dynamic>? page}) {
    ToastUtils.showInfo('Content page editor coming soon');
  }

  void _showAnnouncementDialog({Map<String, dynamic>? announcement}) {
    ToastUtils.showInfo('Announcement editor coming soon');
  }

  void _showAppSettingDialog({Map<String, dynamic>? setting}) {
    ToastUtils.showInfo('App setting editor coming soon');
  }

  void _showFeaturedContentDialog({Map<String, dynamic>? content}) {
    ToastUtils.showInfo('Featured content editor coming soon');
  }

  // Database operations (placeholder implementations)
  Future<void> _toggleContentPagePublish(Map<String, dynamic> page, bool publish) async {
    try {
      await _supabaseService.client
          .from('content_pages')
          .update({
            'is_published': publish,
            'publish_date': publish ? DateTime.now().toIso8601String() : null,
          })
          .eq('id', page['id']);
      
      ToastUtils.showSuccess('Page ${publish ? 'published' : 'unpublished'} successfully');
      _loadContentPages();
    } catch (e) {
      ToastUtils.showError('Error updating page: $e');
    }
  }

  Future<void> _toggleAnnouncementActive(Map<String, dynamic> announcement, bool active) async {
    try {
      await _supabaseService.client
          .from('announcements')
          .update({'is_active': active})
          .eq('id', announcement['id']);
      
      ToastUtils.showSuccess('Announcement ${active ? 'activated' : 'deactivated'} successfully');
      _loadAnnouncements();
    } catch (e) {
      ToastUtils.showError('Error updating announcement: $e');
    }
  }

  Future<void> _toggleFeaturedContentActive(Map<String, dynamic> content, bool active) async {
    try {
      await _supabaseService.client
          .from('featured_content')
          .update({'is_active': active})
          .eq('id', content['id']);
      
      ToastUtils.showSuccess('Featured content ${active ? 'activated' : 'deactivated'} successfully');
      _loadFeaturedContent();
    } catch (e) {
      ToastUtils.showError('Error updating featured content: $e');
    }
  }

  Future<void> _deleteContentPage(Map<String, dynamic> page) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Content Page'),
        content: Text('Are you sure you want to delete "${page['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.client
            .from('content_pages')
            .delete()
            .eq('id', page['id']);
        
        ToastUtils.showSuccess('Content page deleted successfully');
        _loadContentPages();
      } catch (e) {
        ToastUtils.showError('Error deleting page: $e');
      }
    }
  }

  Future<void> _deleteAnnouncement(Map<String, dynamic> announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text('Are you sure you want to delete "${announcement['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.client
            .from('announcements')
            .delete()
            .eq('id', announcement['id']);
        
        ToastUtils.showSuccess('Announcement deleted successfully');
        _loadAnnouncements();
      } catch (e) {
        ToastUtils.showError('Error deleting announcement: $e');
      }
    }
  }

  Future<void> _deleteAppSetting(Map<String, dynamic> setting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete App Setting'),
        content: Text('Are you sure you want to delete "${setting['key']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.client
            .from('app_settings')
            .delete()
            .eq('id', setting['id']);
        
        ToastUtils.showSuccess('App setting deleted successfully');
        _loadAppSettings();
      } catch (e) {
        ToastUtils.showError('Error deleting setting: $e');
      }
    }
  }

  Future<void> _deleteFeaturedContent(Map<String, dynamic> content) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Featured Content'),
        content: Text('Are you sure you want to delete "${content['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.client
            .from('featured_content')
            .delete()
            .eq('id', content['id']);
        
        ToastUtils.showSuccess('Featured content deleted successfully');
        _loadFeaturedContent();
      } catch (e) {
        ToastUtils.showError('Error deleting featured content: $e');
      }
    }
  }
}



