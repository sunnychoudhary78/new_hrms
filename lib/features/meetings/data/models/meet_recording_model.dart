import 'package:lms/core/network/api_constants.dart';
import 'package:lms/features/meetings/data/models/meeting_model.dart';

class MeetRecording {
  final String id;
  final String title;
  final String? roomName;
  final String sourceType;
  final String? meetingId;
  final String? originalFilename;
  final int? fileSize;
  final String? mimeType;
  final String mediaKind;
  final int? durationSeconds;
  final DateTime? recordedAt;
  final DateTime? createdAt;
  final String transcriptStatus;
  final String? transcriptError;
  final DateTime? transcribedAt;

  const MeetRecording({
    required this.id,
    required this.title,
    this.roomName,
    this.sourceType = 'meeting',
    this.meetingId,
    this.originalFilename,
    this.fileSize,
    this.mimeType,
    this.mediaKind = 'video',
    this.durationSeconds,
    this.recordedAt,
    this.createdAt,
    this.transcriptStatus = 'none',
    this.transcriptError,
    this.transcribedAt,
  });

  bool get isAudioOnly => mediaKind == 'audio';

  String get whenLabel {
    final at = recordedAt ?? createdAt;
    if (at == null) return title;
    final local = at.toLocal();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${weekdays[local.weekday - 1]}, ${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}, $hh:$mm';
  }

  factory MeetRecording.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic raw) {
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toUtc();
    }

    return MeetRecording(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Recording',
      roomName: json['room_name']?.toString(),
      sourceType: json['source_type']?.toString() ?? 'meeting',
      meetingId: json['meeting_id']?.toString(),
      originalFilename: json['original_filename']?.toString(),
      fileSize: int.tryParse(json['file_size']?.toString() ?? ''),
      mimeType: json['mime_type']?.toString(),
      mediaKind: json['media_kind']?.toString() ?? 'video',
      durationSeconds: int.tryParse(json['duration_seconds']?.toString() ?? ''),
      recordedAt: parse(json['recorded_at']),
      createdAt: parse(json['created_at']),
      transcriptStatus: json['transcript_status']?.toString() ?? 'none',
      transcriptError: json['transcript_error']?.toString(),
      transcribedAt: parse(json['transcribed_at']),
    );
  }
}

class RecordingsPageResult {
  final List<MeetRecording> recordings;
  final int page;
  final int limit;
  final int total;
  final int pages;
  final int totalBytes;
  final bool transcription;

  const RecordingsPageResult({
    required this.recordings,
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.pages = 1,
    this.totalBytes = 0,
    this.transcription = false,
  });
}

class RecordingPlayLinks {
  final String streamUrl;
  final String downloadUrl;
  final int expiresIn;

  const RecordingPlayLinks({
    required this.streamUrl,
    required this.downloadUrl,
    this.expiresIn = 7200,
  });
}

class TranscriptSegment {
  final double start;
  final double end;
  final String? speaker;
  final String text;

  const TranscriptSegment({
    required this.start,
    required this.end,
    this.speaker,
    required this.text,
  });

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      start: double.tryParse(json['start']?.toString() ?? '') ?? 0,
      end: double.tryParse(json['end']?.toString() ?? '') ?? 0,
      speaker: (json['speaker'] ?? json['speaker_name'])?.toString(),
      text: json['text']?.toString() ?? '',
    );
  }
}

class MeetTranscript {
  final String id;
  final String title;
  final String status;
  final String? language;
  final String? text;
  final List<TranscriptSegment> segments;

  const MeetTranscript({
    required this.id,
    required this.title,
    required this.status,
    this.language,
    this.text,
    this.segments = const [],
  });

  factory MeetTranscript.fromJson(Map<String, dynamic> json) {
    final raw = json['segments'];
    final segments = <TranscriptSegment>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          segments.add(
            TranscriptSegment.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return MeetTranscript(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Transcript',
      status: json['transcript_status']?.toString() ?? 'ready',
      language: json['language']?.toString(),
      text: json['text']?.toString(),
      segments: segments,
    );
  }

  String get shareText {
    if (segments.isNotEmpty) {
      return segments
          .map((s) {
            final who = (s.speaker ?? '').trim();
            final prefix = who.isEmpty ? '' : '$who: ';
            return '[${formatRecordingClock(s.start)}] $prefix${s.text}';
          })
          .join('\n');
    }
    return text ?? '';
  }
}

String formatRecordingClock(num? seconds) {
  final total = (seconds ?? 0).floor();
  if (total < 0) return '00:00';
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$mm:$ss';
}

String recordingAbsoluteUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/+$'), '');
  if (path.startsWith('/')) return '$base$path';
  return '$base/$path';
}

RecordingsPageResult recordingsPageFromResponse(dynamic res) {
  final map = meetingResponseMap(res);
  final pagination = map['pagination'];
  final storage = map['storage'];
  final features = map['features'];
  dynamic raw = map['data'];
  if (raw is Map) raw = raw['data'] ?? raw['rows'];
  final recordings = <MeetRecording>[];
  if (raw is List) {
    for (final item in raw) {
      if (item is Map) {
        final rec = MeetRecording.fromJson(Map<String, dynamic>.from(item));
        if (rec.id.isNotEmpty) recordings.add(rec);
      }
    }
  }
  int readInt(dynamic source, String key, int fallback) {
    if (source is! Map) return fallback;
    return int.tryParse(source[key]?.toString() ?? '') ?? fallback;
  }

  return RecordingsPageResult(
    recordings: recordings,
    page: readInt(pagination, 'page', 1),
    limit: readInt(pagination, 'limit', 20),
    total: readInt(pagination, 'total', recordings.length),
    pages: readInt(pagination, 'pages', 1),
    totalBytes: readInt(storage, 'total_bytes', 0),
    transcription: features is Map && features['transcription'] == true,
  );
}

MeetRecording? recordingFromResponse(dynamic res) {
  final map = meetingResponseMap(res);
  dynamic raw = map['data'] ?? map;
  if (raw is Map && raw['id'] == null && raw['data'] is Map) raw = raw['data'];
  if (raw is Map) {
    return MeetRecording.fromJson(Map<String, dynamic>.from(raw));
  }
  return null;
}

RecordingPlayLinks playLinksFromResponse(dynamic res) {
  final map = meetingResponseMap(res);
  final data = map['data'] is Map
      ? Map<String, dynamic>.from(map['data'] as Map)
      : map;
  final stream = data['stream_path']?.toString() ?? '';
  final download = data['download_path']?.toString() ?? stream;
  return RecordingPlayLinks(
    streamUrl: stream.isEmpty ? '' : recordingAbsoluteUrl(stream),
    downloadUrl: download.isEmpty ? '' : recordingAbsoluteUrl(download),
    expiresIn: int.tryParse(data['expires_in']?.toString() ?? '') ?? 7200,
  );
}

MeetTranscript? transcriptFromResponse(dynamic res) {
  final map = meetingResponseMap(res);
  dynamic raw = map['data'] ?? map;
  if (raw is Map) {
    return MeetTranscript.fromJson(Map<String, dynamic>.from(raw));
  }
  return null;
}
