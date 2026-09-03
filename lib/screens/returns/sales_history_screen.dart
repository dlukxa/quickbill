import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/sale_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import 'process_return_screen.dart';

import '../../providers/employee_provider.dart';
import '../../services/sync_service.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isFetchingHistory = false;

  @override
  void initState() {
    super.initState();
    // Trigger lazy loading of historical sales data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchHistoricalSales();
    });
  }

  Future<void> _fetchHistoricalSales() async {
    if (!mounted) return;
    setState(() => _isFetchingHistory = true);
    
    // Fetch older sales and sales_returns from the cloud
    await ref.read(syncServiceProvider).pullHistoricalData('sales');
    await ref.read(syncServiceProvider).pullHistoricalData('sales_returns');
    
    if (mounted) {
      setState(() => _isFetchingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(recentSalesProvider);
    final employeeAsync = ref.watch(currentEmployeeProvider);
    final currentEmployee = employeeAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Sale for Return'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Invoice # or Customer',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: salesAsync.when(
              data: (sales) {
                final filtered = sales.where((s) {
                  final q = _searchQuery.toLowerCase();
                  return s.billNumber.toLowerCase().contains(q) ||
                      (s.customerName != null && s.customerName!.toLowerCase().contains(q));
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No sales found'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final sale = filtered[index];
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(sale.billNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${Formatters.date(sale.createdAt)} • ${Formatters.currency(sale.total)}',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          if (currentEmployee?.permissions.canDeleteBill ?? false) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProcessReturnScreen(sale: sale),
                              ),
                            );
                          } else {
                             ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Access Denied: Return Processing permission required')),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          if (_isFetchingHistory)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.blue.withOpacity(0.1),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Fetching older sales from cloud...', style: TextStyle(fontSize: 12, color: Colors.blue)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
