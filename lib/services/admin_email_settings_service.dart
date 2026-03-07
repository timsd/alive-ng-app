import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage configurable admin notification emails
class AdminEmailSettingsService {
  static final AdminEmailSettingsService instance = AdminEmailSettingsService._();
  AdminEmailSettingsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'admin_email_settings';
  static const String _docId = 'config';

  /// Defaults
  static const String defaultPrimaryEmail = 'zavolah@gmail.com';

  Future<Map<String, dynamic>> getSettings() async {
    final doc = await _firestore.collection(_collection).doc(_docId).get();
    if (!doc.exists) {
      // Initialize with defaults
      final defaults = {
        'primary': defaultPrimaryEmail,
        'cc': <String>[],
        'notifyOnSignup': true,
        'notifyOnApproval': true,
        'notifyOnRejection': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore.collection(_collection).doc(_docId).set(defaults);
      return defaults;
    }
    return doc.data() ?? {};
  }

  Stream<Map<String, dynamic>> watchSettings() {
    return _firestore.collection(_collection).doc(_docId).snapshots().map((s) => s.data() ?? {});
  }

  Future<void> setPrimaryEmail(String email) async {
    await _firestore.collection(_collection).doc(_docId).set({
      'primary': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addCcEmail(String email) async {
    await _firestore.collection(_collection).doc(_docId).set({
      'cc': FieldValue.arrayUnion([email]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeCcEmail(String email) async {
    await _firestore.collection(_collection).doc(_docId).set({
      'cc': FieldValue.arrayRemove([email]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<String>> getRecipients() async {
    final settings = await getSettings();
    final primary = (settings['primary'] as String?) ?? defaultPrimaryEmail;
    final cc = (settings['cc'] as List?)?.cast<String>() ?? <String>[];
    // Return unique, non-empty emails
    final emails = <String>{}
      ..add(primary.trim())
      ..addAll(cc.map((e) => e.trim()).where((e) => e.isNotEmpty));
    return emails.toList();
  }
}