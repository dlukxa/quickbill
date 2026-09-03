import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/appointment.dart';
import '../services/database_service.dart';

final appointmentsProvider = FutureProvider.family<List<Appointment>, DateTime?>((ref, date) async {
  final db = DatabaseService.instance;
  if (date == null) {
    return db.getAppointments();
  } else {
    // Get appointments for specific date (from start of day to end of day)
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return db.getAppointments(startDate: startOfDay, endDate: endOfDay);
  }
});

final appointmentsByEmployeeProvider = FutureProvider.family<List<Appointment>, int>((ref, employeeId) async {
  final db = DatabaseService.instance;
  return db.getAppointmentsByEmployee(employeeId);
});

final appointmentActionsProvider = Provider((ref) => AppointmentActions(ref));

class AppointmentActions {
  final ProviderRef ref;
  AppointmentActions(this.ref);

  Future<void> createAppointment(Appointment appointment) async {
    final db = DatabaseService.instance;
    await db.insertAppointment(appointment);
    // Invalidate related providers
    ref.invalidate(appointmentsProvider);
    ref.invalidate(appointmentsByEmployeeProvider);
  }

  Future<void> updateAppointment(Appointment appointment) async {
    final db = DatabaseService.instance;
    await db.updateAppointment(appointment);
    ref.invalidate(appointmentsProvider);
    ref.invalidate(appointmentsByEmployeeProvider);
  }

  Future<void> cancelAppointment(int appointmentId) async {
    final db = DatabaseService.instance;
    // Fetch first to update status
    // Wait, our DB service deleteAppointment marks it as deleted entirely, or we can just update status to cancelled
    // It's better to update status to cancelled so it stays in history
    final appointments = await db.getAppointments();
    final appointment = appointments.firstWhere((a) => a.id == appointmentId);
    await db.updateAppointment(appointment.copyWith(status: 'cancelled'));
    ref.invalidate(appointmentsProvider);
    ref.invalidate(appointmentsByEmployeeProvider);
  }
}
