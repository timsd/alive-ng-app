import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Logger _logger = Logger('FirestoreService');

  // Generic helpers
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _db.collection(path);
  DocumentReference<Map<String, dynamic>> doc(String path) => _db.doc(path);

  Future<void> create(
      String collectionPath, String id, Map<String, dynamic> data) async {
    try {
      await _db.collection(collectionPath).doc(id).set(data);
    } catch (e) {
      _logger.error('Error creating document in $collectionPath', e);
      throw DatabaseException('Failed to create document', originalError: e);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> read(
      String collectionPath, String id) async {
    try {
      return await _db.collection(collectionPath).doc(id).get();
    } catch (e) {
      _logger.error('Error reading document from $collectionPath', e);
      throw DatabaseException('Failed to read document', originalError: e);
    }
  }

  Future<void> update(
      String collectionPath, String id, Map<String, dynamic> data) async {
    try {
      await _db
          .collection(collectionPath)
          .doc(id)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      _logger.error('Error updating document in $collectionPath', e);
      throw DatabaseException('Failed to update document', originalError: e);
    }
  }

  Future<void> delete(String collectionPath, String id) async {
    try {
      await _db.collection(collectionPath).doc(id).delete();
    } catch (e) {
      _logger.error('Error deleting document from $collectionPath', e);
      throw DatabaseException('Failed to delete document', originalError: e);
    }
  }

  Query<Map<String, dynamic>> query(String collectionPath,
      {Map<String, dynamic>? filters, int? limit}) {
    Query<Map<String, dynamic>> q = _db.collection(collectionPath);
    if (filters != null) {
      filters.forEach((key, value) {
        q = q.where(key, isEqualTo: value);
      });
    }
    if (limit != null) {
      q = q.limit(limit);
    }
    return q;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDoc(
      String collectionPath, String id) {
    return _db.collection(collectionPath).doc(id).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(
      String collectionPath,
      {Map<String, dynamic>? filters,
      int? limit}) {
    return query(collectionPath, filters: filters, limit: limit).snapshots();
  }

  // Profiles
  Future<void> upsertProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _db
          .collection('profiles')
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      _logger.error('Error upserting profile', e);
      throw DatabaseException('Failed to upsert profile', originalError: e);
    }
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    try {
      final snap = await _db.collection('profiles').doc(uid).get();
      return snap.data();
    } catch (e) {
      _logger.error('Error getting profile', e);
      throw DatabaseException('Failed to get profile', originalError: e);
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> profileStream(String uid) {
    return _db.collection('profiles').doc(uid).snapshots();
  }
}
