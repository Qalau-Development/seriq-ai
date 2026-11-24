import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/page_shell.dart';

// ExerciseScreen — видеоинструкция, шаги упражнения и советы по съёмке
class ExerciseScreen extends StatefulWidget {
  final bool fromSession;

  const ExerciseScreen({super.key, this.fromSession = false});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  VideoPlayerController? _video;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  // _initVideo — загружает видеоинструкцию с сервера
  Future<void> _initVideo() async {
    final controller = VideoPlayerController.networkUrl(
        Uri.parse(AppConfig.instructionVideoUrl));
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _video = controller);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _videoFailed = true);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  // _togglePlay — запускает или ставит видео на паузу
  void _togglePlay() {
    final v = _video;
    if (v == null) return;
    setState(() => v.value.isPlaying ? v.pause() : v.play());
  }

  // _ready — переходит к занятию или возвращает в него
  void _ready() {
    if (widget.fromSession) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/session');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      tab: AppTab.home,
      children: [
        Text(tr('exercise_e02_title'), style: AppText.title),
        const SizedBox(height: 20),
        _buildVideo(context),
        const SizedBox(height: 24),
        Text(tr('instruction_title'), style: AppText.h2),
        const SizedBox(height: 8),
        for (var i = 1; i <= 4; i++)
          _NumberedLine(number: i, text: tr('instruction_step_$i')),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('tips_title'), style: AppText.h2),
              const SizedBox(height: 8),
              for (var i = 1; i <= 4; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.videocam_outlined,
                        size: 24,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tr('tip_$i'), style: AppText.body)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BigButton(
          label: tr('ready'),
          icon: Icons.check_rounded,
          onPressed: _ready,
        ),
      ],
    );
  }

  // _buildVideo — плеер, индикатор загрузки или запасной текст
  Widget _buildVideo(BuildContext context) {
    final v = _video;
    if (_videoFailed) {
      return MessageBox(
        text: tr('instruction_video_missing'),
        icon: Icons.ondemand_video_rounded,
      );
    }
    if (v == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: _togglePlay,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.messageRadius),
        child: AspectRatio(
          aspectRatio: v.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(v),
              if (!v.value.isPlaying)
                Container(
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 64, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// _NumberedLine — пронумерованный шаг инструкции
class _NumberedLine extends StatelessWidget {
  final int number;
  final String text;

  const _NumberedLine({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            child: Text(
              '$number',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.body)),
        ],
      ),
    );
  }
}
