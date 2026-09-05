/// Service-layer facade for the Appwrite SDK.
///
/// Screens and providers must NEVER import `package:appwrite` directly.
/// They import this facade instead, so all Appwrite SDK references stay
/// inside the service layer (`lib/services/`). If the SDK's API changes,
/// this file (and the adapters) is the only place that needs updating.
export 'package:appwrite/appwrite.dart' hide Locale;