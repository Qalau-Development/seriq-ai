// AppConfig — адреса сервера, задаются при сборке
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://seriq-ai.qalau.com/api/v1',
  );
  static const instructionVideoUrl = String.fromEnvironment(
    'INSTRUCTION_VIDEO_URL',
    defaultValue: 'https://seriq-ai.qalau.com/media/instruction-e02.mp4',
  );
}
