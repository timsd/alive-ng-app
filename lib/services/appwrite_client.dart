import 'package:appwrite/appwrite.dart';

/// Global Appwrite service instances for SDK and provider access.
/// Extracted to break circular imports between main.dart and services.
final appwriteClient = Client();
late final Account appwriteAccount;
late final Storage appwriteStorage;
late final Realtime appwriteRealtime;

