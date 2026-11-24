import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/analysis_result.dart';

// PoseStyle — цвета и толщина линии руки, одинаковые с сайтом
class PoseStyle {
  static const line = Color(0xFF22C55E);
  static const lineWidth = 6.0;
  static const jointRadius = 7.0;
  static const jointBorder = Color(0xFFFFFFFF);
  static const jointBorderWidth = 2.0;
  static const handDot = Color(0xCCFFFFFF);
  static const handDotRadius = 3.0;
}

// PoseVideo — запись пользователя с линией локоть → запястье поверх кадра
class PoseVideo extends StatefulWidget {
  final String videoPath;
  final Pose? pose;
  final double maxHeight;

  const PoseVideo({
    super.key,
    required this.videoPath,
    this.pose,
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

  // _init — открывает видео, без звука и по кругу
  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setVolume(0);
      await _controller.setLooping(true);
      await _controller.play();
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

  // _toggle — пауза или воспроизведение по нажатию
  void _toggle() {
    setState(
      () => _controller.value.isPlaying
          ? _controller.pause()
          : _controller.play(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    if (!_ready) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
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
          child: GestureDetector(
            onTap: _toggle,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(_controller),
                    if (widget.pose != null)
                      CustomPaint(
                        painter: PosePainter(
                          pose: widget.pose!,
                          controller: _controller,
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
                                  size: 56,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// PosePainter — рисует кадр pose для текущей позиции видео, только точки из ответа
class PosePainter extends CustomPainter {
  final Pose pose;
  final VideoPlayerController controller;

  PosePainter({required this.pose, required this.controller})
    : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    paintFrame(
      canvas,
      size,
      pose.elbow,
      pose.frameAt(controller.value.position),
    );
  }

  // paintFrame — линия локоть → запястье, точки локтя, запястья и кисти; null — ничего
  static void paintFrame(
    Canvas canvas,
    Size size,
    Offset elbow,
    PoseFrame? frame,
  ) {
    if (frame == null) return;
    Offset px(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    final e = px(elbow);
    final w = px(frame.wrist);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawLine(
      e,
      w,
      Paint()
        ..color = PoseStyle.line
        ..strokeWidth = PoseStyle.lineWidth
        ..strokeCap = StrokeCap.round,
    );
    final dot = Paint()..color = PoseStyle.handDot;
    for (final p in frame.hand.skip(1)) {
      canvas.drawCircle(px(p), PoseStyle.handDotRadius, dot);
    }
    final fill = Paint()..color = PoseStyle.line;
    final border = Paint()
      ..color = PoseStyle.jointBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = PoseStyle.jointBorderWidth;
    for (final j in [e, w]) {
      canvas.drawCircle(j, PoseStyle.jointRadius, fill);
      canvas.drawCircle(j, PoseStyle.jointRadius, border);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PosePainter old) =>
      old.pose != pose || old.controller != controller;
}
