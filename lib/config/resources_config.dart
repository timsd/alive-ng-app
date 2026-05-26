class ResourcesConfig {
  static const String baseUrl = String.fromEnvironment(
    'APPWRITE_RESOURCES_BASE_URL',
    defaultValue: 'https://app.alivenigeria.org/resources',
  );
}
