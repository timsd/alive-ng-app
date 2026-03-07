import 'package:flutter/material.dart';
import 'config/firebase_config.dart';
import 'config/development_config.dart';
// import 'services/kids_content_service.dart';
import 'screens/admin/admin_preview_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DevelopmentConfig.initializeFromPrefs();
  await FirebaseConfig.initialize();
  // Kids content initialization disabled for admin preview only
  runApp(const AdminPreviewApp());
}

class AdminPreviewApp extends StatelessWidget {
  const AdminPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALIVE-NG APP Admin Page',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AdminPreviewHome(),
    );
  }
}