import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/data/models/meet_recording_model.dart';
import 'package:lms/features/meetings/presentation/meetings_access.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
import 'package:lms/features/meetings/presentation/widgets/recording_transcript_button.dart';
import 'package:lms/shared/utils/app_snackbar.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';
import 'package:url_launcher/url_launcher.dart';

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key, this.meetingId});

  final String? meetingId;

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _sourceType;
  int _page = 1;
  String? _openingId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  RecordingsQuery get _key => RecordingsQuery(
    meetingId: widget.meetingId,
    search: _query,
    sourceType: _sourceType,
    page: _page,
  );

  Future<void> _play(MeetRecording recording) async {
    setState(() => _openingId = recording.id);
    try {
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '/meetings/recording-player',
        arguments: {
          'id': recording.id,
          'title': recording.title,
          'audioOnly': recording.isAudioOnly,
        },
      );
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Future<void> _download(MeetRecording recording) async {
    try {
      final links = await ref
          .read(meetingsRepositoryProvider)
          .getRecordingPlayUrl(recording.id);
      final uri = Uri.parse(links.downloadUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        AppSnackbar.error(context, 'Could not download recording');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, cleanApiError(e));
    }
  }

  Future<void> _delete(MeetRecording recording) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this recording?'),
        content: const Text('The file is removed from the server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(meetingsRepositoryProvider).deleteRecording(recording.id);
      ref.invalidate(recordingsListProvider);
      if (mounted) AppSnackbar.success(context, 'Recording deleted');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, cleanApiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(recordingsListProvider(_key));
    final canDelete = ref.watch(canDeleteMeetingRecordingsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppAppBar(
        title: widget.meetingId == null ? 'Recordings' : 'Meeting recordings',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(recordingsListProvider(_key)),
            icon: Icon(Icons.refresh_rounded, color: scheme.onSurface),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search recordings',
              ),
              onSubmitted: (value) {
                setState(() {
                  _query = value.trim();
                  _page = 1;
                });
              },
            ),
          ),
          if (widget.meetingId == null)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final item in const [
                    (null, 'All'),
                    ('meeting', 'Meetings'),
                    ('interview', 'Interviews'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.$2),
                        selected: _sourceType == item.$1,
                        onSelected: (_) {
                          setState(() {
                            _sourceType = item.$1;
                            _page = 1;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: page.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load recordings',
                    subtitle: cleanApiError(e),
                  ),
                ],
              ),
              data: (result) {
                if (result.recordings.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      PremiumEmptyState(
                        icon: Icons.video_library_outlined,
                        title: _query.isEmpty
                            ? 'No recordings yet'
                            : 'No recordings match your search',
                        subtitle: _query.isEmpty
                            ? 'Start a recording from the Meet toolbar. It appears here a few minutes after the recording stops.'
                            : 'Try a different search.',
                      ),
                    ],
                  );
                }
                final hasPager = result.pages > 1;
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: result.recordings.length + (hasPager ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index >= result.recordings.length) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (result.page > 1)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _page = result.page - 1),
                              child: const Text('Previous'),
                            ),
                          if (result.page < result.pages)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _page = result.page + 1),
                              child: const Text('Next'),
                            ),
                        ],
                      );
                    }
                    final rec = result.recordings[index];
                    return PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  rec.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (rec.isAudioOnly)
                                const PremiumStatusPill(
                                  label: 'Transcript only',
                                  color: Color(0xFF0369A1),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rec.durationSeconds == null
                                ? rec.whenLabel
                                : '${rec.whenLabel} · ${formatRecordingClock(rec.durationSeconds)}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _openingId == rec.id ? null : () => _play(rec),
                                icon: Icon(rec.isAudioOnly ? Icons.play_arrow_rounded : Icons.play_circle_outline),
                                label: Text(rec.isAudioOnly ? 'Play audio' : 'Watch'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _download(rec),
                                icon: const Icon(Icons.download_rounded, size: 18),
                                label: const Text('Download'),
                              ),
                              RecordingTranscriptButton(
                                recordingId: rec.id,
                                title: rec.title,
                                status: rec.transcriptStatus,
                                error: rec.transcriptError,
                                enabled: result.transcription,
                                compact: true,
                              ),
                              if (canDelete)
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () => _delete(rec),
                                  icon: Icon(Icons.delete_outline, color: scheme.error),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
