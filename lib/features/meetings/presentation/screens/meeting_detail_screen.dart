import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/data/models/meeting_model.dart';
import 'package:lms/features/meetings/presentation/meeting_join.dart';
import 'package:lms/features/meetings/presentation/meetings_access.dart';
import 'package:lms/features/meetings/presentation/providers/meeting_session_provider.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
import 'package:lms/features/meetings/presentation/widgets/employee_picker.dart';
import 'package:lms/features/meetings/presentation/widgets/guest_invite_sheet.dart';
import 'package:lms/shared/utils/app_snackbar.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';

class MeetingDetailScreen extends ConsumerStatefulWidget {
  const MeetingDetailScreen({super.key, this.meetingId});

  final String? meetingId;

  @override
  ConsumerState<MeetingDetailScreen> createState() =>
      _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController(text: '30');
  DateTime? _startsAt;
  TimeOfDay _recTime = const TimeOfDay(hour: 10, minute: 0);
  List<int> _recDays = [1, 2, 3, 4, 5];
  List<String> _selectedIds = [];
  String _employeeFilter = '';
  bool _hydrated = false;
  bool _joining = false;
  bool _saving = false;

  String? get _id {
    if (widget.meetingId != null && widget.meetingId!.isNotEmpty) {
      return widget.meetingId;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) return args;
    if (args is Map) {
      final id = args['id'] ?? args['meetingId'];
      if (id != null && id.toString().isNotEmpty) return id.toString();
    }
    return null;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _hydrate(Meeting meeting) {
    _title.text = meeting.title;
    _description.text = meeting.description ?? '';
    _duration.text = '${meeting.durationMinutes}';
    _startsAt = meeting.startsAt?.toLocal();
    final rec = recurrenceTimeForApi(meeting.recurrenceTime ?? '10:00');
    final parts = rec.split(':');
    _recTime = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 10,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    _recDays = meeting.recurrenceDays.isNotEmpty
        ? List<int>.from(meeting.recurrenceDays)
        : [1, 2, 3, 4, 5];
    _selectedIds = meeting.attendeeUserIds;
    _hydrated = true;
  }

  Future<void> _pickStartsAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _startsAt != null
          ? TimeOfDay.fromDateTime(_startsAt!)
          : TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _join(String id, {String? title}) async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      await joinMeetingById(context, ref, meetingId: id, title: title);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _save(Meeting meeting) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final n = int.tryParse(_duration.text.trim()) ?? 30;
      final payload = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'duration_minutes': n < 5 ? 5 : (n > 480 ? 480 : n),
        'participant_ids': List<String>.from(_selectedIds),
      };
      if (meeting.isRecurring) {
        payload['recurrence_time'] = hhmm(
          DateTime(2000, 1, 1, _recTime.hour, _recTime.minute),
        );
        payload['recurrence_days'] = List<int>.from(_recDays);
      } else if (_startsAt != null) {
        payload['starts_at'] = _startsAt!.toUtc().toIso8601String();
      }
      await ref
          .read(meetingsRepositoryProvider)
          .updateMeeting(meeting.id, payload);
      ref.invalidate(meetingDetailProvider(meeting.id));
      ref.invalidate(meetingsListProvider);
      if (mounted) AppSnackbar.success(context, 'Meeting updated');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, cleanApiError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel(Meeting meeting) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this meeting?'),
        content: const Text('Participants will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel meeting'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(meetingsRepositoryProvider).cancelMeeting(meeting.id);
      ref.invalidate(meetingDetailProvider(meeting.id));
      ref.invalidate(meetingsListProvider);
      if (mounted) AppSnackbar.success(context, 'Meeting cancelled');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, cleanApiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    if (id == null) {
      return const Scaffold(
        appBar: const AppAppBar(title: 'Meeting'),
        body: Center(child: Text('Meeting not found')),
      );
    }

    final meetingAsync = ref.watch(meetingDetailProvider(id));
    final session = ref.watch(meetingSessionProvider);
    final canEdit = ref.watch(canEditMeetingsProvider);
    final userId = currentUserId(ref);
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      appBar: const AppAppBar(title: 'Meeting'),
      body: meetingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(cleanApiError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (meeting) {
          if (!_hydrated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _hydrate(meeting));
            });
          }

          final cancelled = meeting.isCancelled;
          final isHost = meeting.isHostOf(userId);
          final canInviteGuests = !cancelled && (isHost || canEdit);
          final statusColor = cancelled
              ? scheme.error
              : meeting.isEnded
              ? scheme.outline
              : const Color(0xFF059669);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            physics: isIOS
                ? const BouncingScrollPhysics()
                : const ClampingScrollPhysics(),
            children: [
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        PremiumStatusPill(
                          label: meeting.statusLabel,
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${meeting.typeLabel} · ${meeting.formatWhen()}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Host: ${meeting.creator?.name ?? '—'} · ${meeting.durationMinutes} min',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    if (!cancelled) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Guests and attendees wait in the Meet lobby until the host admits them. Join as host first, then admit from Participants.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (meeting.description != null &&
                        meeting.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Agenda',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(meeting.description!),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Participants',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...meeting.activeParticipants.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              p.role,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!cancelled) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (canInviteGuests)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => showGuestInviteSheet(
                                  context,
                                  ref,
                                  meeting.id,
                                ),
                                icon: const Icon(Icons.link_rounded),
                                label: const Text('Invite guest'),
                              ),
                            ),
                          if (canInviteGuests) const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _joining
                                  ? null
                                  : () => _join(
                                      meeting.id,
                                      title: meeting.title,
                                    ),
                              icon: const Icon(Icons.videocam_rounded),
                              label: Text(
                                _joining
                                    ? 'Opening…'
                                    : session.isFor(meeting.id)
                                    ? 'Return to meeting'
                                    : isHost
                                    ? 'Join as host'
                                    : 'Join meeting',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!cancelled && canEdit) ...[
                const SizedBox(height: 16),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit meeting',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _description,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Agenda'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                        ),
                      ),
                      if (meeting.isOneTime || meeting.isInstant) ...[
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Starts at'),
                          subtitle: Text(
                            _startsAt == null
                                ? 'Select date and time'
                                : localDateTimeLabel(_startsAt),
                          ),
                          trailing: const Icon(Icons.event),
                          onTap: _pickStartsAt,
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Recurring time'),
                          subtitle: Text(_recTime.format(context)),
                          trailing: const Icon(Icons.schedule),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _recTime,
                            );
                            if (t != null && mounted) {
                              setState(() => _recTime = t);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text('Weekdays'),
                        const SizedBox(height: 8),
                        WeekdayChipRow(
                          selectedDays: _recDays,
                          onToggle: (day) {
                            setState(() {
                              final next = {..._recDays};
                              if (next.contains(day)) {
                                next.remove(day);
                              } else {
                                next.add(day);
                              }
                              _recDays =
                                  (next.isEmpty ? {1, 2, 3, 4, 5} : next)
                                      .toList()
                                    ..sort();
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      ref
                          .watch(meetingEmployeesProvider)
                          .when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, __) => const Text(
                              'Could not load employees',
                            ),
                            data: (employees) => MeetingEmployeePicker(
                              employees: employees,
                              selectedIds: _selectedIds,
                              filter: _employeeFilter,
                              onFilterChanged: (v) =>
                                  setState(() => _employeeFilter = v),
                              onToggle: (id) {
                                setState(() {
                                  if (_selectedIds.contains(id)) {
                                    _selectedIds.remove(id);
                                  } else {
                                    _selectedIds.add(id);
                                  }
                                });
                              },
                              label: 'Attendees',
                              hint: 'Search…',
                              helper: '${_selectedIds.length} attendees selected',
                            ),
                          ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _cancel(meeting),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.error,
                              ),
                              child: const Text('Cancel meeting'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : () => _save(meeting),
                              child: Text(_saving ? 'Saving…' : 'Save changes'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
