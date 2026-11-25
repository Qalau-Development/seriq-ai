import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../models/analysis_result.dart';
import 'app_card.dart';

// PoseStyle — цвета и толщина линии руки, одинаковые с сайтом
class PoseStyle {
  static const line = Color(0xFF22C55E);
  static const lineWidth = 6.0;
  static const outline = Color(0x8C000000);
  static const jointRadius = 8.0;
  static const jointFill = Color(0xFFFFFFFF);
  static const handDot = Color(0xE6FFFFFF);
  static const handDotRadius = 3.0;
  static const bone = Color(0xF222C55E);
  static const boneWidth = 3.0;
  static const tipRadius = 5.5;
  static const tipFill = Color(0xFFFACC15);
}

// handLinks — кости кисти: пары точек MediaPipe Hand Landmarker
const handLinks = <(int, int)>[
  (0, 1), (1, 2), (2, 3), (3, 4),
  (0, 5), (5, 6), (6, 7), (7, 8),
  (5, 9), (9, 10), (10, 11), (11, 12),
  (9, 13), (13, 14), (14, 15), (15, 16),
  (13, 17), (17, 18), (18, 19), (19, 20),
  (0, 17),
];
const _fingertips = {4, 8, 12, 16, 20};

// PoseVideo — запись пользователя с точками кисти и линией локтя (если он известен) поверх кадра
class PoseVideo extends StatefulWidget {
  final String videoPath;
  final Pose? pose;
  final Offset? liftStart;
  final double maxHeight;

  const PoseVideo({
    super.key,
    required this.videoPath,
    this.pose,
    this.liftStart,
    this.maxHeight = 420,
  });

  @override
  State<PoseVideo> createState() => _PoseVideoState();
}

class _PoseVideoState extends State<PoseVideo> {
  late final VideoPlayerController _controller = VideoPlayerController.file(
    File(widget.videoPath),
  );
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // _init — открывает видео без звука
  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setVolume(0);
      await _controller.setLooping(true);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // _toggle — пауза или воспроизведение
  void _toggle() {
    setState(
      () => _controller.value.isPlaying
          ? _controller.pause()
          : _controller.play(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return MessageBox(text: tr('pose_video_unsupported'));
    }
    if (!_ready) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      );
    }
    final pose = widget.pose;
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = _controller.value.aspectRatio;
        var width = constraints.maxWidth;
        var height = width / ratio;
        if (height > widget.maxHeight) {
          height = widget.maxHeight;
          width = height * ratio;
        }
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.messageRadius),
            child: Container(
              color: const Color(0xFF0B1E33),
              width: constraints.maxWidth,
              child: Column(
                children: [
                  SizedBox(
                    width: width,
                    height: height,
                    child: GestureDetector(
                      onTap: _toggle,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          VideoPlayer(_controller),
                          if (pose != null)
                            CustomPaint(
                              painter: PosePainter(
                                pose: pose,
                                controller: _controller,
                                missingText: tr('pose_no_hand'),
                                liftStart: widget.liftStart,
                              ),
                            ),
                          ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: _controller,
                            builder: (context, value, _) => value.isPlaying
                                ? const SizedBox.shrink()
                                : Center(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 48,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _Controls(controller: _controller, onToggle: _toggle),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// _Controls — кнопка воспроизведения, полоса перемотки и время
class _Controls extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onToggle;

  const _Controls({required this.controller, required this.onToggle});

  // _fmt — время в виде 0:05
  static String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              onPressed: onToggle,
              icon: Icon(
                value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            ),
            Text(
              '${_fmt(value.position)} / ${_fmt(value.duration)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Color(0x55FFFFFF),
                  backgroundColor: Color(0x33FFFFFF),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

// PosePainter — рисует точки кисти для текущей позиции видео, только точки из ответа
class PosePainter extends CustomPainter {
  final Pose pose;
  final VideoPlayerController controller;
  final String missingText;
  final Offset? liftStart;

  PosePainter({
    required this.pose,
    required this.controller,
    this.missingText = '',
    this.liftStart,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final position = controller.value.position;
    final hand = pose.handAt(position);
    paintHand(
      canvas,
      size,
      pose.elbow,
      hand,
      missingText: missingText,
      liftStart: liftStart,
    );
  }

  // paintHand — кисть со скелетом, линия локоть → запястье (если локоть есть) и белые суставы; нет кисти — подпись
  static void paintHand(
    Canvas canvas,
    Size size,
    Offset? elbow,
    List<Offset>? hand, {
    String missingText = '',
    Offset? liftStart,
  }) {
    if (hand == null) {
      if (missingText.isNotEmpty) _paintMissing(canvas, missingText);
      return;
    }
    Offset px(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    final e = elbow == null ? null : px(elbow);
    final joints = hand.map(px).toList();
    final w = joints[0];
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final round = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (liftStart != null) {
      final sy = px(liftStart).dy;
      final dash = Paint()
        ..color = const Color(0xE6FFFFFF)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      for (var x = 0.0; x < size.width; x += 18) {
        canvas.drawLine(Offset(x, sy), Offset(math.min(x + 10, size.width), sy), dash);
      }
      final foot = Offset(w.dx, sy);
      canvas.drawLine(
        foot,
        w,
        round
          ..color = PoseStyle.outline
          ..strokeWidth = PoseStyle.lineWidth + 4,
      );
      canvas.drawLine(
        foot,
        w,
        round
          ..color = PoseStyle.tipFill
          ..strokeWidth = PoseStyle.lineWidth,
      );
    }
    if (e != null) {
      canvas.drawLine(
        e,
        w,
        round
          ..color = PoseStyle.outline
          ..strokeWidth = PoseStyle.lineWidth + 4,
      );
      canvas.drawLine(
        e,
        w,
        round
          ..color = PoseStyle.line
          ..strokeWidth = PoseStyle.lineWidth,
      );
    }
    final bones = Path();
    for (final (a, b) in handLinks) {
      if (a < joints.length && b < joints.length) {
        bones
          ..moveTo(joints[a].dx, joints[a].dy)
          ..lineTo(joints[b].dx, joints[b].dy);
      }
    }
    canvas.drawPath(
      bones,
      round
        ..color = PoseStyle.outline
        ..strokeWidth = PoseStyle.boneWidth + 3,
    );
    canvas.drawPath(
      bones,
      round
        ..color = PoseStyle.bone
        ..strokeWidth = PoseStyle.boneWidth,
    );
    for (var n = 1; n < joints.length; n++) {
      final tip = _fingertips.contains(n);
      canvas.drawCircle(
        joints[n],
        tip ? PoseStyle.tipRadius : PoseStyle.handDotRadius,
        Paint()..color = tip ? PoseStyle.tipFill : PoseStyle.handDot,
      );
    }
    final fill = Paint()..color = PoseStyle.jointFill;
    final border = Paint()
      ..color = PoseStyle.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final j in [?e, w]) {
      canvas.drawCircle(j, PoseStyle.jointRadius, fill);
      canvas.drawCircle(j, PoseStyle.jointRadius, border);
    }
    canvas.restore();
  }

  // _paintMissing — подпись «Кисть в этом кадре не найдена» на тёмной плашке
  static void _paintMissing(Canvas canvas, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, painter.width + 24, 34),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0x99000000));
    painter.paint(canvas, Offset(24, 12 + (34 - painter.height) / 2));
  }

  @override
  bool shouldRepaint(PosePainter old) =>
      old.pose != pose || old.controller != controller;
}
