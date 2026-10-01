import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/presentation/meetings_access.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:video_player/video_player.dart';

class RecordingPlayerScreen extends ConsumerStatefulWidget {
  const RecordingPlayerScreen({
    super.key,
    required this.recordingId,
    this.title,
    this.audioOnly = false,
  });

  final String recordingId;
  final String? title;
  final bool audioOnly;

  @override
  ConsumerState<RecordingPlayerScreen> createState() =>
      _RecordingPlayerScreenState();
}

class _RecordingPlayerScreenState extends ConsumerState<RecordingPlayerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _chewie?.dispose();
    await _video?.dispose();
    _chewie = null;
    _video = null;
    try {
      final links = await ref
          .read(meetingsRepositoryProvider)
          .getRecordingPlayUrl(widget.recordingId);
      final video = VideoPlayerController.networkUrl(Uri.parse(links.streamUrl));
      await video.initialize();
      if (widget.audioOnly) {
        video.addListener(() {
          if (mounted) setState(() {});
        });
      }
      if (!mounted) {
        await video.dispose();
        return;
      }
      final chewie = ChewieController(
        videoPlayerController: video,
        autoPlay: true,
        allowFullScreen: !widget.audioOnly,
        showControls: true,
      );
      setState(() {
        _video = video;
        _chewie = chewie;
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppAppBar(
        title: widget.title ?? 'Recording',
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
                    Text(
                      cleanApiError(_error!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _open, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : widget.audioOnly
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.graphic_eq_rounded, color: scheme.primary, size: 72),
                  const SizedBox(height: 12),
                  const Text(
                    'Transcript only',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  if (_video != null)
                    IconButton(
                      iconSize: 56,
                      color: Colors.white,
                      onPressed: () {
                        final video = _video!;
                        setState(() {
                          video.value.isPlaying ? video.pause() : video.play();
                        });
                      },
                      icon: Icon(
                        _video!.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                      ),
                    ),
                ],
              ),
            )
          : _chewie == null
          ? const SizedBox.shrink()
          : Center(child: Chewie(controller: _chewie!)),
    );
  }
}
