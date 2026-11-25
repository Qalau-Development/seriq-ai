import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import 'app_card.dart';

// slowAfter — через сколько после начала анализа появляется плашка «Сервер занят»
const slowAfter = Duration(seconds: 15);

// AnalyzingCard — экран ожидания анализа; через 15 секунд добавляет плашку, что сервер занят
class AnalyzingCard extends StatefulWidget {
  const AnalyzingCard({super.key});

  @override
  State<AnalyzingCard> createState() => _AnalyzingCardState();
}

class _AnalyzingCardState extends State<AnalyzingCard> {
  late final Timer _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(tr('analyzing'), style: AppText.h2)),
            ],
          ),
          const SizedBox(height: 20),
          Text(tr('analyzing_hint'), style: AppText.small.copyWith(fontSize: 18, height: 27 / 18)),
          if (_slow) ...[
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: MessageBox(text: tr('analyzing_slow')),
            ),
          ],
        ],
      ),
    );
  }
}
