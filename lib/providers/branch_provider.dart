import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/branch.dart';
import '../services/database_service.dart';

class BranchState {
  final List<Branch> branches;
  final Branch? selectedBranch;
  final bool isLoading;

  BranchState({
    this.branches = const [],
    this.selectedBranch,
    this.isLoading = false,
  });

  BranchState copyWith({
    List<Branch>? branches,
    Branch? selectedBranch,
    bool? isLoading,
  }) {
    return BranchState(
      branches: branches ?? this.branches,
      selectedBranch: selectedBranch ?? this.selectedBranch,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BranchNotifier extends StateNotifier<BranchState> {
  final DatabaseService _db = DatabaseService.instance;
  static const String _lastBranchIdKey = 'last_selected_branch_id';

  BranchNotifier() : super(BranchState());

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    try {
      final branches = await _db.getAllBranches();
      
      // Load last selected branch from preferences
      final prefs = await SharedPreferences.getInstance();
      final lastBranchId = prefs.getInt(_lastBranchIdKey);
      
      Branch? selected;
      if (lastBranchId != null) {
        try {
          selected = branches.firstWhere((b) => b.id == lastBranchId);
        } catch (_) {
          selected = branches.isNotEmpty ? branches.first : null;
        }
      } else if (branches.isNotEmpty) {
        selected = branches.first;
      }
      if (!mounted) return;
      state = state.copyWith(
        branches: branches,
        selectedBranch: selected,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> selectBranch(Branch branch) async {
    if (state.selectedBranch?.id == branch.id) return;
    
    final prefs = await SharedPreferences.getInstance();
    if (branch.id != null) {
      await prefs.setInt(_lastBranchIdKey, branch.id!);
    }
    
    if (!mounted) return;
    state = state.copyWith(selectedBranch: branch);
  }

  Future<void> selectBranchById(int branchId) async {
    List<Branch> branches = state.branches;
    if (branches.isEmpty) {
      branches = await _db.getAllBranches();
    }
    try {
      final branch = branches.firstWhere((b) => b.id == branchId);
      await selectBranch(branch);
    } catch (_) {
      // Branch not found, keep current
    }
  }

  Future<void> refreshBranches() async {
    final branches = await _db.getAllBranches();
    
    // Ensure selected branch still exists
    Branch? selected = state.selectedBranch;
    if (selected != null && !branches.any((b) => b.id == selected?.id)) {
      selected = branches.isNotEmpty ? branches.first : null;
    } else if (selected == null && branches.isNotEmpty) {
      selected = branches.first;
    }

    if (!mounted) return;
    state = state.copyWith(
      branches: branches,
      selectedBranch: selected,
    );
  }

  Future<void> addBranch(Branch branch) async {
    await _db.insertBranch(branch);
    await refreshBranches();
  }

  Future<void> updateBranch(Branch branch) async {
    await _db.updateBranch(branch);
    await refreshBranches();
  }

  Future<void> deleteBranch(int id) async {
    await _db.deleteBranch(id);
    await refreshBranches();
  }
}

final branchProvider = StateNotifierProvider<BranchNotifier, BranchState>((ref) {
  return BranchNotifier()..init();
});

final currentBranchIdProvider = Provider<int>((ref) {
  final branchState = ref.watch(branchProvider);
  return branchState.selectedBranch?.id ?? 1;
});
