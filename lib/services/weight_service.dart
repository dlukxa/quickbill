import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';

enum ScaleStatus { disconnected, connecting, connected, error }

class WeightService {
  static final WeightService _instance = WeightService._internal();
  factory WeightService() => _instance;
  WeightService._internal();

  final _weightController = StreamController<double>.broadcast();
  Stream<double> get weightStream => _weightController.stream;

  final _statusController = StreamController<ScaleStatus>.broadcast();
  Stream<ScaleStatus> get statusStream => _statusController.stream;

  bool _isSimulationMode = false;
  Timer? _simulationTimer;
  double _currentWeight = 0.0;
  ScaleStatus _status = ScaleStatus.disconnected;

  ScaleStatus get status => _status;
  bool get isSimulationMode => _isSimulationMode;

  void setSimulationMode(bool enabled) {
    _isSimulationMode = enabled;
    if (enabled) {
      _startSimulation();
      _updateStatus(ScaleStatus.connected);
    } else {
      _stopSimulation();
      _updateStatus(ScaleStatus.disconnected);
    }
  }

  void _startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // Simulate weight changes when something is "on the scale"
      // We'll vary it slightly around a target if it's "placed"
      if (_currentWeight > 0) {
        final variation = (Random().nextDouble() - 0.5) * 0.02;
        _currentWeight = (_currentWeight + variation).clamp(0.0, 50.0);
      }
      _weightController.add(_currentWeight);
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    _currentWeight = 0.0;
    _weightController.add(0.0);
  }

  /// Manually set the weight for simulation purposes (e.g. "placing" an item)
  void simulateWeightPlacement(double targetWeight) {
    if (!_isSimulationMode) return;
    _currentWeight = targetWeight;
    _weightController.add(_currentWeight);
  }

  void _updateStatus(ScaleStatus newStatus) {
    _status = newStatus;
    _statusController.add(_status);
  }

  // Basic BLE placeholders (would be expanded for specific hardware protocols)
  
  Future<void> connectToScale() async {
    if (_isSimulationMode) return;
    
    _updateStatus(ScaleStatus.connecting);
    
    try {
      // 1. Check permissions and adapter state
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        debugPrint('Bluetooth is off');
        _updateStatus(ScaleStatus.error);
        return;
      }

      // 2. Start scanning (highly simplified)
      // In a real app, we'd look for specific manufacturer IDs or service UUIDs
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      
      // For this implementation, we'll keep it as a framework
      // Actual protocol varies wildly between scale brands (e.g. CAS, Digi, Adam Equipment)
      
      _updateStatus(ScaleStatus.disconnected); // Fallback since no real hardware is here
    } catch (e) {
      debugPrint('Scale connection error: $e');
      _updateStatus(ScaleStatus.error);
    }
  }

  void dispose() {
    _simulationTimer?.cancel();
    _weightController.close();
    _statusController.close();
  }
}
