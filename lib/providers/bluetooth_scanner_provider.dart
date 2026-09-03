import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_scanner_manager.dart';

/// Provider for the Bluetooth scanner manager instance
final bluetoothScannerManagerProvider = Provider<BluetoothScannerManager>((ref) {
  final manager = BluetoothScannerManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// State class for Bluetooth scanner connection
class BluetoothScannerState {
  final BluetoothDevice? connectedDevice;
  final BluetoothConnectionState connectionState;
  final String? lastScannedBarcode;
  final bool isScanning;

  const BluetoothScannerState({
    this.connectedDevice,
    this.connectionState = BluetoothConnectionState.disconnected,
    this.lastScannedBarcode,
    this.isScanning = false,
  });

  BluetoothScannerState copyWith({
    BluetoothDevice? connectedDevice,
    BluetoothConnectionState? connectionState,
    String? lastScannedBarcode,
    bool? isScanning,
  }) {
    return BluetoothScannerState(
      connectedDevice: connectedDevice ?? this.connectedDevice,
      connectionState: connectionState ?? this.connectionState,
      lastScannedBarcode: lastScannedBarcode ?? this.lastScannedBarcode,
      isScanning: isScanning ?? this.isScanning,
    );
  }

  bool get isConnected => connectionState == BluetoothConnectionState.connected;
}

/// Notifier for managing Bluetooth scanner state
class BluetoothScannerNotifier extends StateNotifier<BluetoothScannerState> {
  final BluetoothScannerManager _manager;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _barcodeSubscription;

  BluetoothScannerNotifier(this._manager) : super(const BluetoothScannerState()) {
    _init();
  }

  void _init() {
    // Listen to connection state changes
    _connectionSubscription = _manager.connectionStateStream.listen((connectionState) {
      if (mounted) {
        state = state.copyWith(
          connectionState: connectionState,
          connectedDevice: connectionState == BluetoothConnectionState.connected
              ? _manager.connectedDevice
              : null,
        );
      }
    });

    // Listen to barcode scans
    _barcodeSubscription = _manager.barcodeStream.listen((barcode) {
      if (mounted) state = state.copyWith(lastScannedBarcode: barcode);
    });

    // Try to reconnect to last device
    _reconnectToLastDevice();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _barcodeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _reconnectToLastDevice() async {
    try {
      await _manager.reconnectToLastDevice();
    } catch (e) {
      // Silent fail - user can manually connect
    }
  }

  Future<List<ScanResult>> startScan() async {
    if (mounted) state = state.copyWith(isScanning: true);
    try {
      return await _manager.startScan();
    } finally {
      if (mounted) state = state.copyWith(isScanning: false);
    }
  }

  Future<void> stopScan() async {
    await _manager.stopScan();
    if (mounted) state = state.copyWith(isScanning: false);
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await _manager.connectToDevice(device);
  }

  Future<void> disconnect() async {
    await _manager.disconnect();
    if (mounted) {
      state = state.copyWith(
        connectedDevice: null,
        connectionState: BluetoothConnectionState.disconnected,
      );
    }
  }

  Future<Map<String, String>?> getSavedDeviceInfo() async {
    return await _manager.getSavedDeviceInfo();
  }

  Future<void> clearSavedDevice() async {
    await _manager.clearSavedDevice();
  }

  Stream<String> get barcodeStream => _manager.barcodeStream;
}

/// Provider for Bluetooth scanner state
final bluetoothScannerProvider =
    StateNotifierProvider<BluetoothScannerNotifier, BluetoothScannerState>((ref) {
  final manager = ref.watch(bluetoothScannerManagerProvider);
  return BluetoothScannerNotifier(manager);
});
