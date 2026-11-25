import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../core/voice_items.dart';
import '../services/speech.dart';
import '../services/voice.dart';
import 'big_button.dart';

// SpeakButton — «Озвучить»: играет записанные клипы по id, а где клипа нет, читает текст запасным голосом устройства; кнопки нет, если нет ни клипов, ни голоса
class SpeakButton extends StatefulWidget {
  final List<VoiceItem> items;

  const SpeakButton({super.key, required this.items});

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {
  bool _ttsAvailable = false;
  bool _speaking = false;
  String _checkedLang = '';

  @override
  void initState() {
    super.initState();
    voicePlayer.load();
    voicePlayer.addListener(_onManifest);
    _checkTts();
  }

  @override
  void didUpdateWidget(covariant SpeakButton old) {
    super.didUpdateWidget(old);
    if (_ids(old.items) != _ids(widget.items)) _stop();
  }

  @override
  void dispose() {
    voicePlayer.removeListener(_onManifest);
    _stop();
    super.dispose();
  }

  String _ids(List<VoiceItem> items) => items.map((i) => i.id).join(',');

  // _onManifest — манифест загрузился: кнопка может появиться или скрыться
  void _onManifest() {
    if (mounted) setState(() {});
  }

  // _checkTts — есть ли в системе голос для текущего языка
  Future<void> _checkTts() async {
    final lang = appLang.value;
    _checkedLang = lang;
    final ok = await speechEngine.isAvailable(lang);
    if (mounted && appLang.value == lang) setState(() => _ttsAvailable = ok);
  }

  // _stop — останавливает озвучивание без ожидания
  void _stop() {
    if (_speaking) voicePlayer.stop();
    _speaking = false;
  }

  // _toggle — запускает или останавливает озвучивание
  Future<void> _toggle() async {
    if (_speaking) {
      await voicePlayer.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await voicePlayer.playClips(
      widget.items,
      appLang.value,
      onEnd: () {
        if (mounted) setState(() => _speaking = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) {
        if (lang != _checkedLang) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _checkTts());
        }
        final hasClip = voicePlayer.hasClip(widget.items, lang);
        if (!_ttsAvailable && !hasClip || widget.items.isEmpty) {
          return const SizedBox.shrink();
        }
        return BigButton(
          label: tr(_speaking ? 'speak_stop' : 'speak_start'),
          icon: _speaking ? Icons.stop_rounded : Icons.volume_up_outlined,
          kind: ButtonKind.secondary,
          onPressed: _toggle,
        );
      },
    );
  }
}
