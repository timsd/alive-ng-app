import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import '../../providers/language_provider.dart';
import '../../widgets/custom_app_bar.dart';

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  String? _privacyPolicyContent;
  bool _isLoading = true;
  String? _error;
  bool _needsTranslation = false;
  String? _targetLanguage;

  @override
  void initState() {
    super.initState();
    _loadPrivacyPolicy();
  }

  Future<void> _translateContent() async {
    if (_privacyPolicyContent == null || _targetLanguage == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the translation provider for basic translation
      final translate = ref.read(translationProvider);
      final translated = translate(_privacyPolicyContent!);
      
      if (mounted) {
        setState(() {
          _privacyPolicyContent = translated;
          _needsTranslation = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPrivacyPolicy() async {
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current language from provider
      final currentLocale = ref.read(localeProvider);
      final languageCode = currentLocale.languageCode;
      
      final contentData = await SupabaseService.getContentPageBySlug(
        'privacy-policy', 
        languageCode: languageCode
      );
      
      if (contentData != null && mounted) {
        setState(() {
          _privacyPolicyContent = contentData['content'] ?? 'Privacy policy content not available.';
          _needsTranslation = contentData['needs_translation'] == true;
          _targetLanguage = contentData['target_language'];
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _privacyPolicyContent = 'Privacy policy content not available.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load privacy policy: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Privacy Policy',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrivacyPolicy,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePrivacyPolicy(context),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Privacy Policy',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPrivacyPolicy,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_privacyPolicyContent == null || _privacyPolicyContent!.isEmpty) {
      return const Center(
        child: Text('Privacy policy content not available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Translation banner if needed
          if (_needsTranslation) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.translate, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This content is in English. Tap to translate to your language.',
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                  ),
                  TextButton(
                    onPressed: _translateContent,
                    child: const Text('Translate'),
                  ),
                ],
              ),
            ),
          ],
          
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.privacy_tip,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text(
                  'ALIVE Nigeria Privacy Policy',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Dynamic Content from Database
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            child: Text(
              _privacyPolicyContent!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Contact Information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.contact_support,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Need Help?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'If you have any questions about this Privacy Policy, please contact us at privacy@alivenigeria.org',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sharePrivacyPolicy(BuildContext context) {
    Clipboard.setData(const ClipboardData(
      text: 'Check out ALIVE NG Privacy Policy: https://alive-ng-flutter-app.web.app/privacy-policy.html',
    ));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy Policy link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}



