import 'dart:convert';
import '../../utils/appwrite_id_utils.dart';
import 'package:flutter/material.dart';
import '../../services/appwrite_facade.dart';
import 'package:intl/intl.dart';
import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/toast_utils.dart';
import '../../utils/text_formatter.dart';
import '../../utils/layout_fix_utils.dart';
import '../../utils/project_sync_bridge.dart';
import '../../widgets/custom_app_bar.dart';

class ContentManagementScreen extends StatefulWidget {
  final String? contentType;

  const ContentManagementScreen({
    super.key,
    this.contentType,
  });

  @override
  State<ContentManagementScreen> createState() =>
      _ContentManagementScreenState();
}

class _ContentManagementScreenState extends State<ContentManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TablesDB _tables = TablesDB(appwriteClient);

  bool _isLoading = false;
  List<Map<String, dynamic>> _contentPages = List.from(_defaultContentPages);
  List<Map<String, dynamic>> _projects = List.from(_defaultProjects);

  static final List<Map<String, dynamic>> _defaultContentPages = [
    {
      'id': 'page_about_alive',
      'title': 'About ALIVE Nigeria',
      'slug': 'about-alive',
      'language': 'en',
      'is_published': true,
      'publish_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'content':
          'A.L.I.V.E is an acronym for Africans Living In View of Eternity. ALIVE-Nigeria is the Nigerian chapter of this movement, committed to a Bible-based, youth-led revival across Africa.\n\nWe are men, women, graduates, working professionals, and student volunteers whose hearts are burdened for spreading God\'s Word and works. ALIVE Nigeria exists to challenge and equip believers with tools for individual missionary work, spiritual growth, mentorship, and service.\n\n"The Lord has appointed the youth to be His helping hand." — {ChS 30.1}\n\n"With such an army of workers as our youth, rightly trained, how soon the message of a crucified, risen, and soon-coming Saviour might be carried to the whole world." — Education, p. 271. {ChS 30.2}\n\nJoin us today and let us take the good news of the Gospel to places where no one wants to go.',
    },
    {
      'id': 'page_mission_vision',
      'title': 'Mission & Vision Statement',
      'slug': 'mission-vision',
      'language': 'en',
      'is_published': true,
      'publish_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'content':
          'MISSION STATEMENT:\nOur mission is to prepare Africa for the imminent return of Jesus Christ. Through biblical spiritual training and evangelistic efforts, we challenge African Seventh-day Adventist young adults to live with authentic biblical excellence, develop a missionary volunteer spirit, support missionary movements across Africa, and make meaningful impact in neglected areas.\n\nVISION STATEMENT:\nAt ALIVE, our vision is to ignite and sustain a Bible-based, youth-led revival movement across the continent of Africa, empowering every Seventh-day Adventist young professional to become a dedicated missionary with a deep personal relationship with Jesus Christ and commitment to His Great Commission.',
    },
    {
      'id': 'page_what_alive_emphasizes',
      'title': 'What ALIVE Emphasizes',
      'slug': 'what-alive-emphasizes',
      'language': 'en',
      'is_published': true,
      'publish_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'content':
          'ALIVE Nigeria emphasizes four core pillars of ministry:\n\n1. Evangelism: Taking the Gospel seriously and making outreach part of everyday ministry life.\n2. Discipleship: Helping people mature in Scripture, character, and practical obedience to Christ.\n3. Prayer and Care: Supporting members spiritually while building a culture of intercession and encouragement.\n4. Wholesome Living: Promoting healthy, balanced living that reflects stewardship of body, mind, and mission (health evangelism and plant-based nutrition).',
    },
    {
      'id': 'page_onboarding',
      'title': 'Welcome to ALIVE Nigeria',
      'slug': 'onboarding',
      'language': 'en',
      'is_published': true,
      'publish_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'content':
          'Welcome to ALIVE Nigeria — Africans Living In View of Eternity. Bible study, prayer, and service in one community.\n\nJoin our vibrant community united by Prayer, Study, Missions, and Health:\n\n• Roles & Organization: We are organized to serve! From dedicated Members and Chapter Leaders to Coordinators, Directors, and Board of Trustees (BOD), every role is vital.\n• Tagging, Praying & Chatting: Stay deeply connected. Tag members, join chapter chats, pray together instantly, and share your powerful testimonies with the community.\n• Kids & Discipleship: A rich library of Books, Tracts, Podcasts, and Health+ recipes awaits you. Plus special mission activities and Bible memorization features for both Kids and Adults.',
    },
    {
      'id': 'page_privacy_policy',
      'title': 'Community Guidelines & Privacy Policy',
      'slug': 'privacy-policy',
      'language': 'en',
      'is_published': true,
      'publish_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'content':
          'ALIVE Nigeria values user trust, spiritual confidentiality, and Christian brotherhood.\n\nPrivate prayer rooms, intercession requests, and personal reflections are protected with role-based and cryptographic boundaries. Chat communication across local chapters, committees, and leadership bodies must reflect Christ-like decorum, mutual respect, and spiritual upliftment.',
    },
    {
      'id': 'page_annual_retreat',
      'title': 'ALIVE Nigeria National Retreat 2026',
      'slug': 'annual-retreat',
      'language': 'en',
      'is_published': true,
      'publish_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'content':
          'Annual gathering of Adventist lay missionaries, working professionals, and students across Nigeria for spiritual revival, mission consecration, and evangelism training.',
    },
    {
      'id': 'page_mission_outreaches',
      'title': 'Campus & Rural Mission Outreaches (STMs & LTMs)',
      'slug': 'mission-outreaches',
      'language': 'en',
      'is_published': true,
      'publish_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'content':
          'Deploying Short-Term Missionaries (STMs) and Long-Term Missionaries (LTMs) to unreached campus territories and rural outposts across Nigeria.',
    },
    {
      'id': 'page_health_plus',
      'title': 'Health+ Plant-Based Living & Remedies',
      'slug': 'health-plus',
      'language': 'en',
      'is_published': true,
      'publish_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'content':
          'Authentic Nigerian plant-based recipes, natural therapeutic remedies, and wholesome living resources reflecting stewardship of body, mind, and mission.',
    },
    {
      'id': 'page_discipleship_daily',
      'title': 'Daily Word & Discipleship Growth',
      'slug': 'discipleship-growth',
      'language': 'en',
      'is_published': true,
      'publish_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'content':
          'Structured Bible study lessons, Daily Tasks, Instant Word memorization games, and spiritual progress tracking for personal and chapter development.',
    },
  ];

  static final List<Map<String, dynamic>> _defaultProjects = [
    {
      'id': 'impact_hub_center',
      'title': 'Impact Hub Center',
      'summary': 'Community discipleship and outreach facility',
      'description':
          'A central hub for training, discipleship, and community engagement. Seed funding has helped prepare the project scope, early planning, and ministry coordination for the hub.',
      'goal': 35000000.0,
      'raised': 8384400.0,
      'currency': 'NGN',
      'status': 'active',
      'priority': 1,
      'cta_label': 'Donate for this item',
      'image_url': 'assets/images/impact_hub_3d_view.png',
      'viewer_url': 'alive_ng_3d_viewer.html',
      'fund_update_title': 'Progress so far',
      'fund_update_text':
          'Seed funding has helped prepare the project scope, early planning, and ministry coordination for the hub.',
      'fund_update_images': <String>[],
    },
    {
      'id': 'vehicle_purchase',
      'title': 'Vehicle Purchase',
      'summary': 'Mission vehicle for outreach logistics',
      'description':
          'Reliable transportation for mission trips and logistics across Nigeria.',
      'goal': 18000000.0,
      'raised': 0.0,
      'currency': 'NGN',
      'status': 'active',
      'priority': 2,
      'cta_label': 'Donate for this item',
      'image_url':
          'https://images.unsplash.com/photo-1597685204565-110abf469a1e?q=80&w=870&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      'fund_update_title': '',
      'fund_update_text': '',
      'fund_update_images': <String>[],
    },
    {
      'id': 'media_studio_setup',
      'title': 'Media Studio Setup',
      'summary': 'Podcast and content production equipment',
      'description':
          'Equipping the ministry with high-quality media production capabilities for tracts, audio podcasts, video meetings, and digital evangelism.',
      'goal': 9000000.0,
      'raised': 0.0,
      'currency': 'NGN',
      'status': 'planning',
      'priority': 3,
      'cta_label': 'Donate for this item',
      'image_url':
          'https://images.unsplash.com/photo-1769699167906-a44d5ae50abb?q=80&w=387&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      'fund_update_title': '',
      'fund_update_text': '',
      'fund_update_images': <String>[],
    },
  ];

  Widget _buildSectionHeader(
      BuildContext context, String title, Widget action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 460;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: LayoutFixUtils.safeText(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ),
                  if (!isNarrow) action,
                ],
              ),
              if (isNarrow) ...[
                const SizedBox(height: 10),
                action,
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllContent();

    // Set initial tab based on content type
    if (widget.contentType == 'projects') {
      _tabController.index = 1;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllContent() async {
    try {
      await Future.wait([
        _loadContentPages(),
        _loadProjects(),
      ]);
    } catch (e) {
      debugPrint('Error loading content: $e');
    }
  }

  Future<void> _loadContentPages() async {
    try {
      final pages = await _listAdminDocuments(
        AppwriteBackendConfig.contentPagesCollectionId,
      );
      if (!mounted) return;
      setState(() {
        _contentPages =
            pages.isNotEmpty ? pages : List.from(_defaultContentPages);
      });
      if (pages.isEmpty) {
        _seedSamplePages();
      }
    } catch (e) {
      debugPrint('Error loading content pages: $e');
      if (mounted) {
        setState(() {
          _contentPages = List.from(_defaultContentPages);
        });
      }
    }
  }

  Future<void> _seedSamplePages() async {
    try {
      for (var page in _defaultContentPages) {
        final id = page['id'] as String;
        final data = Map<String, dynamic>.from(page)..remove('id');
        try {
          await _createAdminDocument(
            AppwriteBackendConfig.contentPagesCollectionId,
            data,
            documentId: id,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error seeding sample pages: $e');
    }
  }

  void _broadcastProjectsSync() {
    try {
      final jsonString = jsonEncode(_projects);
      syncProjectsToWeb(jsonString);
    } catch (e) {
      debugPrint('Error syncing projects to web: $e');
    }
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _listAdminDocuments(
        AppwriteBackendConfig.projectsCollectionId,
        queries: [Query.orderAsc('priority'), Query.limit(100)],
      );
      if (!mounted) return;
      setState(() {
        _projects = projects.isNotEmpty ? projects : List.from(_defaultProjects);
      });
      _broadcastProjectsSync();
      if (projects.isEmpty) {
        _seedSampleProjects(showDialog: false);
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
      if (mounted) {
        setState(() {
          _projects = List.from(_defaultProjects);
        });
        _broadcastProjectsSync();
      }
    }
  }

  Future<List<Map<String, dynamic>>> _listAdminDocuments(
    String collectionId, {
    List<String> queries = const [],
  }) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      queries: queries,
    );
    return response.rows
        .map((row) => {...Map<String, dynamic>.from(row.data), 'id': row.$id})
        .toList();
  }

  Future<void> _createAdminDocument(
    String collectionId,
    Map<String, dynamic> data, {
    String? documentId,
  }) async {
    await _tables.createRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      rowId: AppwriteIdUtils.toValidUid(documentId),
      data: data,
    );
  }

  Future<void> _upsertAdminDocument(
    String collectionId,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: collectionId,
        rowId: AppwriteIdUtils.toValidUid(documentId),
        data: data,
      );
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
      await _createAdminDocument(collectionId, data, documentId: documentId);
    }
  }

  Future<void> _updateAdminDocument(
    String collectionId,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    await _tables.updateRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      rowId: AppwriteIdUtils.toValidUid(documentId),
      data: data,
    );
  }

  Future<void> _deleteAdminDocument(
    String collectionId,
    String documentId,
  ) async {
    await _tables.deleteRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      rowId: AppwriteIdUtils.toValidUid(documentId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoleVisibility(
      allowedRoles: const [
        'admin',
        'super_admin',
        'content_manager',
        'director',
        'president',
      ],
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Content Management',
          showBackButton: true,
          showDonationButton: false,
          bottom: TabBar(
            controller: _tabController,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Content Pages', icon: Icon(Icons.article_outlined, size: 20)),
              Tab(text: 'Projects', icon: Icon(Icons.account_tree_outlined, size: 20)),
            ],
          ),
        ),
        body: _isLoading
            ? const LoadingWidget()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildContentPagesTab(),
                  _buildProjectsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildContentPagesTab() {
    return LayoutFixUtils.safeColumn(
      children: [
        _buildSectionHeader(
          context,
          'Content Pages (${_contentPages.length})',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showContentPageDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Page', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _editOnboardingPage,
                icon: const Icon(Icons.flag, size: 16),
                label: const Text('Edit Onboarding', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
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

  void _editOnboardingPage() {
    try {
      final page = _contentPages.firstWhere(
        (p) => (p['slug'] as String?) == 'onboarding',
        orElse: () => {},
      );
      if (page.isNotEmpty) {
        _showContentPageDialog(page: page);
      } else {
        _showContentPageDialog();
      }
    } catch (_) {
      _showContentPageDialog();
    }
  }

  Widget _buildContentPageCard(Map<String, dynamic> page) {
    final isPublished = page['is_published'] ?? false;
    final publishDate = page['publish_date'] != null
        ? DateTime.parse(page['publish_date'])
        : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPublished
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.secondary,
          child: Icon(
            isPublished ? Icons.public : Icons.drafts,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        title: Text(
          page['title'] ?? 'Untitled',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: LayoutFixUtils.safeColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutFixUtils.safeText(page['slug'] ?? ''),
            const SizedBox(height: 4),
            LayoutFixUtils.safeText(
              isPublished
                  ? 'Published${publishDate != null ? ' on ${publishDate.day}/${publishDate.month}/${publishDate.year}' : ''}'
                  : 'Draft',
              style: TextStyle(
                color: isPublished
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w500,
              ),
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
              value: isPublished ? 'unpublish' : 'publish',
              child: ListTile(
                leading:
                    Icon(isPublished ? Icons.visibility_off : Icons.visibility),
                title: Text(isPublished ? 'Unpublish' : 'Publish'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text('Delete',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) => _handleContentPageAction(value, page),
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

  // Dialog methods (placeholder implementations)
  void _showContentPageDialog({Map<String, dynamic>? page}) {
    final isEditing = page != null && page.isNotEmpty;
    final titleController =
        TextEditingController(text: page?['title'] ?? 'Onboarding');
    final slugController =
        TextEditingController(text: page?['slug'] ?? 'onboarding');
    final contentController =
        TextEditingController(text: page?['content'] ?? '');
    String selectedLanguage =
        (page?['language'] ?? page?['language_code'] ?? 'en').toString();
    if (!['en', 'yo', 'ha', 'ig'].contains(selectedLanguage)) {
      selectedLanguage = 'en';
    }
    bool isPublished = page?['is_published'] ?? false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Edit Content Page' : 'Create Content Page',
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        onChanged: (val) {
                          if (!isEditing) {
                            slugController.text = val
                                .toLowerCase()
                                .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
                                .replaceAll(RegExp(r'\s+'), '-')
                                .replaceAll(RegExp(r'-+'), '-')
                                .trim();
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(
                          labelText: 'Slug',
                          hintText: 'onboarding',
                          prefixIcon: Icon(Icons.link),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Language',
                          prefixIcon: Icon(Icons.language),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English (en)')),
                          DropdownMenuItem(value: 'yo', child: Text('Yorùbá (yo)')),
                          DropdownMenuItem(value: 'ha', child: Text('Hausa (ha)')),
                          DropdownMenuItem(value: 'ig', child: Text('Igbo (ig)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedLanguage = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: contentController,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Content',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isPublished,
                        onChanged: (v) => setDialogState(() => isPublished = v),
                        title: const Text('Published'),
                        subtitle: Text(
                          isPublished
                              ? 'Visible to app users'
                              : 'Saved as draft (hidden)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: () async {
                    final payload = {
                      'title': titleController.text.trim(),
                      'slug': slugController.text.trim(),
                      'language': selectedLanguage,
                      'language_code': selectedLanguage,
                      'content': contentController.text.trim(),
                      'is_published': isPublished,
                      'updated_at': DateTime.now().toIso8601String(),
                    };

                    setState(() {
                      if (isEditing) {
                        final idx = _contentPages
                            .indexWhere((p) => p['id'] == page['id']);
                        if (idx != -1) {
                          _contentPages[idx] = {
                            ..._contentPages[idx],
                            ...payload
                          };
                        }
                      } else {
                        _contentPages.insert(0, {
                          ...payload,
                          'id': 'page_${DateTime.now().millisecondsSinceEpoch}',
                          'created_at': DateTime.now().toIso8601String(),
                        });
                      }
                    });

                    try {
                      if (isEditing) {
                        await _updateAdminDocument(
                          AppwriteBackendConfig.contentPagesCollectionId,
                          page['id'],
                          payload,
                        );
                        ToastUtils.showSuccess('Content page updated');
                      } else {
                        await _createAdminDocument(
                          AppwriteBackendConfig.contentPagesCollectionId,
                          {
                            ...payload,
                            'created_at': DateTime.now().toIso8601String(),
                          },
                        );
                        ToastUtils.showSuccess('Content page created');
                      }
                      if (!mounted) return;
                      Navigator.of(context).pop();
                    } catch (e) {
                      debugPrint('Note: local page saved, Appwrite sync: $e');
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ToastUtils.showSuccess(
                          isEditing ? 'Content page updated' : 'Content page created');
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleContentPagePublish(
      Map<String, dynamic> page, bool publish) async {
    final id = page['id'];
    setState(() {
      final idx = _contentPages.indexWhere((p) => p['id'] == id);
      if (idx != -1) {
        _contentPages[idx] = {
          ..._contentPages[idx],
          'is_published': publish,
          'status': publish ? 'published' : 'draft',
        };
      }
    });
    try {
      await _updateAdminDocument(
        AppwriteBackendConfig.contentPagesCollectionId,
        id,
        {
          'is_published': publish,
          'status': publish ? 'published' : 'draft',
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      ToastUtils.showSuccess(
        publish ? 'Page published' : 'Page unpublished',
      );
    } catch (e) {
      debugPrint('Note: local page updated, Appwrite sync: $e');
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
      final id = page['id'];
      setState(() {
        _contentPages.removeWhere((p) => p['id'] == id);
      });
      try {
        await _deleteAdminDocument(
          AppwriteBackendConfig.contentPagesCollectionId,
          id,
        );
      } catch (e) {
        debugPrint('Note: local page removed, Appwrite sync: $e');
      }
      ToastUtils.showSuccess('Content page deleted successfully');
    }
  }

  Widget _buildProjectsTab() {
    return LayoutFixUtils.safeColumn(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              LayoutFixUtils.safeText(
                'Projects (${_projects.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showProjectDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _projects.isEmpty
              ? const Center(
                  child: Text(
                    'No projects found.\nCreate your first project!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return _buildProjectCard(project);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final goal = (project['goal'] ?? 0).toDouble();
    final raised = (project['raised'] ?? 0).toDouble();
    final percent = goal > 0 ? (raised / goal).clamp(0.0, 1.0) : 0.0;
    final status = project['status'] ?? 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: status == 'active' ? Colors.green : Colors.orange,
          child: const Icon(Icons.account_tree, color: Colors.white),
        ),
        title: Text(
          project['title'] ?? 'Untitled Project',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project['summary'] ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Raised: ${NumberFormat.simpleCurrency(name: 'NGN').format(raised)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Goal: ${NumberFormat.simpleCurrency(name: 'NGN').format(goal)}',
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
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) async {
            if (value == 'edit') {
              _showProjectDialog(project: project);
            } else if (value == 'delete') {
              _deleteProject(project);
            }
          },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Description:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(project['description'] ?? 'No description provided.'),
                const SizedBox(height: 12),
                if (project['image_url'] != null) ...[
                  const Text('Image URL:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(project['image_url'],
                      style: const TextStyle(fontSize: 12, color: Colors.blue)),
                ],
                if ((project['fund_update_title'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty ||
                    (project['fund_update_text'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Fund update:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  if ((project['fund_update_title'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)
                    Text(project['fund_update_title'].toString()),
                  if ((project['fund_update_text'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)
                    Text(project['fund_update_text'].toString()),
                ],
                if (_projectImageList(project['fund_update_images'])
                    .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_projectImageList(project['fund_update_images']).length} fund update image(s)',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Status: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    _buildStatusBadge(status),
                    const Spacer(),
                    const Text('Priority: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${project['priority'] ?? 100}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.green;
        break;
      case 'planning':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _showProjectDialog({Map<String, dynamic>? project}) async {
    final isEditing = project != null;
    final titleController =
        TextEditingController(text: project?['title'] ?? '');
    final summaryController =
        TextEditingController(text: project?['summary'] ?? '');
    final descriptionController =
        TextEditingController(text: project?['description'] ?? '');
    final goalController =
        TextEditingController(text: (project?['goal'] ?? 0).toString());
    final raisedController =
        TextEditingController(text: (project?['raised'] ?? 0).toString());
    final imageUrlController =
        TextEditingController(text: project?['image_url'] ?? '');
    final fundUpdateTitleController =
        TextEditingController(text: project?['fund_update_title'] ?? '');
    final fundUpdateTextController =
        TextEditingController(text: project?['fund_update_text'] ?? '');
    final fundUpdateImagesController = TextEditingController(
      text: _projectImageList(project?['fund_update_images']).join('\n'),
    );
    final priorityController =
        TextEditingController(text: (project?['priority'] ?? 100).toString());
    String status = project?['status'] ?? 'active';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Project' : 'New Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration:
                      const InputDecoration(labelText: 'Project Title *'),
                ),
                TextField(
                  controller: summaryController,
                  decoration: const InputDecoration(labelText: 'Short Summary'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration:
                      const InputDecoration(labelText: 'Full Description'),
                  maxLines: 3,
                ),
                TextField(
                  controller: goalController,
                  decoration:
                      const InputDecoration(labelText: 'Goal Amount (NGN)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: raisedController,
                  decoration: const InputDecoration(
                    labelText: 'Amount Raised (NGN)',
                    helperText:
                        'Total raised (Paystack auto checkout + direct bank transfers)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                ),
                TextField(
                  controller: fundUpdateTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Fund update title',
                    hintText: 'What has been done so far?',
                  ),
                ),
                TextField(
                  controller: fundUpdateTextController,
                  decoration: const InputDecoration(
                    labelText: 'Fund update text',
                    hintText:
                        'Explain what the received funds have helped accomplish.',
                  ),
                  maxLines: 4,
                ),
                TextField(
                  controller: fundUpdateImagesController,
                  decoration: const InputDecoration(
                    labelText: 'Fund update image URLs',
                    hintText: 'One image URL per line, maximum 10 images',
                  ),
                  maxLines: 5,
                ),
                TextField(
                  controller: priorityController,
                  decoration:
                      const InputDecoration(labelText: 'Priority (ascending)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['active', 'planning', 'completed']
                      .map((s) => DropdownMenuItem(
                          value: s, child: Text(TextFormatter.formatText(s))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => status = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isEmpty) {
                  ToastUtils.showError('Title is required');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final fundUpdateImages =
          _projectImageList(fundUpdateImagesController.text).take(10).toList();
      final projectData = {
        'title': titleController.text,
        'summary': summaryController.text,
        'description': descriptionController.text,
        'goal': double.tryParse(goalController.text) ?? 0,
        'target_amount': double.tryParse(goalController.text) ?? 0,
        'raised': double.tryParse(raisedController.text) ?? 0,
        'amount_raised': double.tryParse(raisedController.text) ?? 0,
        'image_url': imageUrlController.text,
        'fund_update_title': fundUpdateTitleController.text,
        'fund_update_text': fundUpdateTextController.text,
        'fund_update_images': fundUpdateImages,
        if (fundUpdateTitleController.text.trim().isNotEmpty ||
            fundUpdateTextController.text.trim().isNotEmpty ||
            fundUpdateImages.isNotEmpty)
          'fund_update_updated_at': DateTime.now().toIso8601String(),
        'priority': int.tryParse(priorityController.text) ?? 100,
        'status': status,
      };

      setState(() {
        if (isEditing) {
          final idx = _projects.indexWhere((p) => p['id'] == project['id']);
          if (idx != -1) {
            _projects[idx] = {
              ..._projects[idx],
              ...projectData,
              'updated_at': DateTime.now().toIso8601String(),
            };
          }
        } else {
          _projects.insert(0, {
            ...projectData,
            'id': 'proj_${DateTime.now().millisecondsSinceEpoch}',
            'currency': 'NGN',
            'is_active': status == 'active',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      });
      _broadcastProjectsSync();

      try {
        if (isEditing) {
          await _updateAdminDocument(
            AppwriteBackendConfig.projectsCollectionId,
            project['id'],
            {
              ...projectData,
              'updated_at': DateTime.now().toIso8601String(),
            },
          );
          ToastUtils.showSuccess('Project updated successfully');
        } else {
          await _createAdminDocument(
            AppwriteBackendConfig.projectsCollectionId,
            {
              ...projectData,
              'currency': 'NGN',
              'is_active': status == 'active',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          );
          ToastUtils.showSuccess('Project created successfully');
        }
      } catch (e) {
        debugPrint('Note: local project saved, Appwrite sync: $e');
        ToastUtils.showSuccess(
            isEditing ? 'Project updated successfully' : 'Project created successfully');
      }
    }
  }

  List<String> _projectImageList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(10)
          .toList();
    }
    return value
        .toString()
        .split(RegExp(r'[\r\n,]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(10)
        .toList();
  }

  Future<void> _deleteProject(Map<String, dynamic> project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
            'Are you sure you want to delete "${project['title']}"? This will also affect the donation page.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final id = project['id'];
      setState(() {
        _projects.removeWhere((p) => p['id'] == id);
      });
      _broadcastProjectsSync();
      try {
        await _deleteAdminDocument(
          AppwriteBackendConfig.projectsCollectionId,
          id,
        );
      } catch (e) {
        debugPrint('Note: local project removed, Appwrite sync: $e');
      }
      ToastUtils.showSuccess('Project deleted successfully');
    }
  }

  // Seed template content into Appwrite so the live admin experience owns
  // project content, while the app can still fall back safely when offline.
  Future<void> _seedSampleProjects({bool showDialog = false}) async {
    setState(() => _isLoading = true);
    try {
      for (var project in _defaultProjects) {
        final documentId = project['id']?.toString();
        await _upsertAdminDocument(
          AppwriteBackendConfig.projectsCollectionId,
          documentId ?? ID.unique(),
          {
            ...project,
            'is_active': project['status'] == 'active',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }

      _loadProjects();
    } catch (e) {
      debugPrint('Error seeding projects: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
