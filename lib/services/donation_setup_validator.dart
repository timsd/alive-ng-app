import 'package:appwrite/appwrite.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/logger.dart';

/// Validates that all Appwrite collections, attributes, and permissions
/// required by the donation flow exist and are correctly configured.
///
/// Run this from a debug screen or during development to surface the exact
/// missing piece instead of the generic "AppwriteException(database error)".
class DonationSetupValidator {
  DonationSetupValidator._();

  static final Logger _logger = Logger('DonationSetupValidator');

  /// Result of validating a single collection.
  static const String _tablesDbNote =
      'Appwrite 1.9+ uses TablesDB. Collections must be created as tables '
      '(not legacy documents) and the API key must have the '
      'tables.read / tables.write scopes.';

  /// Full list of collections the donation flow depends on, with the
  /// attributes each one must expose.
  static const Map<String, List<String>> _required = {
    AppwriteBackendConfig.projectsCollectionId: [
      'title',
      'description',
      'target_amount',
      'raised_amount',
      'currency',
      'status',
      'priority',
      'image_url',
      'cta_label',
      'fund_update_title',
      'fund_update_text',
      'fund_update_images',
      'category',
      'is_active',
      'created_at',
      'updated_at',
    ],
    AppwriteBackendConfig.donationRecordsCollectionId: [
      'user_id',
      'email',
      'amount',
      'currency',
      'status',
      'reference',
      'payment_gateway',
      'payment_method',
      'transaction_id',
      'project_id',
      'material_id',
      'metadata',
      'recurring',
      'created_at',
      'updated_at',
    ],
    AppwriteBackendConfig.giftSubmissionsCollectionId: [
      'gift_type',
      'user_id',
      'full_name',
      'email',
      'phone',
      'item_type',
      'quantity',
      'estimated_value',
      'delivery_preference',
      'location',
      'skills_or_service',
      'availability',
      'description',
      'status',
      'created_at',
      'updated_at',
    ],
    AppwriteBackendConfig.downloadableMaterialsCollectionId: [
      'title',
      'description',
      'file_url',
      'category',
      'download_count',
      'is_active',
      'requires_donation',
      'created_at',
      'updated_at',
    ],
    AppwriteBackendConfig.materialDownloadsCollectionId: [
      'user_id',
      'material_id',
      'donation_id',
      'downloaded_at',
    ],
    AppwriteBackendConfig.paymentLogsCollectionId: [
      'donation_id',
      'reference',
      'amount',
      'currency',
      'status',
      'gateway_response',
      'created_at',
    ],
    AppwriteBackendConfig.appSettingsCollectionId: [
      'key',
      'value',
    ],
  };

  /// Runs the full validation and returns a human-readable report.
  /// Also logs every finding so it shows up in the debug console.
  static Future<String> validate() async {
    final tables = TablesDB(appwriteClient);
    final dbId = AppwriteBackendConfig.databaseId;
    final buffer = StringBuffer();
    int missing = 0;
    int warnings = 0;

    buffer.writeln('Donation setup validation');
    buffer.writeln('Database: $dbId');
    buffer.writeln('Endpoint: ${AppwriteBackendConfig.endpoint}');
    buffer.writeln('Project: ${AppwriteBackendConfig.projectId}');
    buffer.writeln('─' * 40);

    for (final entry in _required.entries) {
      final tableId = entry.key;
      final attrs = entry.value;
      buffer.writeln('Table: $tableId');

      try {
        // Probe the table with a minimal query.
        await tables.listRows(
          databaseId: dbId,
          tableId: tableId,
          queries: [Query.limit(1)],
        );
        buffer.writeln('  ✓ table reachable');
      } on AppwriteException catch (e) {
        missing++;
        final code = e.code;
        final msg = e.message ?? 'unknown';
        if (code == 404) {
          buffer.writeln('  ✗ MISSING — table "$tableId" does not exist.');
          buffer.writeln('    Fix: create it in Appwrite → Databases → '
              '$dbId → as a Table (enable TablesDB).');
        } else if (code == 401) {
          buffer.writeln('  ✗ PERMISSION — API key lacks access to '
              '"$tableId".');
          buffer.writeln('    Fix: add tables.read / tables.write scopes '
              'to the API key.');
        } else {
          buffer.writeln('  ✗ ERROR ($code): $msg');
        }
        _logger.warn('Table $tableId check failed', e);
        continue;
      } catch (e) {
        missing++;
        buffer.writeln('  ✗ UNEXPECTED: $e');
        _logger.error('Table $tableId unexpected error', e);
        continue;
      }

      // Table exists — try to read one row to confirm attribute access.
      try {
        final snapshot = await tables.listRows(
          databaseId: dbId,
          tableId: tableId,
          queries: [Query.limit(1)],
        );
        if (snapshot.rows.isNotEmpty) {
          final keys = snapshot.rows.first.data.keys.toSet();
          final missingAttrs = attrs.where((a) => !keys.contains(a)).toList();
          if (missingAttrs.isNotEmpty) {
            warnings++;
            buffer.writeln('  ⚠ missing attributes: ${missingAttrs.join(", ")}');
          }
        }
      } catch (e) {
        warnings++;
        buffer.writeln('  ⚠ could not inspect rows: $e');
      }
    }

    buffer.writeln('─' * 40);
    buffer.writeln(_tablesDbNote);
    buffer.writeln('Missing: $missing   Warnings: $warnings');

    final report = buffer.toString();
    _logger.info(report);
    return report;
  }
}
