// ============================================================
// DEV ADMIN OVERRIDE — FOR DEVELOPMENT/TESTING ONLY
// ============================================================
// To remove: delete this file and remove its import from main.dart
// This code is a no-op in release builds (kDebugMode guard).
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to store the dev admin override flag in SharedPreferences.
/// Checked by the admin auth guard in the app.
const kDevAdminOverrideKey = 'dev_admin_override';

/// Returns true if the dev admin override is active.
/// Always returns false in release mode.
Future<bool> isDevAdminOverrideActive() async {
  if (!kDebugMode) return false;
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kDevAdminOverrideKey) ?? false;
  } catch (_) {
    return false;
  }
}

/// Enables the dev admin override.
Future<void> enableDevAdminOverride() async {
  if (!kDebugMode) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kDevAdminOverrideKey, true);
}

/// Disables the dev admin override.
Future<void> disableDevAdminOverride() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kDevAdminOverrideKey);
}

/// A floating button visible ONLY in debug builds.
/// Place this inside your widget tree (e.g. in main.dart's Stack wrapper).
/// Tap it to toggle admin bypass on/off.
///
/// Usage in main.dart:
///   Stack(children: [
///     child,
///     if (kDebugMode) const DevAdminOverlayButton(),
///   ])
class DevAdminOverlayButton extends StatefulWidget {
  const DevAdminOverlayButton({super.key});

  @override
  State<DevAdminOverlayButton> createState() => _DevAdminOverlayButtonState();
}

class _DevAdminOverlayButtonState extends State<DevAdminOverlayButton> {
  bool _isActive = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final active = await isDevAdminOverrideActive();
    if (mounted) setState(() { _isActive = active; _isLoading = false; });
  }

  Future<void> _toggle() async {
    if (_isActive) {
      await disableDevAdminOverride();
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('🔧 Enable Dev Admin'),
          content: const Text(
            'This grants admin access WITHOUT Firebase claims.\n\n'
            'FOR DEVELOPMENT TESTING ONLY.\n'
            'This button is invisible in release builds.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Enable Dev Admin'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await enableDevAdminOverride();
    }
    await _loadState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isActive
            ? '✅ Dev Admin ENABLED — restart or re-navigate to take effect'
            : '❌ Dev Admin DISABLED'),
        backgroundColor: _isActive ? Colors.orange : Colors.grey[800],
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Invisible in release builds
    if (!kDebugMode || _isLoading) return const SizedBox.shrink();
    return Positioned(
      bottom: 100,
      right: 16,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isActive ? Colors.orange : Colors.grey[800],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isActive ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _isActive ? 'DEV ADMIN ON' : 'DEV ADMIN',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
