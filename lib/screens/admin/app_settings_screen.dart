import 'package:flutter/material.dart';
import '../../services/firebase_database_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/toast_utils.dart';
import '../../utils/text_formatter.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final FirebaseDatabaseService _firebaseService = FirebaseDatabaseService.instance;
  
  bool _isLoading = true;
  final Map<String, List<Map<String, dynamic>>> _settingsByCategory = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Map<String, dynamic>? _findSettingByKey(String key) {
    for (final categorySettings in _settingsByCategory.values) {
      for (final setting in categorySettings) {
        if (setting['setting_key'] == key) {
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
      final settings = await _firebaseService.getCollection('app_settings', orderBy: 'category');
      
      // Group settings by category
      _settingsByCategory.clear();
      _controllers.clear();
      
      for (final setting in settings) {
        final category = setting['category'] as String;
        if (!_settingsByCategory.containsKey(category)) {
          _settingsByCategory[category] = [];
        }
        _settingsByCategory[category]!.add(setting);
        
        // Create controller for each setting
        final key = setting['setting_key'] as String;
        _controllers[key] = TextEditingController(
          text: setting['setting_value']?.toString() ?? '',
        );
      }
    } catch (e) {
      ToastUtils.showError('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleVisibility(
      allowedRoles: const ['admin', 'super_admin'],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('App Settings'),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
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
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          tooltip: 'Save All Changes',
          child: const Icon(Icons.save),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Settings Found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first app setting to get started',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddSettingDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Setting'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
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
          // Settings by category
          ..._settingsByCategory.entries.map((entry) {
            return _buildCategorySection(entry.key, entry.value);
          }),
          
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category, List<Map<String, dynamic>> settings) {
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
                  color: Colors.purple,
                ),
                const SizedBox(width: 8),
                Text(
                  TextFormatter.formatCategory(category).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const Spacer(),
                Text(
                  '${settings.length} setting${settings.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
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
    final key = setting['setting_key'] as String;
    final dataType = setting['data_type'] as String;
    final isActive = setting['is_active'] as bool? ?? true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isActive ? Colors.grey.shade300 : Colors.grey.shade400,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isActive ? null : Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setting['display_name'] ?? key,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isActive ? Colors.black : Colors.grey.shade600,
                      ),
                    ),
                    if (setting['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        setting['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(
                      dataType.toUpperCase(),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: _getDataTypeColor(dataType),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: isActive,
                    onChanged: (value) => _toggleSettingStatus(setting, value),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _showEditSettingDialog(setting),
                    tooltip: 'Edit Setting',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => _deleteSetting(setting),
                    tooltip: 'Delete Setting',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSettingInput(setting, key, dataType, isActive),
        ],
      ),
    );
  }

  Widget _buildSettingInput(Map<String, dynamic> setting, String key, String dataType, bool isActive) {
    final controller = _controllers[key]!;
    
    switch (dataType) {
      case 'boolean':
        return Row(
          children: [
            const Text('Value: '),
            Switch(
              value: controller.text.toLowerCase() == 'true',
              onChanged: isActive ? (value) {
                controller.text = value.toString();
              } : null,
            ),
            Text(controller.text.toLowerCase() == 'true' ? 'Enabled' : 'Disabled'),
          ],
        );
      
      case 'number':
        return TextFormField(
          controller: controller,
          enabled: isActive,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        );
      
      case 'json':
        return TextFormField(
          controller: controller,
          enabled: isActive,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'JSON Value',
            border: OutlineInputBorder(),
            isDense: true,
            helperText: 'Enter valid JSON',
          ),
        );
      
      default: // string
        return TextFormField(
          controller: controller,
          enabled: isActive,
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
            isDense: true,
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

  Color _getDataTypeColor(String dataType) {
    switch (dataType) {
      case 'boolean':
        return Colors.green.shade100;
      case 'number':
        return Colors.blue.shade100;
      case 'json':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Future<void> _toggleSettingStatus(Map<String, dynamic> setting, bool isActive) async {
    try {
      await _firebaseService.updateDocument('app_settings', setting['id'], {
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
        
        // Find the setting by key and update it
        final setting = _findSettingByKey(key);
        if (setting != null) {
          updates.add(
            _firebaseService.updateDocument('app_settings', setting['id'], {
              'setting_value': controller.text,
            })
          );
        }
      }
      
      await Future.wait(updates);
      ToastUtils.showSuccess('All settings saved successfully');
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
        await _firebaseService.createDocument('app_settings', result);

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
        await _firebaseService.updateDocument('app_settings', setting['id'], result);

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
        content: Text('Are you sure you want to delete "${setting['display_name'] ?? setting['setting_key']}"?'),
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
        await _firebaseService.deleteDocument('app_settings', setting['id']);

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
    'app', 'notification', 'security', 'payment', 'social', 'api', 'ui', 'feature'
  ];
  final List<String> _dataTypes = ['string', 'number', 'boolean', 'json'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Setting'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: 'Setting Key *',
                  hintText: 'e.g., max_upload_size',
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name *',
                  hintText: 'e.g., Maximum Upload Size',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of this setting',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(TextFormatter.formatCategory(cat).toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _dataType,
                decoration: const InputDecoration(labelText: 'Data Type'),
                items: _dataTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _dataType = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                decoration: const InputDecoration(
                  labelText: 'Default Value',
                  hintText: 'Initial value for this setting',
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
        ElevatedButton(
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
    'app', 'notification', 'security', 'payment', 'social', 'api', 'ui', 'feature'
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
    _category = widget.setting['category'] ?? 'app';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Setting'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name *',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat.toUpperCase()),
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
        ElevatedButton(
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



