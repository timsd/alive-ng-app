hoimport 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

/// Centralised helper for Appwrite `TablesDB` operations that must gracefully
/// auto-create missing rows on `404` (`row_not_found` / `document_not_found`)
/// so UI/UX state immediately persists and renders without 404 crashes.
class AppwriteUpsertHelper {
  const AppwriteUpsertHelper._();

  /// Updates [rowId] in [tableId], falling back to `createRow` when Appwrite
  /// returns `404`.
  ///
  /// When the full payload needed for creation differs from the partial update
  /// payload, pass [createData].
  static Future<models.Row> updateOrCreateRow(
    TablesDB tables, {
    required String databaseId,
    required String tableId,
    required String rowId,
    required Map<String, dynamic> data,
    Map<String, dynamic>? createData,
    List<String>? permissions,
  }) async {
    try {
      return await tables.updateRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: rowId,
        data: data,
      );
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
      return await tables.createRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: rowId,
        data: createData ?? data,
        permissions: permissions,
      );
    }
  }

  /// Fetches [rowId] from [tableId], creating it with [defaultData] if
  /// Appwrite returns `404`.
  static Future<models.Row> getOrCreateRow(
    TablesDB tables, {
    required String databaseId,
    required String tableId,
    required String rowId,
    required Map<String, dynamic> defaultData,
    List<String>? permissions,
  }) async {
    try {
      return await tables.getRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: rowId,
      );
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
      return await tables.createRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: rowId,
        data: defaultData,
        permissions: permissions,
      );
    }
  }
}
