import 'dart:convert';
import '../../utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/appwrite_admin_export_service.dart';
import '../../models/donation_report_models.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/admin_filter_header.dart';
import '../../utils/responsive_utils.dart';

class AdminDonationsReportScreen extends StatelessWidget {
  const AdminDonationsReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Financial data is leadership-gated: it exposes every donor's name, email
    // and amounts. This screen previously had no guard at all, so any signed-in
    // user who could reach the route could read the whole giving history.
    return const RoleProtectedScreen(
      requiredRole: 'leader',
      screenName: 'Donation Reports',
      child: _AdminDonationsReportContent(),
    );
  }
}

class _AdminDonationsReportContent extends StatefulWidget {
  const _AdminDonationsReportContent();

  @override
  State<_AdminDonationsReportContent> createState() =>
      _AdminDonationsReportContentState();
}

class _AdminDonationsReportContentState
    extends State<_AdminDonationsReportContent> {
  final _currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
  final _usdFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  bool _isLoading = true;
  bool _isExporting = false;
  List<DonationReportEntry> _allDonations = [];
  List<DonationReportEntry> _filteredDonations = [];

  String _statusFilter = 'all';
  String _datePreset = 'all';
  String _modeFilter = 'live';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _searchQuery = '';

  double _totalNgn = 0;
  double _totalUsd = 0;
  int _successCount = 0;
  int _pendingCount = 0;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    setState(() => _isLoading = true);
    try {
      final rows =
          await AppwriteAdminExportService.instance.listDonationEntries(
        status: _statusFilter == 'all' ? null : _statusFilter,
        limit: 250,
      );
      _allDonations = rows;
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load donations: ${ErrorHandler.getUserFriendlyMessage(e)}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();
    final now = DateTime.now();

    DateTime? filterStart;
    DateTime? filterEnd;

    switch (_datePreset) {
      case 'today':
        filterStart = DateTime(now.year, now.month, now.day);
        filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'week':
        filterStart = now.subtract(const Duration(days: 7));
        filterEnd = now;
        break;
      case 'month':
        filterStart = DateTime(now.year, now.month, 1);
        filterEnd = now;
        break;
      case 'custom':
        filterStart = _customStartDate;
        filterEnd = _customEndDate;
        break;
      case 'all':
      default:
        filterStart = null;
        filterEnd = null;
        break;
    }

    _filteredDonations = _allDonations.where((d) {
      // Transaction mode filter: strictly isolate test transactions from live financial totals
      if (_modeFilter == 'live' && d.isTest) return false;
      if (_modeFilter == 'test' && !d.isTest) return false;

      // Status filter
      final status = d.status;
      if (_statusFilter != 'all' && status != _statusFilter.toLowerCase()) {
        return false;
      }

      // Date filter
      final dt = d.createdAt;
      if (dt != null) {
        if (filterStart != null && dt.isBefore(filterStart)) return false;
        if (filterEnd != null && dt.isAfter(filterEnd)) return false;
      }

      // Search query filter
      if (query.isNotEmpty) {
        final ref = d.reference.toLowerCase();
        final name = d.donorName.toLowerCase();
        final email = d.donorEmail.toLowerCase();
        final purpose = d.purpose.toLowerCase();

        if (!ref.contains(query) &&
            !name.contains(query) &&
            !email.contains(query) &&
            !purpose.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Recalculate summary totals
    _totalNgn = 0;
    _totalUsd = 0;
    _successCount = 0;
    _pendingCount = 0;
    _failedCount = 0;

    for (final d in _filteredDonations) {
      final amount = d.amount;
      final currency = d.currency;
      final status = d.status;

      if (status == 'success' || status == 'completed') {
        _successCount++;
        if (currency == 'USD') {
          _totalUsd += amount;
        } else {
          _totalNgn += amount;
        }
      } else if (status == 'failed') {
        _failedCount++;
      } else {
        _pendingCount++;
      }
    }
  }

  Future<void> _exportReport(String format) async {
    setState(() => _isExporting = true);
    try {
      final result =
          await AppwriteAdminExportService.instance.exportDonationsReport(
        format: format,
        startDate: _datePreset == 'custom' ? _customStartDate : null,
        endDate: _datePreset == 'custom' ? _customEndDate : null,
        status: _statusFilter == 'all' ? null : _statusFilter,
      );

      final content = result['content'] as String? ?? '';
      final fileInfo = result['file'] as Map<String, dynamic>?;
      final downloadUrl = fileInfo?['url']?.toString();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Report Generated'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial report in ${format.toUpperCase()} format has been compiled using official bank statement standards.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Records included: ${result['count'] ?? _filteredDonations.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                  'Total NGN: ${_currencyFormat.format(result['summary']?['total_ngn'] ?? _totalNgn)}'),
              if ((result['summary']?['total_usd'] ?? _totalUsd) > 0)
                Text(
                    'Total USD: ${_usdFormat.format(result['summary']?['total_usd'] ?? _totalUsd)}'),
              const SizedBox(height: 14),
              Text(
                'You can instantly save or share the statement file, copy it to clipboard, or download directly.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (content.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: content));
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Statement copied to clipboard!')),
                  );
                },
              ),
            if (content.isNotEmpty)
              FilledButton.icon(
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Save / Share File'),
                onPressed: () async {
                  final fileName =
                      'alive_financial_statement_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.$format';
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [
                      XFile.fromData(
                        Uint8List.fromList(utf8.encode(content)),
                        name: fileName,
                        mimeType: format == 'csv'
                            ? 'text/csv'
                            : 'application/json',
                      ),
                    ],
                      subject: 'ALIVE Nigeria Financial Statement',
                    ),
                  );
                },
              ),
            if (downloadUrl != null)
              TextButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Link'),
                onPressed: () async {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${ErrorHandler.getUserFriendlyMessage(e)}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Donations & Financial Report',
        showBackButton: true,
        showDonationButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadDonations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Overview Cards
                  _buildKpiSection(theme, isDesktop),

                  const SizedBox(height: 20),

                  // Filter Toolbar
                  _buildFilterToolbar(theme),

                  const SizedBox(height: 20),

                  // Header and Record Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Donation Records (${_filteredDonations.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_download_outlined, size: 16),
                        label: const Text(
                          'Export CSV',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _filteredDonations.isEmpty || _isExporting
                            ? null
                            : () => _exportReport('csv'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Content Table or Card List
                  if (_filteredDonations.isEmpty)
                    _buildEmptyState(theme)
                  else if (isDesktop)
                    _buildDataTable(theme)
                  else
                    _buildMobileCardList(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiSection(ThemeData theme, bool isDesktop) {
    final cards = [
      _buildStatCard(
        theme,
        title: 'Total Raised (NGN)',
        value: _currencyFormat.format(_totalNgn),
        icon: Icons.payments,
        color: Colors.green,
      ),
      _buildStatCard(
        theme,
        title: 'Total Raised (USD)',
        value: _usdFormat.format(_totalUsd),
        icon: Icons.attach_money,
        color: Colors.teal,
      ),
      _buildStatCard(
        theme,
        title: 'Successful Gifts',
        value: '$_successCount',
        icon: Icons.check_circle_outline,
        color: Colors.blue,
      ),
      _buildStatCard(
        theme,
        title: 'Pending / Failed',
        value: '$_pendingCount / $_failedCount',
        icon: Icons.pending_outlined,
        color: Colors.orange,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((c) => SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: c,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(ThemeData theme) {
    final baseRecords = _allDonations.where((d) {
      if (_modeFilter == 'live' && d.isTest) return false;
      if (_modeFilter == 'test' && !d.isTest) return false;
      return true;
    }).toList();

    final allCount = baseRecords.length;
    final completedCount = baseRecords
        .where((d) => d.status == 'completed' || d.status == 'success')
        .length;
    final pendingCount =
        baseRecords.where((d) => d.status == 'pending').length;
    final checkoutCount =
        baseRecords.where((d) => d.status == 'initialized').length;
    final failedCount =
        baseRecords.where((d) => d.status == 'failed').length;

    return AdminFilterHeader<String>(
      searchHint: 'Search by donor name, email, or reference ID...',
      onSearchChanged: (val) {
        _searchQuery = val;
        setState(() => _applyFilters());
      },
      dropdownFilters: [
        AdminDropdownPill<String>(
          label: 'Mode',
          icon: Icons.shield_outlined,
          selectedValue: _modeFilter,
          items: const [
            DropdownMenuItem(value: 'live', child: Text('Live Production')),
            DropdownMenuItem(value: 'test', child: Text('Test Transactions')),
            DropdownMenuItem(value: 'all', child: Text('All Records')),
          ],
          onChanged: (val) {
            if (val != null) {
              _modeFilter = val;
              setState(() => _applyFilters());
            }
          },
        ),
        AdminDropdownPill<String>(
          label: 'Timeframe',
          icon: Icons.calendar_today_outlined,
          selectedValue: _datePreset,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Time')),
            DropdownMenuItem(value: 'month', child: Text('This Month')),
            DropdownMenuItem(value: 'week', child: Text('Last 7 Days')),
            DropdownMenuItem(value: 'today', child: Text('Today')),
          ],
          onChanged: (val) {
            if (val != null) {
              _datePreset = val;
              setState(() => _applyFilters());
            }
          },
        ),
      ],
      metricPills: [
        AdminMetricPill<String>(
          label: 'All',
          value: 'all',
          count: allCount,
          color: theme.colorScheme.primary,
        ),
        AdminMetricPill<String>(
          label: 'Completed',
          value: 'completed',
          count: completedCount,
          color: Colors.green,
        ),
        AdminMetricPill<String>(
          label: 'Pending',
          value: 'pending',
          count: pendingCount,
          color: Colors.amber,
        ),
        AdminMetricPill<String>(
          label: 'Checkout Opened',
          value: 'initialized',
          count: checkoutCount,
          color: Colors.blue,
        ),
        AdminMetricPill<String>(
          label: 'Failed',
          value: 'failed',
          count: failedCount,
          color: Colors.red,
        ),
      ],
      selectedMetric: _statusFilter,
      onSelectMetric: (val) {
        _statusFilter = val;
        setState(() => _applyFilters());
      },
      hasActiveNonDefaultFilters: _modeFilter != 'live' ||
          _datePreset != 'all' ||
          _statusFilter != 'all' ||
          _searchQuery.isNotEmpty,
      onClearAllFilters: () {
        setState(() {
          _modeFilter = 'live';
          _datePreset = 'all';
          _statusFilter = 'all';
          _searchQuery = '';
          _applyFilters();
        });
      },
    );
  }

  Widget _buildDataTable(ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          columns: const [
            DataColumn(label: Text('Date & Time')),
            DataColumn(label: Text('Donor')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Purpose')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Reference')),
          ],
          rows: _filteredDonations.map((d) {
            final amount = d.amount;
            final currency = d.currency;
            final status = d.status;
            final dt = d.createdAt;

            return DataRow(cells: [
              DataCell(Text(dt != null ? _dateFormat.format(dt) : 'N/A')),
              DataCell(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        d.donorName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (d.isTest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade700, width: 0.5),
                          ),
                          child: Text(
                            'TEST',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(d.donorEmail, style: theme.textTheme.bodySmall),
                ],
              )),
              DataCell(Text(
                currency == 'USD'
                    ? _usdFormat.format(amount)
                    : _currencyFormat.format(amount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              )),
              DataCell(Text(d.purpose)),
              DataCell(_buildStatusBadge(status)),
              DataCell(Text(
                d.reference,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileCardList(ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredDonations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final d = _filteredDonations[i];
        final amount = d.amount;
        final currency = d.currency;
        final status = d.status;
        final dt = d.createdAt;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        d.donorName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (d.isTest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade700, width: 0.5),
                          ),
                          child: Text(
                            'TEST',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    currency == 'USD'
                        ? _usdFormat.format(amount)
                        : _currencyFormat.format(amount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                d.donorEmail.isEmpty ? 'No email provided' : d.donorEmail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Purpose: ${d.purpose}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              if (dt != null) ...[
                const SizedBox(height: 6),
                Text(
                  _dateFormat.format(dt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green.shade800;
        label = 'COMPLETED';
        break;
      case 'failed':
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red.shade800;
        label = 'FAILED';
        break;
      case 'pending':
      default:
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange.shade800;
        label = 'PENDING';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'No Donation Records Found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search criteria, timeframe, or status filter.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
