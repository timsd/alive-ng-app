import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/role_guard.dart';
import 'tract_podcast/category_management_tab.dart';
import 'tract_podcast/podcast_management_tab.dart';
import 'tract_podcast/tract_management_tab.dart';

class TractPodcastAdminScreen extends StatefulWidget {
  const TractPodcastAdminScreen({super.key});

  @override
  State<TractPodcastAdminScreen> createState() =>
      _TractPodcastAdminScreenState();
}

class _TractPodcastAdminScreenState extends State<TractPodcastAdminScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoleVisibility(
      allowedRoles: const ['admin', 'super_admin', 'content_manager'],
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Tract & Podcast Management',
          showBackButton: true,
          showDonationButton: false,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(
                icon: Icon(Icons.article),
                text: 'Tracts',
              ),
              Tab(
                icon: Icon(Icons.mic),
                text: 'Podcasts',
              ),
              Tab(
                icon: Icon(Icons.category),
                text: 'Categories',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            TractManagementTab(),
            PodcastManagementTab(),
            CategoryManagementTab(),
          ],
        ),
      ),
    );
  }
}
