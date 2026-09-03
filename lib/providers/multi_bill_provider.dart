import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_session.dart';
import 'cart_provider.dart';
import 'customer_provider.dart';

class MultiBillState {
  final List<BillSession> sessions;
  final int activeIndex;

  MultiBillState({
    required this.sessions,
    required this.activeIndex,
  });

  BillSession get activeSession => sessions[activeIndex];

  MultiBillState copyWith({
    List<BillSession>? sessions,
    int? activeIndex,
  }) {
    return MultiBillState(
      sessions: sessions ?? this.sessions,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

class MultiBillNotifier extends StateNotifier<MultiBillState> {
  final Ref ref;

  MultiBillNotifier(this.ref)
      : super(MultiBillState(
          sessions: [
            BillSession(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: 'Bill 1',
              items: [],
              updatedAt: DateTime.now(),
            )
          ],
          activeIndex: 0,
        ));

  void addNewSession() {
    _saveCurrentToSession();

    final newSession = BillSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Bill ${state.sessions.length + 1}',
      items: [],
      updatedAt: DateTime.now(),
    );

    final newSessions = [...state.sessions, newSession];
    state = state.copyWith(
      sessions: newSessions,
      activeIndex: newSessions.length - 1,
    );
    
    _syncWithProviders(newSession);
  }

  void switchToSession(int index) {
    if (index < 0 || index >= state.sessions.length || index == state.activeIndex) return;
    
    _saveCurrentToSession();
    state = state.copyWith(activeIndex: index);
    _syncWithProviders(state.sessions[index]);
  }

  void removeSession(int index) {
    if (state.sessions.length <= 1) return;
    
    final sessions = [...state.sessions];
    sessions.removeAt(index);
    
    int newActiveIndex = state.activeIndex;
    if (newActiveIndex >= sessions.length) {
      newActiveIndex = sessions.length - 1;
    } else if (index < state.activeIndex) {
      newActiveIndex--;
    }

    state = state.copyWith(
      sessions: sessions,
      activeIndex: newActiveIndex,
    );
    
    _syncWithProviders(state.sessions[newActiveIndex]);
  }

  void _saveCurrentToSession() {
    final cart = ref.read(cartProvider);
    final customer = ref.read(selectedCustomerProvider);
    final discount = ref.read(manualBillDiscountProvider);
    
    final sessions = [...state.sessions];
    sessions[state.activeIndex] = sessions[state.activeIndex].copyWith(
      items: [...cart], // Clone list
      customer: customer,
      manualDiscount: discount,
      updatedAt: DateTime.now(),
    );
    
    state = state.copyWith(sessions: sessions);
  }

  void _syncWithProviders(BillSession session) {
    ref.read(cartProvider.notifier).state = [...session.items]; // Clone list
    ref.read(selectedCustomerProvider.notifier).state = session.customer;
    ref.read(manualBillDiscountProvider.notifier).state = session.manualDiscount;
  }
  
  void onSaleCompleted() {
    if (state.sessions.length > 1) {
      removeSession(state.activeIndex);
    } else {
      ref.read(cartProvider.notifier).clear();
      ref.read(selectedCustomerProvider.notifier).state = null;
      ref.read(manualBillDiscountProvider.notifier).state = null;
      
      final sessions = [...state.sessions];
      sessions[0] = sessions[0].copyWith(
        items: [],
        customer: null,
        manualDiscount: null,
        updatedAt: DateTime.now(),
      );
      state = state.copyWith(sessions: sessions);
    }
  }

  void updateActiveSessionFromProviders() {
    _saveCurrentToSession();
  }
}

final multiBillProvider = StateNotifierProvider<MultiBillNotifier, MultiBillState>((ref) {
  final notifier = MultiBillNotifier(ref);
  
  // Register listeners for auto-save
  ref.listen(cartProvider, (_, __) => notifier.updateActiveSessionFromProviders());
  ref.listen(selectedCustomerProvider, (_, __) => notifier.updateActiveSessionFromProviders());
  ref.listen(manualBillDiscountProvider, (_, __) => notifier.updateActiveSessionFromProviders());
  
  return notifier;
});
