// maxUploadMb — наибольший размер видео для анализа
const maxUploadMb = 100;

// allowedExtensions — форматы видео, которые принимает сервер
const allowedExtensions = ['.mp4', '.mov', '.webm'];

// checkVideoFile — проверяет расширение и размер файла до отправки, возвращает код ошибки или null
String? checkVideoFile(String path, int sizeBytes) {
  final name = path.toLowerCase();
  if (!allowedExtensions.any(name.endsWith)) return 'unsupported_format';
  if (sizeBytes == 0) return 'empty_file';
  if (sizeBytes > maxUploadMb * 1024 * 1024) return 'file_too_large';
  return null;
}

// instructionErrors — ошибки, при которых предлагается посмотреть инструкцию
const instructionErrors = [
  'no_pose_detected',
  'video_too_short',
  'video_too_long',
  'recording_too_short',
];
