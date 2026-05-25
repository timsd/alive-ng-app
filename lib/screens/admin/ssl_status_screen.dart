import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ssl_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/text_formatter.dart';

class SSLStatusScreen extends ConsumerStatefulWidget {
  const SSLStatusScreen({super.key});

  @override
  ConsumerState<SSLStatusScreen> createState() => _SSLStatusScreenState();
}

class _SSLStatusScreenState extends ConsumerState<SSLStatusScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _sslStatus;
  Map<String, dynamic>? _connectionTest;
  Map<String, dynamic>? _securityTest;

  @override
  void initState() {
    super.initState();
    _loadSSLStatus();
  }

  Future<void> _loadSSLStatus() async {
    setState(() => _isLoading = true);

    try {
      final sslStatus = await SSLService.instance.getSSLStatus();
      final connectionTest =
          await SSLService.instance.verifyAppwriteConnection();
      final securityTest = await SSLService.instance.testSSLSecurity();

      setState(() {
        _sslStatus = sslStatus;
        _connectionTest = connectionTest;
        _securityTest = securityTest;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading SSL status: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testSSLConnection() async {
    setState(() => _isLoading = true);

    try {
      final result = await SSLService.instance.testAppwriteConnection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'SSL test completed'),
            backgroundColor:
                result['success'] == true ? Colors.green : Colors.red,
          ),
        );
      }

      // Reload status after test
      await _loadSSLStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SSL test failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'SSL Configuration Status',
        showBackButton: true,
      ),
      body: _isLoading
          ? const LoadingWidget()
          : RefreshIndicator(
              onRefresh: _loadSSLStatus,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSSLOverviewCard(),
                    const SizedBox(height: 16),
                    _buildConnectionStatusCard(),
                    const SizedBox(height: 16),
                    _buildSecurityTestCard(),
                    const SizedBox(height: 16),
                    _buildCertificateInfoCard(),
                    const SizedBox(height: 16),
                    _buildRecommendationsCard(),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSSLOverviewCard() {
    final sslEnabled = _sslStatus?['ssl_enabled'] ?? false;
    final certificateLoaded = _sslStatus?['certificate_loaded'] ?? false;

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  sslEnabled ? Icons.security : Icons.security_outlined,
                  color: sslEnabled ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'SSL Configuration Overview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow('SSL Enabled', sslEnabled),
            _buildStatusRow('Certificate Loaded', certificateLoaded),
            if (_connectionTest != null)
              _buildStatusRow(
                'Connection Secure',
                _connectionTest!['ssl_enabled'] ?? false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    if (_connectionTest == null) return const SizedBox.shrink();

    final isSecure = _connectionTest!['ssl_enabled'] ?? false;
    final url = _connectionTest!['url'] ?? 'Unknown';

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSecure ? Icons.https : Icons.http,
                  color: isSecure ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Connection Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('URL: $url'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSecure
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSecure ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Text(
                isSecure ? 'Secure HTTPS Connection' : 'Insecure Connection',
                style: TextStyle(
                  color: isSecure ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTestCard() {
    if (_securityTest == null) return const SizedBox.shrink();

    final isSecure = _securityTest!['secure'] ?? false;
    final checks = _securityTest!['checks'] as Map<String, dynamic>? ?? {};

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSecure ? Icons.verified_user : Icons.warning,
                  color: isSecure ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Security Test Results',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...checks.entries.map(
              (entry) => _buildStatusRow(
                _formatCheckName(entry.key),
                entry.value == true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateInfoCard() {
    final certificateInfo =
        _sslStatus?['certificate_info'] as Map<String, dynamic>?;
    if (certificateInfo == null) return const SizedBox.shrink();

    final isValid = certificateInfo['valid'] ?? false;

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: isValid ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Certificate Information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Status', isValid ? 'Valid' : 'Invalid'),
            if (certificateInfo['format'] != null)
              _buildInfoRow('Format', certificateInfo['format']),
            if (certificateInfo['size'] != null)
              _buildInfoRow('Size', '${certificateInfo['size']} bytes'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    final recommendations =
        _sslStatus?['recommendations'] as List<dynamic>? ?? [];
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Security Recommendations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendations.map(
              (rec) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '- ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(child: Text(rec.toString())),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _testSSLConnection,
            icon: const Icon(Icons.security),
            label: const Text('Test SSL Connection'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _loadSSLStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Status'),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  String _formatCheckName(String key) {
    return TextFormatter.formatText(key);
  }
}
