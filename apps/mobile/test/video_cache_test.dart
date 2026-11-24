import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seriq_mobile/services/video_cache.dart';

void main() {
  late Directory cache;

  setUp(() => cache = Directory.systemTemp.createTempSync('seriq_cache'));
  tearDown(() => cache.deleteSync(recursive: true));

  // file — создаёт файл в кэше
  File file(String rel, [int size = 3]) => File('${cache.path}/$rel')
    ..createSync(recursive: true)
    ..writeAsBytesSync(List.filled(size, 1));

  test(
    'удаляет старые копии и пустые файлы камеры, текущую оставляет',
    () async {
      final oldGallery = file(
        '3d7475be-e99a-489d-bb51-45d7a2e818a3/1000028508.mp4',
      );
      final oldCamera = file('423698cb-a29c-4af5-a0cf-d2248660e71d8744.mp4', 0);
      final other = file('flutter_engine.bin');
      final current = file(
        '2b38dbf7-c56f-426b-918c-3b70cd295384/1000028514.mp4',
      );

      await deleteOldVideoCopies(current.path);

      expect(oldGallery.existsSync(), isFalse);
      expect(oldGallery.parent.existsSync(), isFalse);
      expect(oldCamera.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
      expect(current.existsSync(), isTrue);
    },
  );

  test('текущий файл снят камерой прямо в корне кэша', () async {
    final old = file('a1b2c3d4-0000-0000-0000-000000000000/old.mov');
    final current = file('e9c10f1c-4375-4fa7-aad2-f127e2de5e25697.mp4');

    await deleteOldVideoCopies(current.path);

    expect(old.existsSync(), isFalse);
    expect(current.existsSync(), isTrue);
  });
}
