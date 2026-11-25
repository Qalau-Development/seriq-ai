import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../core/exercises.dart';
import '../../core/routes.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/analysis_result.dart';
import '../../models/session.dart';
import '../../services/api_client.dart';
import '../../services/catalog.dart';
import '../../services/history_storage.dart';
import '../../services/video_cache.dart';
import '../../services/video_check.dart';
import '../../widgets/analyzing_card.dart';
import '../../widgets/app_card.dart';
import '../../widgets/attempt_tile.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/page_shell.dart';
import '../result/result_view.dart';

// SessionState — этапы занятия: ожидание записи, анализ, результат, ошибка
enum SessionState { idle, analyzing, result, error }

// SessionScreen — занятие: запись или выбор видео, анализ, результат и список повторений
class SessionScreen extends StatefulWidget {
  final String exercise;
  final ApiClient? api;
  final Future<XFile?> Function(ImageSource source)? pick;
  final Future<bool> Function(String path)? tooShort;

  const SessionScreen({
    super.key,
    this.exercise = defaultExercise,
    this.api,
    this.pick,
    this.tooShort,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  static const _mockScenarios = ['complete', 'incomplete', 'uncertain', 'no_pose'];

  late final ApiClient _api = widget.api ?? ApiClient();
  final _storage = HistoryStorage();
  final _picker = ImagePicker();
  final _scroll = ScrollController();
  late final _session = Session(
    id: const Uuid().v4(),
    exercise: widget.exercise,
    startedAt: DateTime.now(),
  );
  SessionState _state = SessionState.idle;
  AnalysisResult? _result;
  String? _videoPath;
  String? _errorCode;
  String? _mockScenario;

  @override
  void initState() {
    super.initState();
    if (catalog.value == null) refreshCatalog();
  }

  @override
  void dispose() {
    final path = _videoPath;
    if (path != null) _deleteQuietly(path);
    _scroll.dispose();
    super.dispose();
  }

  // _toTop — прокручивает страницу к началу, где показан итог или ошибка
  void _toTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  // _run — снимает или выбирает видео и отправляет его на анализ
  Future<void> _run(ImageSource source) async {
    XFile? file;
    try {
      file =
          await widget.pick?.call(source) ??
          await _picker.pickVideo(
            source: source,
            maxDuration: const Duration(seconds: 30),
          );
    } on PlatformException catch (e) {
      setState(() {
        _errorCode = e.code.contains('denied') ? 'camera_denied' : 'internal_error';
        _state = SessionState.error;
      });
      return;
    }
    if (file == null) return;
    await deleteOldVideoCopies(file.path);
    await _dropVideo();
    final path = file.path;

    final local = checkVideoFile(path, await File(path).length());
    if (local != null) {
      await _deleteQuietly(path);
      _fail(local);
      return;
    }
    setState(() => _state = SessionState.analyzing);
    try {
      if (await (widget.tooShort ?? _isTooShort)(path)) {
        throw ApiException(
          source == ImageSource.camera ? 'recording_too_short' : 'video_too_short',
        );
      }
      final result = await _api.analyze(
        path,
        exercise: _session.exercise,
        mockScenario: kDebugMode ? _mockScenario : null,
      );
      _session.attempts.add(Attempt.fromResult(result, DateTime.now()));
      await _storage.saveSession(_session);
      if (!mounted) {
        await _deleteQuietly(path);
        return;
      }
      setState(() {
        _result = result;
        _videoPath = path;
        _state = SessionState.result;
      });
      _toTop();
    } on ApiException catch (e) {
      await _deleteQuietly(path);
      _fail(e.code);
    } catch (_) {
      await _deleteQuietly(path);
      _fail('internal_error');
    }
  }

  // _fail — показывает ошибку с кодом
  void _fail(String code) {
    if (!mounted) return;
    setState(() {
      _errorCode = code;
      _state = SessionState.error;
    });
    _toTop();
  }

  // _dropVideo — удаляет запись прошлого повторения
  Future<void> _dropVideo() async {
    final path = _videoPath;
    _videoPath = null;
    if (path != null) await _deleteQuietly(path);
  }

  // _another — возвращает к записи следующего повторения
  Future<void> _another() async {
    setState(() {
      _result = null;
      _errorCode = null;
      _state = SessionState.idle;
    });
    await _dropVideo();
  }

  // _isTooShort — true, если видео короче 2 секунд
  Future<bool> _isTooShort(String path) async {
    final c = VideoPlayerController.file(File(path));
    try {
      await c.initialize().timeout(const Duration(seconds: 10));
      final d = c.value.duration;
      return d > Duration.zero && d < const Duration(seconds: 2);
    } catch (_) {
      return false;
    } finally {
      await c.dispose();
    }
  }

  // _deleteQuietly — удаляет временную копию видео
  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  // _finish — завершает занятие и открывает сводку
  void _finish() {
    if (_session.attempts.isEmpty) {
      Navigator.popUntil(context, (r) => r.isFirst);
    } else {
      Navigator.pushReplacementNamed(context, '/summary', arguments: _session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final def = exerciseDef(_session.exercise);
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => ValueListenableBuilder(
        valueListenable: catalog,
        builder: (context, entries, _) {
          final availability = exerciseAvailability(entries, def.id);
          return PopScope(
            canPop: _state != SessionState.analyzing,
            child: PageShell(
              tab: AppTab.home,
              controller: _scroll,
              children: [
                Text(tr('session_title'), style: AppText.title),
                const SizedBox(height: 4),
                Text(
                  tr(def.titleKey),
                  style: AppText.bodyStrong.copyWith(
                    color: AppColors.link,
                    fontSize: 20,
                    height: 30 / 20,
                  ),
                ),
                const SizedBox(height: 24),
                if (availability == 'loading')
                  Text(tr('loading'), style: AppText.small)
                else if (availability == 'soon') ...[
                  MessageBox(text: tr('exercise_soon_hint')),
                  const SizedBox(height: 12),
                  BigButton(
                    label: tr('back_to_exercises'),
                    kind: ButtonKind.secondary,
                    onPressed: () => goTab(context, AppTab.home),
                  ),
                ] else
                  ..._body(def),
              ],
            ),
          );
        },
      ),
    );
  }

  // _body — содержимое занятия по этапу и список повторений
  List<Widget> _body(ExerciseDef def) {
    final time = DateFormat('HH:mm');
    return [
      if (_state == SessionState.idle) _idleCard(def),
      if (_state == SessionState.analyzing) const AnalyzingCard(),
      if (_state == SessionState.result && _result != null)
        ResultView(
          result: _result!,
          videoPath: _videoPath,
          onAnother: _another,
        ),
      if (_state == SessionState.error) ..._errorBlock(),
      if (_session.attempts.isNotEmpty && _state != SessionState.analyzing) ...[
        const SizedBox(height: 28),
        Text(tr('attempts_title'), style: AppText.h2),
        const SizedBox(height: 16),
        for (var i = 0; i < _session.attempts.length; i++) ...[
          AttemptTile(
            number: i + 1,
            time: time.format(_session.attempts[i].at.toLocal()),
            label: _session.attempts[i].label,
            exercise: _session.exercise,
            confidence: _session.attempts[i].confidence,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        BigButton(
          label: tr('finish_session'),
          icon: Icons.flag_outlined,
          kind: ButtonKind.secondary,
          onPressed: _finish,
        ),
      ],
    ];
  }

  // _idleCard — карточка с напоминанием о съёмке и кнопками записи и загрузки
  Widget _idleCard(ExerciseDef def) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_session.attempts.isEmpty) ...[
            Text(tr('session_hint'), style: AppText.bodyStrong),
            const SizedBox(height: 16),
          ],
          _Reminder(
            text: tr(def.reminderKey),
            onInstruction: () => Navigator.pushNamed(
              context,
              '/exercise',
              arguments: ExerciseArgs(def.id, fromSession: true),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            const Text('mock_scenario', style: AppText.smallStrong),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _mockScenarios)
                  FilterChipButton(
                    label: s,
                    selected: _mockScenario == s,
                    onPressed: () => setState(
                      () => _mockScenario = _mockScenario == s ? null : s,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          BigButton(
            label: tr('record_camera'),
            icon: Icons.videocam_outlined,
            onPressed: () => _run(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          BigButton(
            label: tr('upload_video'),
            icon: Icons.file_upload_outlined,
            kind: ButtonKind.secondary,
            onPressed: () => _run(ImageSource.gallery),
          ),
          const SizedBox(height: 12),
          Text(tr('upload_formats'), style: AppText.small),
        ],
      ),
    );
  }

  // _errorBlock — сообщение об ошибке и кнопки: инструкция и «Попробовать снова»
  List<Widget> _errorBlock() {
    final code = _errorCode ?? 'internal_error';
    return [
      MessageBox(
        text: trError(code, _session.exercise),
        kind: MessageKind.error,
      ),
      const SizedBox(height: 16),
      if (instructionErrors.contains(code)) ...[
        BigButton(
          label: tr('watch_instruction'),
          kind: ButtonKind.secondary,
          onPressed: () => Navigator.pushNamed(
            context,
            '/exercise',
            arguments: ExerciseArgs(_session.exercise, fromSession: true),
          ),
        ),
        const SizedBox(height: 12),
      ],
      BigButton(
        label: tr('try_again'),
        icon: Icons.replay_rounded,
        onPressed: _another,
      ),
    ];
  }
}

// _Reminder — плашка с напоминанием о съёмке и ссылкой на инструкцию
class _Reminder extends StatelessWidget {
  final String text;
  final VoidCallback onInstruction;

  const _Reminder({required this.text, required this.onInstruction});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(AppSizes.messageRadius),
        border: Border.all(color: AppColors.brandSoft2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline_rounded,
              color: AppColors.neutralInk,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppText.body.copyWith(color: AppColors.neutralInk),
                ),
                InkWell(
                  onTap: onInstruction,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tr('watch_instruction'),
                        style: AppText.bodyStrong.copyWith(
                          color: AppColors.neutralInk,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
