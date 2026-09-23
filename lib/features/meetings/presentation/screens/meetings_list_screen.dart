import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/features/meetings/data/models/meeting_model.dart';
import 'package:lms/features/meetings/presentation/meeting_join.dart';
import 'package:lms/features/meetings/presentation/meetings_access.dart';
import 'package:lms/features/meetings/presentation/providers/meeting_session_provider.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
import 'package:lms/features/meetings/presentation/widgets/create_meeting_sheet.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';

class MeetingsListScreen extends ConsumerStatefulWidget {
  const MeetingsListScreen({super.key});

  @override
  ConsumerState<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends ConsumerState<MeetingsListScreen> {
  String? _joiningId;

  static const _tabs = [
    ('upcoming', 'Upcoming'),
    ('recurring', 'Recurring'),
    ('past', 'Past'),
    ('all', 'All'),
  ];

  Future<void> _refresh() async {
    ref.invalidate(meetingsListProvider);
    await ref.read(meetingsListProvider.future);
  }

  Future<void> _join(String id, {String? title}) async {
    if (_joiningId != null) return;
    setState(() => _joiningId = id);
    try {
      await joinMeetingById(context, ref, meetingId: id, title: title);
    } finally {
      if (mounted) setState(() => _joiningId = null);
    }
  }

  Color _statusColor(String status, ColorScheme scheme) {
    if (status == 'cancelled') return scheme.error;
    if (status == 'ended') return scheme.outline;
    return const Color(0xFF059669);
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(meetingsListProvider);
    final session = ref.watch(meetingSessionProvider);
    final tab = ref.watch(meetingsTabProvider);
    final canCreate = ref.watch(canCreateMeetingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final scrollPhysics = isIOS
        ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
        : const AlwaysScrollableScrollPhysics();

    return Scaffold(
      appBar: AppAppBar(
        title: 'Meetings',
        showBack: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => showCreateMeetingSheet(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Schedule'),
            )
          : null,
      body: Column(
        children: [
          PremiumFeatureHeader(
            icon: Icons.videocam_rounded,
            title: 'Meetings',
            subtitle: 'Internal discussions, standups, and presentations',
            trailing: canCreate
                ? TextButton.icon(
                    onPressed: () =>
                        showCreateMeetingSheet(context, ref, type: 'instant'),
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Start now'),
                  )
                : null,
          ),
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              physics: isIOS
                  ? const BouncingScrollPhysics()
                  : const ClampingScrollPhysics(),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (key, label) = _tabs[i];
                final selected = tab == key;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) =>
                      ref.read(meetingsTabProvider.notifier).select(key),
                  labelStyle: TextStyle(
                    color: selected
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: listAsync.when(
                loading: () => ListView(
                  physics: scrollPhysics,
                  children: const [
                    SizedBox(height: 120),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
                error: (e, _) => ListView(
                  physics: scrollPhysics,
                  padding: const EdgeInsets.all(24),
                  children: [
                    PremiumEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load meetings',
                      subtitle: cleanApiError(e),
                    ),
                  ],
                ),
                data: (result) {
                  if (result.meetings.isEmpty) {
                    return ListView(
                      physics: scrollPhysics,
                      children: const [
                        SizedBox(height: 80),
                        PremiumEmptyState(
                          icon: Icons.videocam_off_outlined,
                          title: 'No meetings found',
                          subtitle:
                              'Schedule a meeting or start one now to see it here.',
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: scrollPhysics,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    itemCount: result.meetings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final meeting = result.meetings[i];
                      return _MeetingTile(
                        meeting: meeting,
                        joining: _joiningId == meeting.id,
                        inCall: session.isFor(meeting.id),
                        statusColor: _statusColor(meeting.status, scheme),
                        onOpen: () {
                          Navigator.pushNamed(
                            context,
                            '/meetings/detail',
                            arguments: meeting.id,
                          );
                        },
                        onJoin: meeting.isScheduled
                            ? () => _join(meeting.id, title: meeting.title)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingTile extends StatelessWidget {
  const _MeetingTile({
    required this.meeting,
    required this.joining,
    required this.inCall,
    required this.statusColor,
    required this.onOpen,
    this.onJoin,
  });

  final Meeting meeting;
  final bool joining;
  final bool inCall;
  final Color statusColor;
  final VoidCallback onOpen;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return InkWell(
      borderRadius: BorderRadius.circular(isIOS ? 14 : 16),
      onTap: onOpen,
      child: PremiumCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isIOS ? 10 : 12),
                color: scheme.primaryContainer,
              ),
              child: Icon(Icons.videocam_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${meeting.typeLabel} · ${meeting.formatWhen()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Host: ${meeting.creator?.name ?? '—'}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PremiumStatusPill(
                  label: meeting.statusLabel,
                  color: statusColor,
                ),
                if (onJoin != null) ...[
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: joining ? null : onJoin,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      joining
                          ? 'Opening…'
                          : inCall
                          ? 'Return'
                          : 'Join',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
