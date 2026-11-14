import 'dart:convert';
import '../../utils/appwrite_id_utils.dart';
import '../../services/appwrite_facade.dart';
import 'package:flutter/material.dart';
import '../../config/appwrite_backend_config.dart';
import '../../config/payment_config.dart';
import '../../main.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/toast_utils.dart';
import '../../utils/text_formatter.dart';
import '../../widgets/custom_app_bar.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final TablesDB _tables = TablesDB(appwriteClient);

  bool _isLoading = true;
  final Map<String, List<Map<String, dynamic>>> _settingsByCategory = {};
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _visibleSecretKeys = {};
  Map<String, dynamic>? _paystackTestModeSetting;

  static const Set<String> _hiddenInternalKeys = {
    'paystack_test_mode',
    'paystack_public_key',
    'paystack_secret_key',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Map<String, dynamic>? _findSettingByKey(String key) {
    if (key == 'paystack_test_mode' && _paystackTestModeSetting != null) {
      return _paystackTestModeSetting;
    }
    for (final categorySettings in _settingsByCategory.values) {
      for (final setting in categorySettings) {
        if (_settingKey(setting) == key) {
          return setting;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final settings = await _listSettings();

      // Group settings by category
      _settingsByCategory.clear();
      _controllers.clear();
      _paystackTestModeSetting = null;

      for (final setting in settings) {
        final key = _settingKey(setting);
        final val = _settingValue(setting).trim();

        // Sync live PaymentConfig state from loaded settings
        if (key == 'paystack_test_mode') {
          _paystackTestModeSetting = setting;
          PaymentConfig.setTestMode(val.toLowerCase() == 'true');
        } else if (key == 'paystack_live_public_key' && val.startsWith('pk_live_')) {
          PaymentConfig.setModePublicKey(isTest: false, key: val);
        } else if (key == 'paystack_test_public_key' && val.startsWith('pk_test_')) {
          PaymentConfig.setModePublicKey(isTest: true, key: val);
        }

        // Hide internal/duplicate Paystack keys since the top Paystack card and
        // the 4 canonical Live/Test Public/Secret key rows handle them cleanly.
        if (_hiddenInternalKeys.contains(key)) {
          continue;
        }

        final category = _resolveCategoryForSetting(setting, key);
        if (!_settingsByCategory.containsKey(category)) {
          _settingsByCategory[category] = [];
        }
        _settingsByCategory[category]!.add(setting);

        // Create controller for each setting
        _controllers[key] = TextEditingController(
          text: val,
        );
      }
    } catch (e) {
      ToastUtils.showError('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _resolveCategoryForSetting(Map<String, dynamic> setting, String key) {
    final raw = setting['category']?.toString().trim() ?? '';
    if (raw.isNotEmpty) return raw;
    if (key == 'monthly_reminder') return 'notification';
    if (key.startsWith('paystack_')) return 'payment';
    if (key == 'app_version') return 'system';
    return 'app';
  }

  Future<List<Map<String, dynamic>>> _listSettings() async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.appSettingsCollectionId,
      queries: [
        Query.orderAsc('category'),
        Query.limit(200),
      ],
    );
    return response.rows
        .map((row) => {...Map<String, dynamic>.from(row.data), 'id': row.$id})
        .toList();
  }

  Future<void> _createSetting(Map<String, dynamic> data) async {
    final key = data['setting_key']?.toString() ?? data['key']?.toString();
    await _tables.createRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.appSettingsCollectionId,
      rowId: AppwriteIdUtils.toValidUid(key, prefix: 'st'),
      data: _normalizeSettingPayload(data),
    );
  }

  Future<void> _updateSetting(
      String documentId, Map<String, dynamic> data) async {
    await _tables.updateRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.appSettingsCollectionId,
      rowId: AppwriteIdUtils.toValidUid(documentId, prefix: 'st'),
      data: _normalizeSettingPayload(data),
    );
  }

  Future<void> _deleteSettingDocument(String documentId) async {
    await _tables.deleteRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.appSettingsCollectionId,
      rowId: AppwriteIdUtils.toValidUid(documentId, prefix: 'st'),
    );
  }

  Map<String, dynamic> _normalizeSettingPayload(Map<String, dynamic> data) {
    final key = data['setting_key']?.toString() ?? data['key']?.toString();
    final type = data['data_type']?.toString() ?? data['type']?.toString();
    final hasValue =
        data.containsKey('setting_value') || data.containsKey('value');
    final value =
        data['setting_value']?.toString() ?? data['value']?.toString() ?? '';
    return {
      ...data,
      if (key != null) 'key': key,
      if (key != null) 'setting_key': key,
      if (type != null) 'type': type,
      if (type != null) 'data_type': type,
      if (hasValue) 'value': value,
      if (hasValue) 'setting_value': value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  String _settingKey(Map<String, dynamic> setting) =>
      setting['setting_key']?.toString() ?? setting['key']?.toString() ?? '';

  String _settingValue(Map<String, dynamic> setting) =>
      setting['setting_value']?.toString() ??
      setting['value']?.toString() ??
      '';

  String _settingDataType(Map<String, dynamic> setting) =>
      setting['data_type']?.toString() ?? setting['type']?.toString() ?? 'string';

  @override
  Widget build(BuildContext context) {
    return RoleVisibility(
      allowedRoles: const ['admin', 'super_admin'],
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'App Settings',
          showBackButton: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddSettingDialog,
              tooltip: 'Add Setting',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSettings,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _isLoading
            ? const LoadingWidget()
            : _settingsByCategory.isEmpty
                ? _buildEmptyState()
                : _buildSettingsList(),
        floatingActionButton: FloatingActionButton(
          onPressed: _saveAllSettings,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          tooltip: 'Save All Changes',
          child: const Icon(Icons.save),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No Settings Found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first app setting to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddSettingDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Setting'),
            style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paystack Mode Toggle Card
          _buildPaystackModeCard(),

          // Settings by category
          ..._settingsByCategory.entries.map((entry) {
            return _buildCategorySection(entry.key, entry.value);
          }),
          
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildPaystackModeCard() {
    final isTest = PaymentConfig.isTestMode;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isTest ? Colors.orange.shade300 : Colors.green.shade300,
          width: 1.5,
        ),
      ),
      color: isTest
          ? Colors.orange.withValues(alpha: 0.06)
          : Colors.green.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isTest ? Colors.orange : Colors.green,
                  radius: 18,
                  child: Icon(
                    isTest ? Icons.bug_report_rounded : Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTest ? 'Paystack: Test Sandbox Mode' : 'Paystack: Live Production Mode',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTest
                            ? 'Test payments active. Transactions are tagged as test records and do not affect live church finances.'
                            : 'Live payments active. Real donor contributions are processed and recorded to official ministry finances.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isTest,
                  activeThumbColor: Colors.orange,
                  onChanged: (val) => _togglePaystackTestMode(val),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Active Public Key: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      PaymentConfig.paystackPublicKey.isEmpty
                          ? '(Not configured)'
                          : PaymentConfig.paystackPublicKey,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePaystackTestMode(bool enableTest) async {
    try {
      PaymentConfig.setTestMode(enableTest);
      setState(() {});

      final setting = _findSettingByKey('paystack_test_mode');
      if (setting != null) {
        await _updateSetting(setting['id'], {
          'setting_value': enableTest ? 'true' : 'false',
          'value': enableTest ? 'true' : 'false',
        });
      } else {
        await _createSetting({
          'key': 'paystack_test_mode',
          'setting_key': 'paystack_test_mode',
          'value': enableTest ? 'true' : 'false',
          'setting_value': enableTest ? 'true' : 'false',
          'category': 'payment',
          'data_type': 'boolean',
          'display_name': 'Paystack Test Mode',
          'description': 'Toggle between Paystack Test sandbox and Live production keys',
          'is_active': true,
        });
      }

      ToastUtils.showSuccess(
        enableTest ? 'Switched to Paystack Test Mode' : 'Switched to Paystack Live Production Mode',
      );
      await _loadSettings();
    } catch (e) {
      ToastUtils.showError('Failed to update Paystack mode: $e');
    }
  }

  Widget _buildCategorySection(String category, List<Map<String, dynamic>> settings) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCategoryIcon(category),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  TextFormatter.formatCategory(category).toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${settings.length} setting${settings.length != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...settings.map((setting) => _buildSettingItem(setting)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(Map<String, dynamic> setting) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final key = _settingKey(setting);
    final dataType = _settingDataType(setting);
    final isActive = setting['is_active'] as bool? ?? true;
    final displayName = (setting['display_name'] ?? key).toString();
    final description = setting['description'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: isActive
              ? colorScheme.outlineVariant.withValues(alpha: 0.6)
              : colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        color: isActive
            ? colorScheme.surface
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Horizontal title row with compact data type badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getDataTypeColor(dataType, theme.brightness == Brightness.dark),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dataType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: _getDataTypeTextColor(dataType, theme.brightness == Brightness.dark),
                  ),
                ),
              ),
            ],
          ),

          // 2. Full-width description spanning horizontally
          if (description != null && description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 3. Full-width input/value editor
          _buildSettingInput(setting, key, dataType, isActive),

          const SizedBox(height: 10),

          // 4. Clean bottom action toolbar (Active status switch + Edit & Delete actions)
          Row(
            children: [
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: isActive,
                  onChanged: (value) => _toggleSettingStatus(setting, value),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Text(
                isActive ? 'Active' : 'Disabled',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.green : colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                icon: const Icon(Icons.edit_outlined, size: 16),
                onPressed: () => _showEditSettingDialog(setting),
                tooltip: 'Edit Setting',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                onPressed: () => _deleteSetting(setting),
                tooltip: 'Delete Setting',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingInput(Map<String, dynamic> setting, String key, String dataType, bool isActive) {
    final controller = _controllers[key]!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 1. Clean human-facing editor for Monthly Reminder (JSON)
    if (key == 'monthly_reminder') {
      bool allowOptOut = false;
      try {
        final decoded = jsonDecode(controller.text);
        if (decoded is Map) {
          allowOptOut = decoded['user_toggle_enabled'] == true;
        }
      } catch (_) {}

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              allowOptOut ? Icons.notifications_active_outlined : Icons.notifications_paused_outlined,
              size: 18,
              color: allowOptOut ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allow Member Opt-Out Toggle',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    allowOptOut
                        ? 'Members can toggle the monthly support reminder on or off in Profile.'
                        : 'Monthly support reminder is managed globally by administration.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: allowOptOut,
              onChanged: isActive
                  ? (val) {
                      setState(() {
                        controller.text = jsonEncode({'user_toggle_enabled': val});
                      });
                    }
                  : null,
            ),
          ],
        ),
      );
    }

    // 2. Clean human-facing editor for Android OTA App Version (JSON)
    if (key == 'app_version') {
      Map<String, dynamic> versionMap = {};
      try {
        final decoded = jsonDecode(controller.text);
        if (decoded is Map) {
          versionMap = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}

      final latestVersion = (versionMap['latest_version'] ?? '2.0.7').toString();
      final buildNumber = (versionMap['build_number'] ?? 15).toString();
      final forceUpdate = versionMap['force_update'] == true;
      final updateUrl = (versionMap['update_url'] ?? '').toString();

      void updateVersionField(String fieldKey, dynamic fieldVal) {
        final next = Map<String, dynamic>.from(versionMap);
        next[fieldKey] = fieldVal;
        controller.text = jsonEncode(next);
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: ValueKey('app_ver_str_${setting['id']}'),
                    initialValue: latestVersion,
                    enabled: isActive,
                    onChanged: (v) => updateVersionField('latest_version', v.trim()),
                    decoration: InputDecoration(
                      labelText: 'Latest Version',
                      hintText: 'e.g. 2.0.9',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: ValueKey('app_ver_bld_${setting['id']}'),
                    initialValue: buildNumber,
                    enabled: isActive,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => updateVersionField('build_number', int.tryParse(v.trim()) ?? 1),
                    decoration: InputDecoration(
                      labelText: 'Build #',
                      hintText: 'e.g. 18',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: ValueKey('app_ver_url_${setting['id']}'),
              initialValue: updateUrl,
              enabled: isActive,
              onChanged: (v) => updateVersionField('update_url', v.trim()),
              decoration: InputDecoration(
                labelText: 'APK Download URL',
                hintText: 'https://...',
                isDense: true,
                prefixIcon: const Icon(Icons.link_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.system_security_update_warning_rounded,
                  size: 16,
                  color: forceUpdate ? Colors.orange : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Require Mandatory Update (Force Update)',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch.adaptive(
                  value: forceUpdate,
                  onChanged: isActive
                      ? (val) {
                          setState(() {
                            updateVersionField('force_update', val);
                          });
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 3. Clean human-facing summary for Discipleship Officer Assignments (JSON Array)
    if (key == 'alive_officer_office_assignments') {
      List<Map<String, dynamic>> assignments = [];
      try {
        final decoded = jsonDecode(controller.text);
        if (decoded is List) {
          assignments = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${assignments.length} Configured Officer Assignment${assignments.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Protected Encoding',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (assignments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: assignments.take(6).map((item) {
                  final name = (item['officer_name'] ?? item['office_title'] ?? 'Officer').toString();
                  final office = (item['office_title'] ?? item['role'] ?? '').toString();
                  final label = office.isNotEmpty && office != name ? '$name • $office' : name;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Officer routing is safely encoded behind the scenes. Manage officer assignments visually in Discipleship Flow.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    switch (dataType) {
      case 'boolean':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  controller.text.toLowerCase() == 'true' ? 'Enabled' : 'Disabled',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Switch.adaptive(
                value: controller.text.toLowerCase() == 'true',
                onChanged: isActive
                    ? (value) {
                        setState(() {
                          controller.text = value.toString();
                        });
                      }
                    : null,
              ),
            ],
          ),
        );

      case 'number':
        return TextFormField(
          controller: controller,
          enabled: isActive,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
        );

      case 'json':
        // Generic structured JSON key-value viewer/editor so raw JSON syntax is protected
        try {
          final decoded = jsonDecode(controller.text);
          if (decoded is Map<String, dynamic>) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: decoded.entries.map((e) {
                  final k = e.key;
                  final v = e.value;
                  if (v is bool) {
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            TextFormatter.formatText(k),
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Switch.adaptive(
                          value: v,
                          onChanged: isActive
                              ? (nextVal) {
                                  setState(() {
                                    final copy = Map<String, dynamic>.from(decoded);
                                    copy[k] = nextVal;
                                    controller.text = jsonEncode(copy);
                                  });
                                }
                              : null,
                        ),
                      ],
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      key: ValueKey('json_${setting['id']}_$k'),
                      initialValue: v?.toString() ?? '',
                      enabled: isActive,
                      onChanged: (nextText) {
                        final copy = Map<String, dynamic>.from(decoded);
                        copy[k] = v is num ? (num.tryParse(nextText) ?? nextText) : nextText;
                        controller.text = jsonEncode(copy);
                      },
                      decoration: InputDecoration(
                        labelText: TextFormatter.formatText(k),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }
        } catch (_) {}
        return TextFormField(
          controller: controller,
          enabled: isActive,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Configuration Value',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
        );

      default: // string
        final isSecret = key.contains('secret') || key.contains('password') || key.contains('token');
        final isRevealed = _visibleSecretKeys.contains(key);
        return TextFormField(
          controller: controller,
          enabled: isActive,
          obscureText: isSecret && !isRevealed,
          style: key.startsWith('paystack_')
              ? const TextStyle(fontFamily: 'monospace', fontSize: 13)
              : null,
          decoration: InputDecoration(
            labelText: isSecret ? 'Secret Key' : 'Value',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
            suffixIcon: isSecret
                ? IconButton(
                    icon: Icon(
                      isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                    ),
                    tooltip: isRevealed ? 'Hide Secret Key' : 'Show Secret Key',
                    onPressed: () {
                      setState(() {
                        if (isRevealed) {
                          _visibleSecretKeys.remove(key);
                        } else {
                          _visibleSecretKeys.add(key);
                        }
                      });
                    },
                  )
                : null,
          ),
        );
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'app':
        return Icons.mobile_friendly;
      case 'notification':
        return Icons.notifications;
      case 'security':
        return Icons.security;
      case 'payment':
        return Icons.payment;
      case 'social':
        return Icons.share;
      case 'api':
        return Icons.api;
      case 'ui':
        return Icons.palette;
      case 'feature':
        return Icons.toggle_on;
      default:
        return Icons.settings;
    }
  }

  Color _getDataTypeColor(String dataType, bool isDark) {
    if (isDark) {
      switch (dataType) {
        case 'boolean':
          return Colors.green.shade900.withValues(alpha: 0.5);
        case 'number':
          return Colors.blue.shade900.withValues(alpha: 0.5);
        case 'json':
          return Colors.orange.shade900.withValues(alpha: 0.5);
        default:
          return Colors.grey.shade800;
      }
    }
    switch (dataType) {
      case 'boolean':
        return Colors.green.shade100;
      case 'number':
        return Colors.blue.shade100;
      case 'json':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getDataTypeTextColor(String dataType, bool isDark) {
    if (isDark) {
      switch (dataType) {
        case 'boolean':
          return Colors.green.shade200;
        case 'number':
          return Colors.blue.shade200;
        case 'json':
          return Colors.orange.shade200;
        default:
          return Colors.grey.shade300;
      }
    }
    switch (dataType) {
      case 'boolean':
        return Colors.green.shade900;
      case 'number':
        return Colors.blue.shade900;
      case 'json':
        return Colors.orange.shade900;
      default:
        return Colors.grey.shade800;
    }
  }

  Future<void> _toggleSettingStatus(Map<String, dynamic> setting, bool isActive) async {
    try {
      await _updateSetting(setting['id'], {
        'is_active': isActive,
      });

      setState(() {
        setting['is_active'] = isActive;
      });

      ToastUtils.showSuccess('Setting ${isActive ? 'activated' : 'deactivated'}');
    } catch (e) {
      ToastUtils.showError('Error updating setting: $e');
    }
  }

  Future<void> _saveAllSettings() async {
    try {
      final updates = <Future>[];
      
      for (final entry in _controllers.entries) {
        final key = entry.key;
        final controller = entry.value;
        final val = controller.text.trim();

        if (key == 'paystack_live_public_key' && val.startsWith('pk_live_')) {
          PaymentConfig.setModePublicKey(isTest: false, key: val);
        } else if (key == 'paystack_test_public_key' && val.startsWith('pk_test_')) {
          PaymentConfig.setModePublicKey(isTest: true, key: val);
        }
        
        // Find the setting by key and update it
        final setting = _findSettingByKey(key);
        if (setting != null) {
          updates.add(
            _updateSetting(setting['id'], {
              'setting_value': val,
              'value': val,
            })
          );
        }
      }
      
      await Future.wait(updates);
      await PaymentConfig.syncPublicKeyFromAppwrite();
      if (mounted) setState(() {});
      ToastUtils.showSuccess('All settings saved and synced in real time');
    } catch (e) {
      ToastUtils.showError('Error saving settings: $e');
    }
  }

  Future<void> _showAddSettingDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _AddSettingDialog(),
    );

    if (result != null) {
      try {
        await _createSetting({
          ...result,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        ToastUtils.showSuccess('Setting added successfully');
        _loadSettings();
      } catch (e) {
        ToastUtils.showError('Error adding setting: $e');
      }
    }
  }

  Future<void> _showEditSettingDialog(Map<String, dynamic> setting) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditSettingDialog(setting: setting),
    );

    if (result != null) {
      try {
        await _updateSetting(setting['id'], result);

        ToastUtils.showSuccess('Setting updated successfully');
        _loadSettings();
      } catch (e) {
        ToastUtils.showError('Error updating setting: $e');
      }
    }
  }

  Future<void> _deleteSetting(Map<String, dynamic> setting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Setting'),
        content: Text('Are you sure you want to delete "${setting['display_name'] ?? _settingKey(setting)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _deleteSettingDocument(setting['id']);

        ToastUtils.showSuccess('Setting deleted successfully');
        _loadSettings();
      } catch (e) {
        ToastUtils.showError('Error deleting setting: $e');
      }
    }
  }
}

class _AddSettingDialog extends StatefulWidget {
  const _AddSettingDialog();

  @override
  State<_AddSettingDialog> createState() => _AddSettingDialogState();
}

class _AddSettingDialogState extends State<_AddSettingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _valueController = TextEditingController();
  
  String _category = 'app';
  String _dataType = 'string';
  
  final List<String> _categories = [
    'app', 'system', 'notification', 'security', 'payment', 'social', 'api', 'ui', 'feature'
  ];
  final List<String> _dataTypes = ['string', 'number', 'boolean', 'json'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add New Setting'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _keyController,
                decoration: InputDecoration(
                  labelText: 'Setting Key *',
                  hintText: 'e.g., max_upload_size',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Setting key is required';
                  }
                  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                    return 'Key can only contain lowercase letters, numbers, and underscores';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Display Name *',
                  hintText: 'e.g., Maximum Upload Size',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of this setting',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _category,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: theme.colorScheme.surfaceContainerHigh,
                menuMaxHeight: 340,
                icon: const Icon(Icons.arrow_drop_down_rounded),
                decoration: InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(TextFormatter.formatCategory(cat)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _dataType,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: theme.colorScheme.surfaceContainerHigh,
                icon: const Icon(Icons.arrow_drop_down_rounded),
                decoration: InputDecoration(
                  labelText: 'Data Type',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _dataTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(TextFormatter.formatText(type)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _dataType = value!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: 'Default Value',
                  hintText: 'Initial value for this setting',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'setting_key': _keyController.text.trim(),
                'display_name': _displayNameController.text.trim(),
                'description': _descriptionController.text.trim().isNotEmpty 
                    ? _descriptionController.text.trim() 
                    : null,
                'category': _category,
                'data_type': _dataType,
                'setting_value': _valueController.text.trim(),
                'is_active': true,
              });
            }
          },
          child: const Text('Add Setting'),
        ),
      ],
    );
  }
}

class _EditSettingDialog extends StatefulWidget {
  final Map<String, dynamic> setting;
  
  const _EditSettingDialog({required this.setting});

  @override
  State<_EditSettingDialog> createState() => _EditSettingDialogState();
}

class _EditSettingDialogState extends State<_EditSettingDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _descriptionController;
  
  late String _category;
  
  final List<String> _categories = [
    'app', 'system', 'notification', 'security', 'payment', 'social', 'api', 'ui', 'feature'
  ];

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.setting['display_name'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.setting['description'] ?? '',
    );
    final rawCat = widget.setting['category']?.toString() ?? 'app';
    _category = _categories.contains(rawCat) ? rawCat : 'app';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit Setting'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Display Name *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _category,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: theme.colorScheme.surfaceContainerHigh,
                menuMaxHeight: 340,
                icon: const Icon(Icons.arrow_drop_down_rounded),
                decoration: InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(TextFormatter.formatCategory(cat)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _category = value!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'display_name': _displayNameController.text.trim(),
                'description': _descriptionController.text.trim().isNotEmpty 
                    ? _descriptionController.text.trim() 
                    : null,
                'category': _category,
              });
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}



