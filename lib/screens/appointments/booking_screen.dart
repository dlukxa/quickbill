import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/staff_schedule_provider.dart';
import '../../providers/employee_provider.dart';
import '../../models/appointment.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../models/service.dart';
import '../../models/employee.dart';
import '../../config/theme.dart';
import '../../generated/l10n/app_localizations.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  int _currentStep = 0;
  
  // Step 1: Customer info
  final _nameController = TextEditingController();

  // Step 2: Service Selection
  Service? _selectedService;

  // Step 3: Staff Selection
  Employee? _selectedStaff;

  // Step 4: Time Slot Selection
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedSlot;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.bookAppointment)),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.pleaseEnterCustomerName)),
              );
              return;
            }
          } else if (_currentStep == 1) {
            if (_selectedService == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.pleaseSelectService)),
              );
              return;
            }
          } else if (_currentStep == 2) {
            if (_selectedStaff == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.pleaseSelectStaff)),
              );
              return;
            }
          } else if (_currentStep == 3) {
            if (_selectedSlot == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.pleaseSelectTimeSlot)),
              );
              return;
            }
            _bookAppointment();
            return;
          }
          
          setState(() {
            _currentStep += 1;
          });
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          } else {
            Navigator.pop(context);
          }
        },
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == 3;
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isLastStep ? localizations.confirmBooking : localizations.continueText,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: Text(localizations.backText),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text(localizations.customerDetails),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final customersAsync = ref.watch(customersProvider);
                    return customersAsync.when(
                      data: (customers) {
                        return DropdownButtonFormField<Customer>(
                          decoration: InputDecoration(labelText: localizations.selectCustomer, border: const OutlineInputBorder()),
                          items: customers.map((c) => DropdownMenuItem(value: c, child: Text('${c.name} ${c.phone != null ? '(${c.phone})' : ''}'))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _nameController.text = val.id.toString(); // We'll store ID in the controller for hacky simplicity
                            }
                          },
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    );
                  },
                ),
              ],
            ),
          ),
          Step(
            title: Text(localizations.selectService),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Consumer(
              builder: (context, ref, _) {
                final servicesAsync = ref.watch(servicesProvider);
                return servicesAsync.when(
                  data: (services) {
                    if (services.isEmpty) return Text(localizations.noServicesFound);
                    return Column(
                      children: services.map((s) {
                        return RadioListTile<Service>(
                          title: Text(s.name),
                          subtitle: Text('${s.durationMinutes} min • \$${s.price}'),
                          value: s,
                          groupValue: _selectedService,
                          onChanged: (val) {
                            setState(() {
                              _selectedService = val;
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                );
              },
            ),
          ),
          Step(
            title: Text(localizations.selectStaff),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: Consumer(
              builder: (context, ref, _) {
                final employeesAsync = ref.watch(employeeListProvider);
                return employeesAsync.when(
                  data: (employees) {
                    if (employees.isEmpty) return Text(localizations.noEmployeesFound);
                    return Column(
                      children: employees.map((e) {
                        return RadioListTile<Employee>(
                          title: Text(e.name),
                          value: e,
                          groupValue: _selectedStaff,
                          onChanged: (val) {
                            setState(() {
                              _selectedStaff = val;
                              _selectedSlot = null; // Reset slot when staff changes
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                );
              },
            ),
          ),
          Step(
            title: Text(localizations.selectTimeSlot),
            isActive: _currentStep >= 3,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat.yMMMd().format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                            _selectedSlot = null;
                          });
                        }
                      },
                      child: Text(localizations.changeDate),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_selectedStaff != null && _selectedService != null)
                  Consumer(
                    builder: (context, ref, _) {
                      final params = SlotParams(
                        _selectedDate, 
                        _selectedStaff!.id!, 
                        _selectedService!.durationMinutes,
                      );
                      final slotsAsync = ref.watch(availableSlotsProvider(params));
                      
                      return slotsAsync.when(
                        data: (slots) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (slots.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(localizations.noAvailableSlots, style: const TextStyle(color: Colors.grey)),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: slots.map((slot) {
                                    final isSelected = _selectedSlot == slot;
                                    return ChoiceChip(
                                      label: Text(DateFormat.jm().format(slot)),
                                      selected: isSelected,
                                      selectedColor: AppTheme.primaryGreen.withOpacity(0.3),
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedSlot = selected ? slot : null;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  side: BorderSide(color: AppTheme.primaryGreen),
                                  foregroundColor: AppTheme.primaryGreen,
                                ),
                                onPressed: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _selectedSlot = DateTime(
                                        _selectedDate.year,
                                        _selectedDate.month,
                                        _selectedDate.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                },
                                icon: const Icon(Icons.access_time),
                                label: Text(_selectedSlot != null 
                                  ? '${localizations.customTime}: ${DateFormat.jm().format(_selectedSlot!)}' 
                                  : localizations.selectCustomTime),
                              ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bookAppointment() async {
    final localizations = AppLocalizations.of(context)!;
    final customerId = int.tryParse(_nameController.text.trim());
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.selectValidCustomer)));
      return;
    }
    
    final appointment = Appointment(
      customerId: customerId,
      employeeId: _selectedStaff!.id!,
      branchId: 1,
      serviceIds: [_selectedService!.id!],
      scheduledStart: _selectedSlot!,
      scheduledEnd: _selectedSlot!.add(Duration(minutes: _selectedService!.durationMinutes)),
      status: 'booked',
    );

    try {
      await ref.read(appointmentActionsProvider).createAppointment(appointment);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.appointmentBooked), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.failedToBookAppointment(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }
}
