import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../services/speech.dart';
import 'big_button.dart';

// SpeakButton — «Озвучить»: читает вслух только слова с экрана; если для языка нет голоса, кнопки нет
class SpeakButton extends StatefulWidget {
  final String text;

  const SpeakButton({super.key, required this.text});

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {
  bool _available = false;
  bool _speaking = false;
  String _lang = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(SpeakButton old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _stop();
  }

  @override
  void dispose() {
    speechEngine.stop();
    super.dispose();
  }

  // _check — есть ли голос для языка интерфейса
  Future<void> _check() async {
    final lang = appLang.value;
    _lang = lang;
    final ok = await speechEngine.isAvailable(lang);
    if (mounted && lang == _lang) setState(() => _available = ok);
  }

  // _stop — останавливает озвучивание
  void _stop() {
    if (_speaking) {
      speechEngine.stop();
      _speaking = false;
    }
  }

  // _toggle — запускает или останавливает озвучивание
  Future<void> _toggle() async {
    if (_speaking) {
      await speechEngine.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await speechEngine.speak(widget.text, appLang.value, () {
      if (mounted) setState(() => _speaking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) {
        if (lang != _lang) {
          _stop();
          WidgetsBinding.instance.addPostFrameCallback((_) => _check());
        }
        if (!_available || widget.text.isEmpty) return const SizedBox.shrink();
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
