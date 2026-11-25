import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../core/instruction_clips.dart';
import '../core/strings.dart';
import '../core/theme.dart';

// InstructionClipsView — два вертикальных видео рядом: слева правильная съёмка, справа по очереди неправильные примеры
class InstructionClipsView extends StatelessWidget {
  final String exerciseId;

  const InstructionClipsView({super.key, required this.exerciseId});

  @override
  Widget build(BuildContext context) {
    final clips = instructionClips[exerciseId];
    if (clips == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('clips_title'), style: AppText.h2),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ClipPanel(
                key: ValueKey('$exerciseId-correct'),
                correct: true,
                clips: clips.correct,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ClipPanel(
                key: ValueKey('$exerciseId-wrong'),
                correct: false,
                clips: clips.wrong,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// _ClipPanel — метка, видео и подпись; несколько роликов сменяются по окончании
class _ClipPanel extends StatefulWidget {
  final bool correct;
  final List<InstructionClip> clips;

  const _ClipPanel({super.key, required this.correct, required this.clips});

  @override
  State<_ClipPanel> createState() => _ClipPanelState();
}

class _ClipPanelState extends State<_ClipPanel> {
  VideoPlayerController? _video;
  int _index = 0;
  bool _autoplay = true;
  bool _advancing = false;

  bool get _many => widget.clips.length > 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final autoplay = !MediaQuery.disableAnimationsOf(context);
    if (_video == null) {
      _autoplay = autoplay;
      _load(_index);
    }
  }

  // _load — открывает ролик из ресурсов приложения, без звука
  Future<void> _load(int index) async {
    final old = _video;
    final controller = VideoPlayerController.asset(widget.clips[index].asset);
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(!_many);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onTick);
      setState(() {
        _index = index;
        _video = controller;
        _advancing = false;
      });
      await old?.dispose();
      if (_autoplay) await controller.play();
    } catch (_) {
      await controller.dispose();
    }
  }

  // _onTick — по окончании ролика переходит к следующему
  void _onTick() {
    final v = _video;
    if (v == null || !_many || _advancing) return;
    final value = v.value;
    if (value.isInitialized &&
        !value.isPlaying &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _advancing = true;
      _load(nextClipIndex(_index, widget.clips.length));
    }
  }

  // _togglePlay — пауза и воспроизведение по нажатию
  void _togglePlay() {
    final v = _video;
    if (v == null) return;
    setState(() => v.value.isPlaying ? v.pause() : v.play());
  }

  @override
  void dispose() {
    _video?.removeListener(_onTick);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    final clip = widget.clips[_index];
    final correct = widget.correct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.messageRadius),
          child: ColoredBox(
            color: const Color(0xFF0B1E33),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: correct ? AppColors.brand : AppColors.errorSoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        correct
                            ? Icons.check_circle_outline_rounded
                            : Icons.cancel_outlined,
                        size: 20,
                        color: correct ? Colors.white : AppColors.errorInk,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tr(correct ? 'clips_correct' : 'clips_wrong'),
                          style: AppText.bodyStrong.copyWith(
                            color: correct ? Colors.white : AppColors.errorInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _togglePlay,
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: v == null
                        ? const Center(
                            child: Icon(
                              Icons.videocam_outlined,
                              size: 40,
                              color: Colors.white54,
                            ),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: v.value.size.width,
                                    height: v.value.size.height,
                                    child: VideoPlayer(v),
                                  ),
                                ),
                              ),
                              if (!v.value.isPlaying)
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 44,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          liveRegion: _many,
          child: Text(tr(clip.captionKey), style: AppText.small),
        ),
        if (_many)
          Wrap(
            children: [
              for (var i = 0; i < widget.clips.length; i++)
                Semantics(
                  button: true,
                  selected: i == _index,
                  label: tr('clips_example')
                      .replaceAll('{n}', '${i + 1}')
                      .replaceAll('{total}', '${widget.clips.length}'),
                  child: InkResponse(
                    onTap: i == _index ? null : () => _load(i),
                    radius: 22,
                    child: SizedBox(
                      width: AppSizes.touch,
                      height: AppSizes.touch,
                      child: Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _index
                                ? AppColors.errorInk
                                : AppColors.lineStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
