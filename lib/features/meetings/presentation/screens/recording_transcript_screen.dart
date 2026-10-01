import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/data/models/meet_recording_model.dart';
import 'package:lms/features/meetings/presentation/meetings_access.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
import 'package:lms/shared/utils/app_snackbar.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:share_plus/share_plus.dart';

class RecordingTranscriptScreen extends ConsumerStatefulWidget {
  const RecordingTranscriptScreen({
    super.key,
    required this.recordingId,
    this.title,
  });

  final String recordingId;
  final String? title;

  @override
  ConsumerState<RecordingTranscriptScreen> createState() =>
      _RecordingTranscriptScreenState();
}

class _RecordingTranscriptScreenState
    extends ConsumerState<RecordingTranscriptScreen> {
  MeetTranscript? _transcript;
  Object? _error;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final transcript = await ref
          .read(meetingsRepositoryProvider)
          .getRecordingTranscript(widget.recordingId);
      if (!mounted) return;
      setState(() {
        _transcript = transcript;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final transcript = _transcript;
    final q = _query.trim().toLowerCase();
    final lines = transcript?.segments ?? const <TranscriptSegment>[];
    final visible = q.isEmpty
        ? lines
        : lines.where((line) {
            final speaker = (line.speaker ?? '').toLowerCase();
            return line.text.toLowerCase().contains(q) || speaker.contains(q);
          }).toList();

    return Scaffold(
      appBar: AppAppBar(
        title: widget.title ?? transcript?.title ?? 'Transcript',
        actions: [
          if (transcript != null && transcript.shareText.trim().isNotEmpty)
            IconButton(
              tooltip: 'Copy',
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: transcript.shareText),
                );
                if (context.mounted) {
                  AppSnackbar.success(context, 'Transcript copied');
                }
              },
              icon: Icon(Icons.copy_rounded, color: scheme.onSurface),
            ),
          if (transcript != null && transcript.shareText.trim().isNotEmpty)
            IconButton(
              tooltip: 'Share',
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(text: transcript.shareText, subject: transcript.title),
                );
              },
              icon: Icon(Icons.share_rounded, color: scheme.onSurface),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cleanApiError(_error!), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search transcript',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty && (transcript?.text ?? '').isEmpty
                      ? const Center(child: Text('No speech was detected'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: visible.isEmpty ? 1 : visible.length,
                          itemBuilder: (context, index) {
                            if (visible.isEmpty) {
                              return Text(transcript?.text ?? '');
                            }
                            final line = visible[index];
                            final previous = index == 0
                                ? null
                                : visible[index - 1].speaker;
                            final speaker = (line.speaker ?? '').trim();
                            final showSpeaker =
                                speaker.isNotEmpty && speaker != previous;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showSpeaker)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        speaker,
                                        style: TextStyle(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 56,
                                        child: Text(
                                          formatRecordingClock(line.start),
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Text(line.text)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
