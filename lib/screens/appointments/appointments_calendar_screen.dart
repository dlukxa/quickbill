import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../providers/appointment_provider.dart';
import '../../models/appointment.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../config/theme.dart';
import 'booking_screen.dart';
import '../../generated/l10n/app_localizations.dart';
import '../billing/billing_screen.dart';
import '../../providers/cart_provider.dart';
import '../../providers/service_provider.dart';

class AppointmentsCalendarScreen extends ConsumerStatefulWidget {
  const AppointmentsCalendarScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AppointmentsCalendarScreen> createState() => _AppointmentsCalendarScreenState();
}

class _AppointmentsCalendarScreenState extends ConsumerState<AppointmentsCalendarScreen> {
  DateTime _focusedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsProvider(_selectedDay));
    final customersAsync = ref.watch(customersProvider);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.appointments),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                final now = DateTime.now();
                _focusedDay = DateTime(now.year, now.month, now.day);
                _selectedDay = DateTime(now.year, now.month, now.day);
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              final normSelected = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
              final normFocused = DateTime(focusedDay.year, focusedDay.month, focusedDay.day);
              if (!isSameDay(_selectedDay, normSelected)) {
                setState(() {
                  _selectedDay = normSelected;
                  _focusedDay = normFocused;
                });
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: appointmentsAsync.when(
              data: (appointments) {
                if (appointments.isEmpty) {
                  return Center(
                    child: Text(localizations.noAppointmentsDay),
                  );
                }
                return ListView.builder(
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final appointment = appointments[index];
                    return _buildAppointmentTile(appointment, customersAsync.valueOrNull ?? []);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BookingScreen()),
          );
        },
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(localizations.addItem, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAppointmentTile(Appointment appointment, List<Customer> customers) {
    final customer = appointment.customerId != null 
        ? customers.firstWhere((c) => c.id == appointment.customerId, orElse: () => Customer(name: 'Unknown', createdAt: DateTime.now(), updatedAt: DateTime.now())) 
        : Customer(name: 'Unknown', createdAt: DateTime.now(), updatedAt: DateTime.now());
    final customerName = customer.name;
    final customerPhone = customer.phone;
    final startTime = DateFormat.jm().format(appointment.scheduledStart);
    final endTime = DateFormat.jm().format(appointment.scheduledEnd);
    
    Color statusColor;
    switch (appointment.status) {
      case 'confirmed':
        statusColor = Colors.blue;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
      case 'noShow':
        statusColor = Colors.red;
        break;
      case 'inProgress':
        statusColor = Colors.orange;
        break;
      case 'booked':
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          customerName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$startTime - $endTime'),
              ],
            ),
            if (customerPhone != null && customerPhone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(customerPhone),
                ],
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withOpacity(0.5)),
          ),
          child: Text(
            appointment.status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () {
          _showAppointmentDetails(appointment, customerName, customerPhone);
        },
      ),
    );
  }

  void _showAppointmentDetails(Appointment appointment, String customerName, String? customerPhone) {
    final localizations = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.appointmentDetails,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('${localizations.customer}: ${customerName}', style: const TextStyle(fontSize: 16)),
              if (customerPhone != null)
                Text('${localizations.phoneNumber}: ${customerPhone}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('${localizations.dueDate}: ${DateFormat.yMMMd().format(appointment.scheduledStart)} at ${DateFormat.jm().format(appointment.scheduledStart)} - ${DateFormat.jm().format(appointment.scheduledEnd)}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (appointment.status == 'booked' || appointment.status == 'confirmed')
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: () {
                        ref.read(appointmentActionsProvider).updateAppointment(appointment.copyWith(status: 'inProgress'));
                        Navigator.pop(context);
                      },
                      child: Text(localizations.start, style: const TextStyle(color: Colors.white)),
                    ),
                  if (appointment.status == 'booked' || appointment.status == 'confirmed' || appointment.status == 'inProgress' || appointment.status == 'completed')
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                      onPressed: () {
                        // Load into cart
                        final services = ref.read(servicesProvider).valueOrNull ?? [];
                        final cartNotifier = ref.read(cartProvider.notifier);
                        
                        for (var serviceId in appointment.serviceIds) {
                          try {
                            final service = services.firstWhere((s) => s.id == serviceId);
                            cartNotifier.addService(service);
                          } catch (_) {}
                        }
                        
                        // Set customer
                        if (appointment.customerId != null) {
                          final customers = ref.read(customersProvider).valueOrNull ?? [];
                          try {
                            final cust = customers.firstWhere((c) => c.id == appointment.customerId);
                            ref.read(selectedCustomerProvider.notifier).state = cust;
                          } catch (_) {}
                        } else {
                           final tempCust = Customer(name: customerName, createdAt: DateTime.now(), updatedAt: DateTime.now());
                           ref.read(selectedCustomerProvider.notifier).state = tempCust;
                        }
                        
                        // Mark as completed
                        ref.read(appointmentActionsProvider).updateAppointment(appointment.copyWith(status: 'completed'));
                        
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingScreen()));
                      },
                      child: Text(localizations.newBill, style: const TextStyle(color: Colors.white)),
                    ),
                  if (appointment.status != 'cancelled' && appointment.status != 'completed')
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        ref.read(appointmentActionsProvider).cancelAppointment(appointment.id!);
                        Navigator.pop(context);
                      },
                      child: Text(localizations.cancel, style: const TextStyle(color: Colors.white)),
                    ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
