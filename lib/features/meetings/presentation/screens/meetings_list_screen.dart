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
import 'package:lms/features/meetings/presentation/widgets/recording_transcript_button.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';

class MeetingsListScreen extends ConsumerStatefulWidget {
  const MeetingsListScreen({super.key});

  @override
  ConsumerState<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends ConsumerState<MeetingsListScreen>
    with WidgetsBindingObserver {
  String? _joiningId;

  static const _tabs = [
    ('upcoming', 'Upcoming'),
    ('recurring', 'Recurring'),
    ('past', 'Past'),
    ('all', 'All'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent == true) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(meetingsListProvider);
    try {
      await ref.read(meetingsListProvider.future);
    } catch (_) {}
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
    final canViewRecordings = ref.watch(canViewMeetingRecordingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final scrollPhysics = isIOS
        ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
        : const AlwaysScrollableScrollPhysics();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppAppBar(
        title: 'Meetings',
        showBack: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            color: scheme.onSurface,
            onPressed: _refresh,
            icon: Icon(Icons.refresh_rounded, color: scheme.onSurface),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: AppHeroBanner(
              icon: Icons.videocam_rounded,
              title: 'Meetings',
              message:
                  'Internal discussions, standups, and presentations',
              trailing: canCreate
                  ? TextButton.icon(
                      onPressed: () => showCreateMeetingSheet(
                        context,
                        ref,
                        type: 'instant',
                      ),
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Start now'),
                    )
                  : null,
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              scrollDirection: Axis.horizontal,
              physics: isIOS
                  ? const BouncingScrollPhysics()
                  : const ClampingScrollPhysics(),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (key, label) = _tabs[i];
                final selected = tab == key;
                return AppFilterChip(
                  label: label,
                  selected: selected,
                  onSelected: (_) =>
                      ref.read(meetingsTabProvider.notifier).select(key),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: listAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
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
                  final meetings = tab == 'upcoming'
                      ? result.meetings.where((m) => !m.isOver).toList()
                      : result.meetings;
                  if (meetings.isEmpty) {
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
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      100,
                    ),
                    itemCount: meetings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final meeting = meetings[i];
                      return _MeetingTile(
                        meeting: meeting,
                        joining: _joiningId == meeting.id,
                        inCall: session.isFor(meeting.id),
                        statusColor: _statusColor(meeting.status, scheme),
                        onOpen: () async {
                          await Navigator.pushNamed(
                            context,
                            '/meetings/detail',
                            arguments: meeting.id,
                          );
                          if (mounted) _refresh();
                        },
                        onJoin: meeting.isScheduled
                            ? () => _join(meeting.id, title: meeting.title)
                            : null,
                        showRecordings: canViewRecordings,
                        transcriptionEnabled: result.transcription,
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
    this.showRecordings = false,
    this.transcriptionEnabled = false,
  });

  final Meeting meeting;
  final bool joining;
  final bool inCall;
  final Color statusColor;
  final VoidCallback onOpen;
  final VoidCallback? onJoin;
  final bool showRecordings;
  final bool transcriptionEnabled;

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return InkWell(
      borderRadius: BorderRadius.circular(isIOS ? 14 : 16),
      onTap: onOpen,
      child: AppSectionCard(
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            AppIconBadge(
              icon: Icons.videocam_rounded,
              size: 44,
              backgroundColor: AppColors.iconBg,
              iconColor: AppColors.primary,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.title,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${meeting.typeLabel} · ${meeting.formatWhen()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Host: ${meeting.creator?.name ?? '—'}',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (meeting.autoTranscribe) ...[
                    SizedBox(height: 6),
                    Text(
                      'Auto transcript',
                      style: TextStyle(
                        color: Color(0xFF0369A1),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (showRecordings &&
                      (meeting.recordingSummary?.count ?? 0) > 0) ...[
                    SizedBox(height: 6),
                    Text(
                      '${meeting.recordingSummary!.count} recording${meeting.recordingSummary!.count == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (showRecordings &&
                      (meeting.recordingSummary?.latestId?.isNotEmpty ??
                          false)) ...[
                    const SizedBox(height: 8),
                    RecordingTranscriptButton(
                      recordingId: meeting.recordingSummary!.latestId!,
                      title: meeting.title,
                      status:
                          meeting.recordingSummary!.latestTranscriptStatus ??
                          'none',
                      enabled: transcriptionEnabled,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppStatusPill(
                  label: meeting.isLive ? 'Live now' : meeting.statusLabel,
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
