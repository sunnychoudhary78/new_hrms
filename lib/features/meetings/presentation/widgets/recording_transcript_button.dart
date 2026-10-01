import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/presentation/meetings_access.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
import 'package:lms/shared/utils/app_snackbar.dart';

class RecordingTranscriptButton extends ConsumerStatefulWidget {
  const RecordingTranscriptButton({
    super.key,
    required this.recordingId,
    required this.title,
    required this.status,
    this.error,
    this.enabled = true,
    this.compact = false,
  });

  final String recordingId;
  final String title;
  final String status;
  final String? error;
  final bool enabled;
  final bool compact;

  @override
  ConsumerState<RecordingTranscriptButton> createState() =>
      _RecordingTranscriptButtonState();
}

class _RecordingTranscriptButtonState
    extends ConsumerState<RecordingTranscriptButton> {
  late String _status;
  Timer? _poll;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _syncPoll();
  }

  @override
  void didUpdateWidget(RecordingTranscriptButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status && !_starting) {
      _status = widget.status;
      _syncPoll();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _syncPoll() {
    _poll?.cancel();
    if (_status != 'processing') return;
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final rec = await ref
          .read(meetingsRepositoryProvider)
          .getRecording(widget.recordingId);
      if (!mounted || rec.transcriptStatus == 'processing') return;
      setState(() => _status = rec.transcriptStatus);
      _syncPoll();
      if (rec.transcriptStatus == 'ready') {
        AppSnackbar.success(context, 'Transcription ready');
      } else if (rec.transcriptStatus == 'failed') {
        AppSnackbar.error(
          context,
          rec.transcriptError ?? 'Transcription failed',
        );
      }
    } catch (_) {}
  }

  Future<void> _start() async {
    if (_starting || !widget.enabled) return;
    setState(() => _starting = true);
    try {
      final rec = await ref
          .read(meetingsRepositoryProvider)
          .transcribeRecording(widget.recordingId);
      if (!mounted) return;
      setState(() => _status = rec.transcriptStatus);
      _syncPoll();
      AppSnackbar.success(
        context,
        'Transcription started. It usually takes a few minutes.',
      );
    } catch (e) {
      if (!mounted) return;
      final message = cleanApiError(e).toLowerCase();
      if (message.contains('already transcribed')) {
        setState(() => _status = 'ready');
        _open();
      } else {
        AppSnackbar.error(context, cleanApiError(e));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _open() {
    Navigator.pushNamed(
      context,
      '/meetings/recording-transcript',
      arguments: {'id': widget.recordingId, 'title': widget.title},
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.compact
        ? OutlinedButton.styleFrom(visualDensity: VisualDensity.compact)
        : null;

    if (_status == 'ready') {
      return OutlinedButton.icon(
        style: style,
        onPressed: _open,
        icon: const Icon(Icons.article_outlined, size: 18),
        label: const Text('View transcription'),
      );
    }

    if (_status == 'processing') {
      return OutlinedButton.icon(
        style: style,
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Transcribing…'),
      );
    }

    final failed = _status == 'failed';
    return OutlinedButton.icon(
      style: style,
      onPressed: (_starting || !widget.enabled) ? null : _start,
      icon: Icon(
        failed ? Icons.refresh_rounded : Icons.mic_none_rounded,
        size: 18,
      ),
      label: Text(
        _starting
            ? 'Starting…'
            : failed
            ? 'Retry transcription'
            : 'Get transcription',
      ),
    );
  }
}
