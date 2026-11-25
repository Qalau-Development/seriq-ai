import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../services/history_view.dart';
import '../services/sync_runtime.dart';

// SyncNotice — состояние сохранения занятий в аккаунте: сохраняем, сохранено, нет связи, вход истёк, предел истории, сервер не принял; гостю ничего не показывает
class SyncNotice extends StatelessWidget {
  const SyncNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: historyView.changes,
      builder: (context, _) {
        final status = syncRuntime.status.value;
        if (historyView.mode.kind != AccountModeKind.account ||
            status == SyncState.idle) {
          return const SizedBox.shrink();
        }
        final text = switch (status) {
          SyncState.syncing => tr('sync_syncing'),
          SyncState.ok => tr('sync_ok'),
          SyncState.offline => tr('sync_offline'),
          SyncState.auth => tr('sync_auth'),
          SyncState.quota => tr('sync_quota'),
          _ => tr('sync_error'),
        };
        final problem = const [
          SyncState.offline,
          SyncState.auth,
          SyncState.quota,
          SyncState.error,
        ].contains(status);
        final icon = switch (status) {
          SyncState.syncing => Icons.sync_rounded,
          SyncState.ok => Icons.check_circle_outline_rounded,
          SyncState.offline => Icons.cloud_off_rounded,
          _ => Icons.info_outline_rounded,
        };
        final ink = problem ? AppColors.warnInk : AppColors.neutralInk;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: problem ? AppColors.warnSoft : AppColors.neutralSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: problem ? AppColors.warnLine : AppColors.brandSoft2,
                  width: problem ? 2 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: ink, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: text),
                          if (status == SyncState.auth) ...[
                            const TextSpan(text: ' '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).pushNamed('/login'),
                                child: Text(
                                  tr('nav_login'),
                                  style: AppText.small.copyWith(
                                    color: ink,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      style: AppText.small.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
