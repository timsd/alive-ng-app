import 'package:appwrite/models.dart' as models;

extension AppwriteUserCompatibility on models.User {
  String get uid => $id;
  String? get displayName => name.isEmpty ? null : name;
  String? get photoURL => null;
  bool get emailVerified => emailVerification;
  bool get isAnonymous => false;
}
