import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/presentation/meeting_join.dart';
import 'package:lms/features/meetings/presentation/meetings_access.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
import 'package:lms/features/meetings/presentation/widgets/employee_picker.dart';
import 'package:lms/shared/utils/app_snackbar.dart';

Future<void> showCreateMeetingSheet(
  BuildContext context,
  WidgetRef ref, {
  String type = 'one_time',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: defaultTargetPlatform == TargetPlatform.iOS,
    builder: (_) => CreateMeetingSheet(initialType: type),
  );
}

class CreateMeetingSheet extends ConsumerStatefulWidget {
  const CreateMeetingSheet({super.key, this.initialType = 'one_time'});

  final String initialType;

  @override
  ConsumerState<CreateMeetingSheet> createState() => _CreateMeetingSheetState();
}

class _CreateMeetingSheetState extends ConsumerState<CreateMeetingSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController(text: '30');
  late String _type;
  DateTime? _startsAt;
  TimeOfDay _recurrenceTime = const TimeOfDay(hour: 10, minute: 0);
  List<int> _recurrenceDays = [1, 2, 3, 4, 5];
  final List<String> _participantIds = [];
  String _employeeFilter = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickStartsAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _startsAt != null
          ? TimeOfDay.fromDateTime(_startsAt!)
          : TimeOfDay.fromDateTime(now.add(const Duration(minutes: 15))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickRecurrenceTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _recurrenceTime,
    );
    if (time == null || !mounted) return;
    setState(() => _recurrenceTime = time);
  }

  void _toggleDay(int day) {
    setState(() {
      final next = {..._recurrenceDays};
      if (next.contains(day)) {
        next.remove(day);
      } else {
        next.add(day);
      }
      _recurrenceDays = (next.isEmpty ? {1, 2, 3, 4, 5} : next).toList()
        ..sort();
    });
  }

  void _toggleParticipant(String id) {
    setState(() {
      if (_participantIds.contains(id)) {
        _participantIds.remove(id);
      } else {
        _participantIds.add(id);
      }
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      AppSnackbar.error(context, 'Title is required');
      return;
    }
    if (_type == 'one_time' && _startsAt == null) {
      AppSnackbar.error(context, 'Start date/time is required');
      return;
    }

    setState(() => _saving = true);
    try {
      final duration = int.tryParse(_duration.text.trim()) ?? 30;
      final payload = <String, dynamic>{
        'title': title,
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'type': _type == 'instant' ? 'instant' : _type,
        'duration_minutes': duration < 5 ? 5 : (duration > 480 ? 480 : duration),
        'participant_ids': List<String>.from(_participantIds),
        'start_now': _type == 'instant',
      };
      if (_type == 'one_time' && _startsAt != null) {
        payload['starts_at'] = _startsAt!.toUtc().toIso8601String();
      }
      if (_type == 'recurring') {
        payload['recurrence_time'] = hhmm(
          DateTime(2000, 1, 1, _recurrenceTime.hour, _recurrenceTime.minute),
        );
        payload['recurrence_days'] = List<int>.from(_recurrenceDays);
      }

      final created = await ref
          .read(meetingsRepositoryProvider)
          .createMeeting(payload);

      if (!mounted) return;
      AppSnackbar.success(
        context,
        _participantIds.isNotEmpty
            ? 'Meeting created — invites will be emailed shortly'
            : 'Meeting created',
      );

      if (_type == 'instant' && created.id.isNotEmpty) {
        await joinMeetingById(context, ref, created.id);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ref.invalidate(meetingsListProvider);
      if (created.id.isNotEmpty) {
        Navigator.pushNamed(context, '/meetings/detail', arguments: created.id);
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, cleanApiError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(meetingEmployeesProvider);
    final isInstant = _type == 'instant';
    final scheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isInstant ? 'Start meeting now' : 'Schedule meeting',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Daily standup',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Agenda / notes',
              ),
            ),
            if (!isInstant) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'one_time', child: Text('One-time')),
                  DropdownMenuItem(
                    value: 'recurring',
                    child: Text('Daily / recurring'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _type = v);
                },
              ),
            ],
            if (_type == 'one_time') ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Starts at'),
                subtitle: Text(
                  _startsAt == null
                      ? 'Select date and time'
                      : localDateTimeLabel(_startsAt),
                ),
                trailing: Icon(Icons.event, color: scheme.primary),
                onTap: _pickStartsAt,
              ),
            ],
            if (_type == 'recurring') ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Time (company timezone)'),
                subtitle: Text(_recurrenceTime.format(context)),
                trailing: Icon(Icons.schedule, color: scheme.primary),
                onTap: _pickRecurrenceTime,
              ),
              const SizedBox(height: 8),
              Text('Weekdays', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              WeekdayChipRow(
                selectedDays: _recurrenceDays,
                onToggle: _toggleDay,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
              ),
            ),
            const SizedBox(height: 16),
            employeesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Text(
                'Could not load employees',
                style: TextStyle(color: scheme.error),
              ),
              data: (employees) => MeetingEmployeePicker(
                employees: employees,
                selectedIds: _participantIds,
                filter: _employeeFilter,
                onFilterChanged: (v) => setState(() => _employeeFilter = v),
                onToggle: _toggleParticipant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : isInstant
                          ? 'Create & open'
                          : 'Create',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
