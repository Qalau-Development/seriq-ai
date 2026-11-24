import 'dart:io';

const _videoExtensions = {'.mp4', '.mov', '.webm', '.m4v', '.3gp'};
final _uuidDir = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F-]{27}$');

// _isVideo — файл видео по расширению
bool _isVideo(String path) {
  final dot = path.lastIndexOf('.');
  return dot >= 0 &&
      _videoExtensions.contains(path.substring(dot).toLowerCase());
}

// deleteOldVideoCopies — удаляет временные копии видео от прошлых записей, кроме текущей
Future<void> deleteOldVideoCopies(String keepPath) async {
  try {
    final keep = File(keepPath).absolute.path;
    final parent = File(keepPath).absolute.parent;
    final root =
        _uuidDir.hasMatch(
          parent.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
        )
        ? parent.parent
        : parent;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is File && _isVideo(entity.path) && entity.path != keep) {
        await entity.delete();
      } else if (entity is Directory &&
          _uuidDir.hasMatch(
            entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
          )) {
        await for (final f in entity.list(followLinks: false)) {
          if (f is File && _isVideo(f.path) && f.path != keep) await f.delete();
        }
        if (await entity.list().isEmpty) await entity.delete();
      }
    }
  } catch (_) {}
}
