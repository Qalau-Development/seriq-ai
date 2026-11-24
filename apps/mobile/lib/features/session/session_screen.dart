import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../core/strings.dart';
import '../../models/analysis_result.dart';
import '../../models/session.dart';
import '../../services/api_client.dart';
import '../../services/history_storage.dart';
import '../../widgets/big_button.dart';
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

    setState(() => _busy = true);
    AnalysisResult? result;
    try {
      if (await _isTooShort(file.path)) {
        throw ApiException(source == ImageSource.camera
            ? 'recording_too_short'
            : 'video_too_short');
      }
      result = await _api.analyze(file.path,
          mockScenario: kDebugMode ? _mockScenario : null);
      _session.attempts.add(Attempt.fromResult(result, DateTime.now()));
      await _storage.saveSession(_session);
    } on ApiException catch (e) {
      _errorCode = e.code;
    } catch (_) {
      _errorCode = 'internal_error';
    } finally {
      await _deleteQuietly(file.path);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      final r = result;
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => ResultScreen(result: r)));
      if (mounted) setState(() {});
    }
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
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(tr('session_title'))),
        body: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(tr('session_hint')),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.videocam_outlined, size: 28),
                          const SizedBox(width: 12),
                          Expanded(child: Text(tr('session_reminder'))),
                        ],
                      ),
                    ),
                  ),
                  if (_errorCode != null) ...[
                    const SizedBox(height: 12),
                    _ErrorCard(text: trError(_errorCode!)),
                  ],
                  if (kDebugMode) ...[
                    const SizedBox(height: 12),
                    Text(tr('debug_mock_title'), style: text.labelLarge),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final s in _mockScenarios)
                          ChoiceChip(
                            label: Text(s),
                            selected: _mockScenario == s,
                            onSelected: (on) =>
                                setState(() => _mockScenario = on ? s : null),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  BigButton(
                    label: tr('record_attempt'),
                    icon: Icons.videocam_rounded,
                    onPressed: _busy ? null : () => _run(ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  BigButton(
                    label: tr('pick_video'),
                    icon: Icons.photo_library_outlined,
                    primary: false,
                    onPressed: _busy ? null : () => _run(ImageSource.gallery),
                  ),
                  const SizedBox(height: 8),
                  Text(tr('upload_formats'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  Text(tr('attempts_title'), style: text.titleLarge),
                  const SizedBox(height: 8),
                  if (_session.attempts.isEmpty) Text(tr('attempts_empty')),
                  for (var i = 0; i < _session.attempts.length; i++)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          _session.attempts[i].verdict == 'completed'
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          color: _session.attempts[i].verdict == 'completed'
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          size: 32,
                        ),
                        title: Text(
                            '${tr('attempt_n')} ${i + 1}: ${tr('verdict_${_session.attempts[i].verdict}')}'),
                        subtitle: Text(tr('label_${_session.attempts[i].label}')),
                      ),
                    ),
                  const SizedBox(height: 24),
                  BigButton(
                    label: tr('finish_session'),
                    icon: Icons.flag_outlined,
                    primary: false,
                    onPressed: _busy ? null : _finish,
                  ),
                ],
              ),
            ),
            if (_busy) const _AnalyzingOverlay(),
          ],
        ),
      ),
    );
  }
}

// _ErrorCard — понятное сообщение об ошибке по её коду
class _ErrorCard extends StatelessWidget {
  final String text;

  const _ErrorCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded,
              color: scheme.onErrorContainer, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(color: scheme.onErrorContainer, fontSize: 18)),
          ),
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
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(strokeWidth: 6),
                  ),
                  const SizedBox(height: 20),
                  Text(tr('analyzing'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(tr('analyzing_hint'), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
