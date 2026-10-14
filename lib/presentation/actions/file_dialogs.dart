import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Thin adapters over file_picker 13's static API so call sites keep the
/// "null means cancelled" shape they were written against.

class PickedFiles {
  final List<PlatformFile> files;
  const PickedFiles(this.files);
}

/// Pick one file (or several with [allowMultiple]); null when cancelled.
Future<PickedFiles?> pickFiles({
  String? dialogTitle,
  FileType type = FileType.any,
  List<String>? allowedExtensions,
  bool allowMultiple = false,
}) async {
  final files = allowMultiple
      ? await FilePicker.pickFiles(
          dialogTitle: dialogTitle,
          type: type,
          allowedExtensions: allowedExtensions,
        )
      : [
          ?await FilePicker.pickFile(
            dialogTitle: dialogTitle,
            type: type,
            allowedExtensions: allowedExtensions,
          ),
        ];
  return files.isEmpty ? null : PickedFiles(files);
}

/// Ask for a save location without writing anything meaningful there.
///
/// file_picker 13 writes the given bytes itself; our exports are rendered
/// by ffmpeg afterwards, so the path is reserved with an empty file that
/// the export overwrites. Returns null when cancelled or when the platform
/// hands back a non-file URI.
Future<String?> pickSavePath({
  required String fileName,
  String? dialogTitle,
  FileType type = FileType.any,
}) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List(0),
    dialogTitle: dialogTitle,
    type: type,
  );
  if (uri == null || uri.scheme != 'file') return null;
  var path = uri.toFilePath();
  final wanted = p.extension(fileName);
  if (p.extension(path).isEmpty && wanted.isNotEmpty) {
    // The user typed a bare name: drop the extension-less placeholder.
    try {
      await File(path).delete();
    } catch (_) {}
    path = '$path$wanted';
  }
  return path;
}
