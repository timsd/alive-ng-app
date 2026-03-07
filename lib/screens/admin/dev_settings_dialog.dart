import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../config/development_config.dart';

class DevSettingsDialog extends StatefulWidget {
  const DevSettingsDialog({super.key});

  @override
  State<DevSettingsDialog> createState() => _DevSettingsDialogState();
}

class _DevSettingsDialogState extends State<DevSettingsDialog> {
  bool _bypassRoleGuards = DevelopmentConfig.shouldBypassRoleGuards;
  bool _adminPreview = DevelopmentConfig.isAdminPreviewEnabled;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Developer Settings'),
      content: kReleaseMode
          ? const Text(
              'Developer settings are disabled in release builds.',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'These toggles only affect non-release builds. They persist across app restarts.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Bypass role guards'),
                  subtitle: const Text('Access role-protected areas without assigned roles'),
                  value: _bypassRoleGuards,
                  onChanged: (v) => setState(() => _bypassRoleGuards = v),
                ),
                SwitchListTile(
                  title: const Text('Enable admin preview'),
                  subtitle: const Text('Show admin-only features for preview'),
                  value: _adminPreview,
                  onChanged: (v) => setState(() => _adminPreview = v),
                ),
                const SizedBox(height: 8),
                Text(
                  DevelopmentConfig.isDevelopmentMode
                      ? 'Development mode: ON'
                      : 'Development mode: OFF',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: DevelopmentConfig.isDevelopmentMode ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await DevelopmentConfig.resetToDefaults();
                  setState(() {
                    _bypassRoleGuards = DevelopmentConfig.shouldBypassRoleGuards;
                    _adminPreview = DevelopmentConfig.isAdminPreviewEnabled;
                    _saving = false;
                  });
                },
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Save'),
          onPressed: kReleaseMode || _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await DevelopmentConfig.setBypassRoleGuards(_bypassRoleGuards);
                  await DevelopmentConfig.setAdminPreviewEnabled(_adminPreview);
                  if (mounted) setState(() => _saving = false);
                  if (context.mounted) Navigator.of(context).pop(true);
                },
        ),
      ],
    );
  }
}