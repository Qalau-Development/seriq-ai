# EngineError — ошибка анализа с кодом из docs/api.md, бэкенд отдаёт её как 422
class EngineError(Exception):
    api_code = "internal_error"


# VideoUnreadable — видео не удалось открыть или декодировать
class VideoUnreadable(EngineError):
    api_code = "video_unreadable"


# VideoTooShort — видео короче минимальной длительности
class VideoTooShort(EngineError):
    api_code = "video_too_short"


# VideoTooLong — видео длиннее максимальной длительности
class VideoTooLong(EngineError):
    api_code = "video_too_long"


# ArmNotFound — кисть найдена в слишком малом числе кадров
class ArmNotFound(EngineError):
    api_code = "no_pose_detected"


# UnsupportedExercise — у упражнения нет готового модуля или модели
class UnsupportedExercise(EngineError):
    api_code = "unsupported_exercise"
