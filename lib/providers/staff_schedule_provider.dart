import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/staff_availability.dart';
import '../models/appointment.dart';
import '../services/database_service.dart';
import 'appointment_provider.dart';

final staffScheduleProvider = StateNotifierProvider.family<StaffScheduleNotifier, AsyncValue<List<StaffAvailability>>, int>((ref, employeeId) {
  final db = DatabaseService.instance;
  return StaffScheduleNotifier(db, employeeId);
});

class StaffScheduleNotifier extends StateNotifier<AsyncValue<List<StaffAvailability>>> {
  final DatabaseService _db;
  final int employeeId;

  StaffScheduleNotifier(this._db, this.employeeId) : super(const AsyncValue.loading()) {
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    try {
      final schedule = await _db.getStaffAvailability(employeeId);
      
      // If no schedule exists, create defaults
      if (schedule.isEmpty) {
        await _createDefaultSchedule();
      } else {
        state = AsyncValue.data(schedule);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _createDefaultSchedule() async {
    final defaults = [
      for (int i = 1; i <= 7; i++)
        StaffAvailability(
          employeeId: employeeId,
          dayOfWeek: i,
          startTime: i < 6 ? '09:00' : null,
          endTime: i < 6 ? '17:00' : null,
          isOffDay: i >= 6,
        )
    ];

    for (var avail in defaults) {
      await _db.insertStaffAvailability(avail);
    }
    
    final schedule = await _db.getStaffAvailability(employeeId);
    state = AsyncValue.data(schedule);
  }

  Future<void> updateAvailability(StaffAvailability availability) async {
    try {
      await _db.updateStaffAvailability(availability);
      await _loadSchedule(); // Refresh
    } catch (e) {
      rethrow;
    }
  }
}

// Helper to generate available time slots for a given day and employee
final availableSlotsProvider = FutureProvider.family<List<DateTime>, SlotParams>((ref, params) async {
  final scheduleAsync = ref.watch(staffScheduleProvider(params.employeeId));
  final schedule = scheduleAsync.valueOrNull ?? [];
  final appointmentsAsync = ref.watch(appointmentsByEmployeeProvider(params.employeeId));
  final appointments = appointmentsAsync.valueOrNull ?? [];

  if (schedule.isEmpty) return [];

  // Find availability for the day of week (Monday = 1, Sunday = 7)
  final dayOfWeek = params.date.weekday;
  final availability = schedule.firstWhere(
    (a) => a.dayOfWeek == dayOfWeek, 
    orElse: () => StaffAvailability(employeeId: params.employeeId, dayOfWeek: dayOfWeek, isOffDay: true)
  );

  if (availability.isOffDay || availability.startTime == null || availability.endTime == null) {
    return [];
  }

  // Parse start/end times
  final startParts = availability.startTime!.split(':');
  final endParts = availability.endTime!.split(':');
  
  DateTime currentSlot = DateTime(
    params.date.year, 
    params.date.month, 
    params.date.day, 
    int.parse(startParts[0]), 
    int.parse(startParts[1])
  );
  
  final endOfDay = DateTime(
    params.date.year, 
    params.date.month, 
    params.date.day, 
    int.parse(endParts[0]), 
    int.parse(endParts[1])
  );

  // Filter appointments for this specific day
  final dayAppointments = appointments.where((a) => 
    a.scheduledStart.year == params.date.year && 
    a.scheduledStart.month == params.date.month && 
    a.scheduledStart.day == params.date.day &&
    a.status != 'cancelled' && a.status != 'noShow'
  ).toList();

  List<DateTime> availableSlots = [];

  // Generate slots every 30 minutes
  while (currentSlot.add(Duration(minutes: params.durationMinutes)).isBefore(endOfDay) || 
         currentSlot.add(Duration(minutes: params.durationMinutes)).isAtSameMomentAs(endOfDay)) {
    
    final slotEnd = currentSlot.add(Duration(minutes: params.durationMinutes));
    
    // Check if slot conflicts with any existing appointment
    bool hasConflict = dayAppointments.any((app) {
      return (currentSlot.isBefore(app.scheduledEnd) && slotEnd.isAfter(app.scheduledStart));
    });
    
    // Don't show past slots for today
    final now = DateTime.now();
    final isPast = currentSlot.isBefore(now);

    if (!hasConflict && !isPast) {
      availableSlots.add(currentSlot);
    }
    
    // Advance by 30 mins (or potentially by service duration?)
    currentSlot = currentSlot.add(const Duration(minutes: 30));
  }

  return availableSlots;
});

class SlotParams {
  final DateTime date;
  final int employeeId;
  final int durationMinutes;

  SlotParams(this.date, this.employeeId, this.durationMinutes);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotParams &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          employeeId == other.employeeId &&
          durationMinutes == other.durationMinutes;

  @override
  int get hashCode => date.hashCode ^ employeeId.hashCode ^ durationMinutes.hashCode;
}
