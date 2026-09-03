import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/employee_provider.dart';
import '../../providers/staff_schedule_provider.dart';
import '../../models/employee.dart';
import '../../models/staff_availability.dart';
import '../../generated/l10n/app_localizations.dart';

class StaffScheduleScreen extends ConsumerStatefulWidget {
  const StaffScheduleScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StaffScheduleScreen> createState() => _StaffScheduleScreenState();
}

class _StaffScheduleScreenState extends ConsumerState<StaffScheduleScreen> {
  Employee? _selectedEmployee;

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeListProvider);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.staffSchedule)),
      body: employeesAsync.when(
        data: (employees) {
          if (employees.isEmpty) {
            return Center(child: Text(localizations.noEmployeesFound));
          }

          if (_selectedEmployee == null) {
            _selectedEmployee = employees.first;
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).cardColor,
                child: DropdownButtonFormField<Employee>(
                  decoration: InputDecoration(
                    labelText: localizations.selectStaffMember,
                    border: const OutlineInputBorder(),
                  ),
                  value: _selectedEmployee,
                  items: employees.map((e) {
                    return DropdownMenuItem(value: e, child: Text(e.name));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedEmployee = val;
                    });
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _selectedEmployee == null
                    ? const SizedBox()
                    : _ScheduleEditor(employeeId: _selectedEmployee!.id!),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ScheduleEditor extends ConsumerWidget {
  final int employeeId;
  const _ScheduleEditor({required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(staffScheduleProvider(employeeId));
    final localizations = AppLocalizations.of(context)!;

    return scheduleAsync.when(
      data: (schedule) {
        if (schedule.isEmpty) {
          return Center(child: Text(localizations.noScheduleFound));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 7,
          itemBuilder: (context, index) {
            final dayOfWeek = index + 1; // 1 = Monday
            final avail = schedule.firstWhere(
              (a) => a.dayOfWeek == dayOfWeek,
              orElse: () => StaffAvailability(employeeId: employeeId, dayOfWeek: dayOfWeek, isOffDay: true),
            );

            return _DayRow(availability: avail, employeeId: employeeId);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _DayRow extends ConsumerWidget {
  final StaffAvailability availability;
  final int employeeId;

  const _DayRow({required this.availability, required this.employeeId});

  String _dayName(BuildContext context, int day) {
    final locale = Localizations.localeOf(context).toString();
    // 2024-01-01 is a Monday, so adding (day - 1) days gives Monday through Sunday correctly.
    final date = DateTime(2024, 1, day);
    return DateFormat.EEEE(locale).format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _dayName(context, availability.dayOfWeek),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Switch(
              value: !availability.isOffDay,
              onChanged: (val) {
                ref.read(staffScheduleProvider(employeeId).notifier).updateAvailability(
                  availability.copyWith(isOffDay: !val),
                );
              },
            ),
            if (!availability.isOffDay) ...[
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: int.tryParse(availability.startTime?.split(':')[0] ?? '9') ?? 9,
                      minute: int.tryParse(availability.startTime?.split(':')[1] ?? '0') ?? 0,
                    ),
                  );
                  if (time != null) {
                    final str = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    ref.read(staffScheduleProvider(employeeId).notifier).updateAvailability(
                      availability.copyWith(startTime: str),
                    );
                  }
                },
                child: Text(availability.startTime ?? '09:00', style: const TextStyle(fontSize: 14)),
              ),
              const Text('-'),
              TextButton(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: int.tryParse(availability.endTime?.split(':')[0] ?? '17') ?? 17,
                      minute: int.tryParse(availability.endTime?.split(':')[1] ?? '0') ?? 0,
                    ),
                  );
                  if (time != null) {
                    final str = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    ref.read(staffScheduleProvider(employeeId).notifier).updateAvailability(
                      availability.copyWith(endTime: str),
                    );
                  }
                },
                child: Text(availability.endTime ?? '17:00', style: const TextStyle(fontSize: 14)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
