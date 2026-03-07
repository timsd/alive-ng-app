import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:alive_flutter_app/config/app_config.dart';
import 'package:go_router/go_router.dart';
import 'package:alive_flutter_app/constants/app_constants.dart';

/// Main navigation shell that wraps routed child content.
class MainNavigationScreen extends StatefulWidget {
  final Widget child;

  const MainNavigationScreen({super.key, required this.child});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final currentLocation =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title:
            Text(AppConfig.isAdminPreviewMode ? 'Admin Preview' : 'ALIVE-NG'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Settings',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            _buildLiveModeToggleDrawerItem(context),
            if (!kReleaseMode) _buildAdminPreviewToggleDrawerItem(context),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: const Text('Prayer Wall'),
              onTap: () => context.go(AppConstants.prayerWallRoute),
            ),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('Testimonies'),
              onTap: () => context.go(AppConstants.testimoniesRoute),
            ),
          ],
        ),
      ),
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getCurrentIndex(currentLocation),
        onTap: (index) => _onItemTapped(context, index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 153 / 255.0),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism_outlined),
            activeIcon: Icon(Icons.volunteer_activism),
            label: 'Prayer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.games_outlined),
            activeIcon: Icon(Icons.games),
            label: 'Bible Game',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Chapters',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildLiveModeToggleDrawerItem(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return SwitchListTile(
          title: const Text('Live Mode'),
          subtitle: const Text('Remove placeholders for production'),
          value: AppConfig.isLiveMode,
          onChanged: (value) {
            AppConfig.toggleLiveMode();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppConfig.isLiveMode
                    ? 'Live mode enabled - placeholders removed'
                    : 'Development mode enabled - placeholders visible'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdminPreviewToggleDrawerItem(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return SwitchListTile(
          title: const Text('Admin Preview'),
          subtitle: const Text('Toggle admin view/user view'),
          value: AppConfig.isAdminPreviewMode,
          onChanged: (value) async {
            final rootCtx = context;
            await AppConfig.toggleAdminPreviewMode();
            setState(() {});
            if (!rootCtx.mounted) return;
            ScaffoldMessenger.of(rootCtx).showSnackBar(
              SnackBar(
                content: Text(AppConfig.isAdminPreviewMode
                    ? 'Admin preview enabled'
                    : 'User view enabled'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }

  int _getCurrentIndex(String location) {
    switch (location) {
      case AppConstants.prayerRoute:
      case AppConstants.prayerWallRoute:
        return 0;
      case AppConstants.bibleGameRoute:
        return 1;
      case AppConstants.homeRoute:
        return 2;
      case AppConstants.chaptersRoute:
        return 3;
      default:
        return 2;
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppConstants.prayerRoute);
        break;
      case 1:
        context.go(AppConstants.bibleGameRoute);
        break;
      case 2:
        context.go(AppConstants.homeRoute);
        break;
      case 3:
        context.go(AppConstants.chaptersRoute);
        break;
      case 4:
        _scaffoldKey.currentState?.openDrawer();
        break;
    }
  }
}
