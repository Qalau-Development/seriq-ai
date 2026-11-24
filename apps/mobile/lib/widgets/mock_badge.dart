import 'package:material_ui/material_ui.dart';

import 'app_card.dart';

// MockBadge — плашка «Тестовые данные» для ответов с source == "mock"
class MockBadge extends StatelessWidget {
  final String text;

  const MockBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return MessageBox(
      text: text,
      kind: MessageKind.warn,
      icon: Icons.science_outlined,
    );
  }
}
