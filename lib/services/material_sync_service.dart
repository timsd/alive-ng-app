import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/donation_models.dart';

/// Admin utility to sync Appwrite Storage tracts into the
/// `downloadable_materials` collection with required donation settings.
class MaterialSyncService {
  MaterialSyncService._();
  static final MaterialSyncService instance = MaterialSyncService._();

  late final TablesDB _tables = TablesDB(appwriteClient);
  late final Storage _storage = Storage(appwriteClient);

  /// Sync all PDF files in the Appwrite tracts bucket into
  /// Appwrite `downloadable_materials`.
  ///
  /// - `requiresDonation`: whether downloads require a donation
  /// - `minimumDonation`: minimum donation amount required (uses DonationConstants)
  ///
  /// Returns the number of materials upserted.
  Future<int> syncTractsToDownloadableMaterials({
    bool requiresDonation = true,
    double minimumDonation = DonationConstants.minimumTractDonation,
    bool activate = true,
  }) async {
    int upserted = 0;

    final fileList = await _storage.listFiles(
      bucketId: AppwriteBackendConfig.tractFilesBucketId,
      queries: [Query.limit(100)],
    );
    for (final file in fileList.files) {
      final name = file.name;
      if (!name.toLowerCase().endsWith('.pdf')) continue;

      final id = name.replaceAll('.pdf', '');
      final fileUrl = '${AppwriteBackendConfig.endpoint}/storage/buckets/'
          '${AppwriteBackendConfig.tractFilesBucketId}/files/${file.$id}/view'
          '?project=${AppwriteBackendConfig.projectId}';

      final nowIso = DateTime.now().toIso8601String();
      var existingDownloadCount = 0;
      var createdAt = nowIso;
      try {
        final existing = await _tables.getRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.downloadableMaterialsCollectionId,
          rowId: id,
        );
        existingDownloadCount = existing.data['download_count'] ?? 0;
        createdAt = existing.data['created_at'] ?? nowIso;
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;
      }

      final data = {
        'title': id.replaceAll('_', ' ').trim(),
        'description': 'Tract PDF',
        'category': 'Tracts',
        'file_url': fileUrl,
        'thumbnail_url': null,
        'file_size_bytes': file.sizeOriginal,
        'file_type': file.mimeType,
        'minimum_donation': minimumDonation,
        'requires_donation': requiresDonation,
        'is_active': activate,
        'download_count': existingDownloadCount,
        'metadata': jsonEncode({
          'source': 'appwrite_storage',
          'bucket_id': AppwriteBackendConfig.tractFilesBucketId,
          'file_id': file.$id,
          'file_name': name,
        }),
        'created_at': createdAt,
        'updated_at': nowIso,
      };

      try {
        await _tables.updateRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.downloadableMaterialsCollectionId,
          rowId: id,
          data: data,
        );
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;
        await _tables.createRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.downloadableMaterialsCollectionId,
          rowId: id,
          data: data,
        );
      }
      upserted++;
    }

    return upserted;
  }
}
