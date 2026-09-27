import 'package:appwrite/appwrite.dart' show AppwriteException;

/// Turns any thrown object into a message worth showing a person.
///
/// Stringifying an `AppwriteException` with `$e` gives
/// "AppwriteException: ..." and discards the fields that actually identify the
/// failure: the numeric `code` (401 unauthorized, 404 missing, 413 too large)
/// and the `type` (user_unauthorized, file_not_found, ...). A permission
/// problem, a missing bucket and an oversized image therefore all looked alike,
/// which is why the picture upload could not be diagnosed.
///
/// Returns a short single-line string; also logged alongside so the detail
/// survives in device logs even when the toast is dismissed.
String describeError(Object error) {
  if (error is AppwriteException) {
    final code = error.code;
    final type = error.type;
    final message = (error.message ?? '').trim();
    final parts = <String>[
      if (code != null) 'code $code',
      if (type != null && type.isNotEmpty) type,
      if (message.isNotEmpty) message,
    ];
    if (parts.isEmpty) return 'unknown Appwrite error';
    return parts.join(': ');
  }
  final text = error.toString().trim();
  // Strip a leading "Exception: " style prefix so the message reads cleanly.
  return text.isEmpty ? 'unknown error' : text;
}
