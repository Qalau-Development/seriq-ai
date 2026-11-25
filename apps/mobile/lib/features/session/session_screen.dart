import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/analysis_result.dart';
import '../../models/session.dart';
import '../../services/api_client.dart';
import '../../services/history_storage.dart';
import '../../services/video_cache.dart';
import '../../widgets/app_card.dart';
import '../../widgets/attempt_tile.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/page_shell.dart';
import '../result/result_screen.dart';

// SessionScreen — занятие: запись повторений, отправка на анализ, список попыток
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  static const _mockScenarios = ['complete', 'incomplete', 'uncertain', 'no_pose'];

  final _api = ApiClient();
  final _storage = HistoryStorage();
  final _picker = ImagePicker();
  final _session = Session(id: const Uuid().v4(), startedAt: DateTime.now());
  bool _busy = false;
  String? _errorCode;
  String? _mockScenario;

  // _run — снимает или выбирает видео и отправляет его на анализ
  Future<void> _run(ImageSource source) async {
    setState(() => _errorCode = null);
    XFile? file;
    try {
      file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
    } on PlatformException catch (e) {
      setState(() => _errorCode =
          e.code.contains('denied') ? 'camera_denied' : 'internal_error');
      return;
    }
    if (file == null) return;
    await deleteOldVideoCopies(file.path);

    setState(() => _busy = true);
    AnalysisResult? result;
    try {
      if (await _isTooShort(file.path)) {
        throw ApiException(source == ImageSource.camera
            ? 'recording_too_short'
            : 'video_too_short');
      }
      result = await _api.analyze(file.path,
          exercise: _session.exercise,
          mockScenario: kDebugMode ? _mockScenario : null);
      _session.attempts.add(Attempt.fromResult(result, DateTime.now()));
      await _storage.saveSession(_session);
    } on ApiException catch (e) {
      _errorCode = e.code;
    } catch (_) {
      _errorCode = 'internal_error';
    }
    if (result == null || !mounted) {
      await _deleteQuietly(file.path);
      if (mounted) setState(() => _busy = false);
      return;
    }
    setState(() => _busy = false);
    final r = result;
    final path = file.path;
    try {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ResultScreen(result: r, videoPath: path)));
    } finally {
      await _deleteQuietly(path);
    }
    if (mounted) setState(() {});
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

  // _deleteQuietly — удаляет временную копию видео после анализа
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
    final time = DateFormat('HH:mm');
    return PopScope(
      canPop: !_busy,
      child: Stack(
        children: [
          PageShell(
            tab: AppTab.home,
            children: [
              Text(tr('session_title'), style: AppText.title),
              const SizedBox(height: 4),
              Text(
                tr('exercise_e02_title'),
                style: AppText.bodyStrong.copyWith(color: AppColors.link),
              ),
              const SizedBox(height: 12),
              Text(tr('session_hint'), style: AppText.body),
              const SizedBox(height: 16),
              MessageBox(
                text: tr('session_reminder'),
                icon: Icons.videocam_outlined,
              ),
              if (_errorCode != null) ...[
                const SizedBox(height: 12),
                MessageBox(text: trError(_errorCode!), kind: MessageKind.error),
              ],
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
                label: tr('record_on_phone'),
                icon: Icons.videocam_rounded,
                onPressed: _busy ? null : () => _run(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              BigButton(
                label: tr('upload_video'),
                icon: Icons.photo_library_outlined,
                kind: ButtonKind.secondary,
                onPressed: _busy ? null : () => _run(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
              Text(
                tr('upload_formats'),
                textAlign: TextAlign.center,
                style: AppText.small,
              ),
              if (_session.attempts.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(tr('attempts_title'), style: AppText.h2),
                const SizedBox(height: 12),
                for (var i = 0; i < _session.attempts.length; i++) ...[
                  AttemptTile(
                    number: i + 1,
                    time: time.format(_session.attempts[i].at.toLocal()),
                    label: _session.attempts[i].label,
                    verdict: _session.attempts[i].verdict,
                    confidence: _session.attempts[i].confidence,
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                BigButton(
                  label: tr('finish_session'),
                  icon: Icons.flag_outlined,
                  kind: ButtonKind.secondary,
                  onPressed: _busy ? null : _finish,
                ),
              ],
            ],
          ),
          if (_busy) const _AnalyzingOverlay(),
        ],
      ),
    );
  }
}

// _AnalyzingOverlay — индикатор «Анализируем движение…» поверх экрана
class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x990E2237),
        child: Center(
          child: AppCard(
            padding: const EdgeInsets.all(28),
            radius: AppSizes.cardRadius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  tr('analyzing'),
                  textAlign: TextAlign.center,
                  style: AppText.h2,
                ),
                const SizedBox(height: 8),
                Text(
                  tr('analyzing_hint'),
                  textAlign: TextAlign.center,
                  style: AppText.small,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
