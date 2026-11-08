import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart' as fp;

export 'package:file_picker/file_picker.dart' show FileType, FilePickerStatus;

/// Unified representation of a picked file across `file_picker` major versions.
///
/// Isolates UI screens from breaking changes in `package:file_picker` (such as
/// the v11–v13 removal of `FilePickerResult`, `FilePicker.platform`, `.bytes`,
/// and `.size`).
class PlatformFile {
  final String name;
  final int size;
  final Uint8List? bytes;
  final String? path;
  final String? extension;
  final Stream<List<int>>? readStream;

  const PlatformFile({
    required this.name,
    required this.size,
    this.bytes,
    this.path,
    this.extension,
    this.readStream,
  });
}

/// Result wrapper preserving the familiar `result.files` API across upgrades.
class FilePickerResult {
  final List<PlatformFile> files;

  const FilePickerResult(this.files);

  bool get isSinglePick => files.length == 1;
}

/// Service-layer facade for `package:file_picker` (v13.3+).
///
/// Screens import this facade instead of `package:file_picker/file_picker.dart`
/// directly so future `file_picker` major upgrades only require updating this file.
class FilePicker {
  FilePicker._();

  static final FilePicker platform = FilePicker._();

  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    fp.FileType type = fp.FileType.any,
    List<String>? allowedExtensions,
    void Function(fp.FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final List<fp.PlatformFile> rawFiles;
    if (allowMultiple) {
      rawFiles = await fp.FilePicker.pickFiles(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        onFileLoading: onFileLoading,
        compressionQuality: compressionQuality,
      );
    } else {
      final single = await fp.FilePicker.pickFile(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        onFileLoading: onFileLoading,
        compressionQuality: compressionQuality,
      );
      rawFiles = single != null ? <fp.PlatformFile>[single] : <fp.PlatformFile>[];
    }

    if (rawFiles.isEmpty) {
      return null;
    }

    final converted = <PlatformFile>[];
    for (final raw in rawFiles) {
      Uint8List? bytes;
      if (withData || kIsWeb) {
        try {
          bytes = await raw.readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }
      final length =
          raw.lengthSync() ?? (await raw.length()) ?? bytes?.length ?? 0;

      converted.add(
        PlatformFile(
          name: raw.name,
          size: length,
          bytes: bytes,
          path: kIsWeb ? null : raw.path,
          extension: raw.extension,
          readStream: withReadStream ? raw.readAsByteStream() : null,
        ),
      );
    }

    return FilePickerResult(converted);
  }

  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) {
    return fp.FilePicker.getDirectoryPath(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
    );
  }

  Future<bool?> clearTemporaryFiles() async {
    await fp.FilePicker.clearTemporaryFiles();
    return true;
  }
}

