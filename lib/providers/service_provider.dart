import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service.dart';
import '../services/database_service.dart';
import 'branch_provider.dart';

// Database service provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

// All services provider
final servicesProvider = FutureProvider<List<Service>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  return await db.getAllServices(branchId);
});

// Search services provider
final searchServicesProvider = FutureProvider.family<List<Service>, String>((ref, query) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  if (query.isEmpty) {
    return await db.getAllServices(branchId);
  }
  return await db.searchServices(query, branchId);
});

// Service by ID provider
final serviceByIdProvider = FutureProvider.family<Service?, int>((ref, id) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getServiceById(id);
});

// ServiceNotifier for CRUD operations
class ServiceNotifier extends StateNotifier<AsyncValue<void>> {
  final DatabaseService _db;
  final Ref _ref;

  ServiceNotifier(this._db, this._ref) : super(const AsyncValue.data(null));

  Future<void> addService(Service service) async {
    state = const AsyncValue.loading();
    try {
      await _db.insertService(service);
      _ref.invalidate(servicesProvider);
      _ref.invalidate(searchServicesProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateService(Service service) async {
    state = const AsyncValue.loading();
    try {
      await _db.updateService(service);
      _ref.invalidate(servicesProvider);
      _ref.invalidate(searchServicesProvider);
      if (service.id != null) {
        _ref.invalidate(serviceByIdProvider(service.id!));
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteService(int id) async {
    state = const AsyncValue.loading();
    try {
      await _db.deleteService(id);
      _ref.invalidate(servicesProvider);
      _ref.invalidate(searchServicesProvider);
      _ref.invalidate(serviceByIdProvider(id));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final serviceNotifierProvider = StateNotifierProvider<ServiceNotifier, AsyncValue<void>>((ref) {
  return ServiceNotifier(ref.watch(databaseServiceProvider), ref);
});
