import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeetingSessionState {
  const MeetingSessionState({
    this.meetingId,
    this.title,
    this.joinUrl,
    this.displayName,
    this.expanded = false,
    this.connecting = false,
  });

  final String? meetingId;
  final String? title;
  final String? joinUrl;
  final String? displayName;
  final bool expanded;
  final bool connecting;

  bool get isActive => joinUrl != null && joinUrl!.isNotEmpty;

  bool isFor(String? id) =>
      isActive && id != null && id.isNotEmpty && meetingId == id;

  MeetingSessionState copyWith({
    String? meetingId,
    String? title,
    String? joinUrl,
    String? displayName,
    bool? expanded,
    bool? connecting,
    bool clear = false,
  }) {
    if (clear) return const MeetingSessionState();
    return MeetingSessionState(
      meetingId: meetingId ?? this.meetingId,
      title: title ?? this.title,
      joinUrl: joinUrl ?? this.joinUrl,
      displayName: displayName ?? this.displayName,
      expanded: expanded ?? this.expanded,
      connecting: connecting ?? this.connecting,
    );
  }
}

class MeetingSessionNotifier extends Notifier<MeetingSessionState> {
  @override
  MeetingSessionState build() => const MeetingSessionState();

  void start({
    required String meetingId,
    required String joinUrl,
    String? title,
    String? displayName,
  }) {
    state = MeetingSessionState(
      meetingId: meetingId,
      title: title,
      joinUrl: joinUrl,
      displayName: displayName,
      expanded: true,
      connecting: false,
    );
  }

  void expand() {
    if (!state.isActive) return;
    state = state.copyWith(expanded: true);
  }

  void minimize() {
    if (!state.isActive) return;
    state = state.copyWith(expanded: false);
  }

  void setConnecting(bool value) {
    state = state.copyWith(connecting: value);
  }

  void end() {
    state = const MeetingSessionState();
  }
}

final meetingSessionProvider =
    NotifierProvider<MeetingSessionNotifier, MeetingSessionState>(
      MeetingSessionNotifier.new,
    );
