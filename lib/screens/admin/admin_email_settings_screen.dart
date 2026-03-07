import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/role_access_service.dart';
import '../../services/admin_email_settings_service.dart';

class AdminEmailSettingsScreen extends ConsumerStatefulWidget {
  const AdminEmailSettingsScreen({super.key});

  @override
  ConsumerState<AdminEmailSettingsScreen> createState() => _AdminEmailSettingsScreenState();
}

class _AdminEmailSettingsScreenState extends ConsumerState<AdminEmailSettingsScreen> {
  final RoleAccessService _roles = RoleAccessService.instance;
  final AdminEmailSettingsService _settings = AdminEmailSettingsService.instance;
  final TextEditingController _primaryController = TextEditingController();
  final TextEditingController _ccController = TextEditingController();
  bool _loading = true;
  List<String> _cc = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _settings.getSettings();
    setState(() {
      _primaryController.text = (data['primary'] as String?) ?? AdminEmailSettingsService.defaultPrimaryEmail;
      _cc = (data['cc'] as List?)?.cast<String>() ?? [];
      _loading = false;
    });
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _ccController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAccess = _roles.canAccessAdmin();
    if (!canAccess) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Admin Email Settings', showBackButton: true),
        body: Center(child: Text('Admin access required')),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Admin Email Settings', showBackButton: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Primary Admin Email', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _primaryController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'primary@example.com',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final ctx = context;
                          await _settings
                              .setPrimaryEmail(_primaryController.text.trim());
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Primary email updated'),
                            ),
                          );
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('CC Emails', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ccController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'cc@example.com',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final ctx = context;
                          final email = _ccController.text.trim();
                          if (email.isEmpty) return;
                          await _settings.addCcEmail(email);
                          if (!ctx.mounted) return;
                          setState(() => _cc.add(email));
                          _ccController.clear();
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _cc.length,
                      itemBuilder: (context, index) {
                        final email = _cc[index];
                        return ListTile(
                          title: Text(email),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final ctx = context;
                              await _settings.removeCcEmail(email);
                              if (!ctx.mounted) return;
                              setState(() => _cc.removeAt(index));
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
