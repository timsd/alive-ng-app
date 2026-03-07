import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_storage_service.dart';
import '../models/donation_models.dart';

/// Admin utility to sync Firebase Storage tracts into Firestore
/// `downloadable_materials` collection with required donation settings.
class MaterialSyncService {
  MaterialSyncService._();
  static final MaterialSyncService instance = MaterialSyncService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorageService _storage = FirebaseStorageService();

  /// Sync all PDF files under `Tracts/` in Firebase Storage into
  /// Firestore `downloadable_materials` collection.
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

    final List<Reference> files = await _storage.getTractFiles();
    for (final ref in files) {
      final name = ref.name; // e.g. my_tract.pdf
      if (!name.toLowerCase().endsWith('.pdf')) continue;

      final id = name.replaceAll('.pdf', '');
      final storagePath = '${FirebaseStorageService.tractsPath}/$name';

      // Get metadata for file size/type
      int fileSizeBytes = 0;
      String fileType = 'application/pdf';
      try {
        final meta = await _storage.getTractFileMetadata(name);
        if (meta?.size != null) fileSizeBytes = meta!.size!;
        if (meta?.contentType != null) fileType = meta!.contentType!;
      } catch (_) {}

      final nowIso = DateTime.now().toIso8601String();

      final docRef = _db.collection('downloadable_materials').doc(id);
      final docSnap = await docRef.get();

      final data = {
        'title': id.replaceAll('_', ' ').trim(),
        'description': 'Tract PDF',
        'category': 'Tracts',
        'file_url': storagePath,
        'thumbnail_url': null,
        'file_size_bytes': fileSizeBytes,
        'file_type': fileType,
        'minimum_donation': minimumDonation,
        'requires_donation': requiresDonation,
        'is_active': activate,
        'download_count': docSnap.exists ? (docSnap.data()!['download_count'] ?? 0) : 0,
        'metadata': {
          'source': 'firebase_storage',
          'bucket_path': storagePath,
        },
        'created_at': docSnap.exists ? (docSnap.data()!['created_at'] ?? nowIso) : nowIso,
        'updated_at': nowIso,
      };

      await docRef.set(data, SetOptions(merge: true));
      upserted++;
    }

    return upserted;
  }
}