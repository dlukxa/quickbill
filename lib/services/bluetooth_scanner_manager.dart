import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages Bluetooth barcode scanner connections and data streaming
class BluetoothScannerManager {
  static const String _prefKeyDeviceId = 'bluetooth_scanner_device_id';
  static const String _prefKeyDeviceName = 'bluetooth_scanner_device_name';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _barcodeCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _characteristicSubscription;
  
  final _barcodeController = StreamController<String>.broadcast();
  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  
  Stream<String> get barcodeStream => _barcodeController.stream;
  Stream<BluetoothConnectionState> get connectionStateStream => _connectionStateController.stream;
  
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;

  /// Request necessary Bluetooth permissions
  Future<bool> requestPermissions() async {
    if (await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted) {
      return true;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Required for Bluetooth scanning on Android
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  /// Start scanning for nearby Bluetooth devices
  Future<List<ScanResult>> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      throw Exception('Bluetooth permissions not granted');
    }

    final devices = <ScanResult>[];
    final completer = Completer<List<ScanResult>>();

    // Check if Bluetooth is available and on
    if (await FlutterBluePlus.isSupported == false) {
      throw Exception('Bluetooth not supported on this device');
    }

    // Start scanning
    await FlutterBluePlus.startScan(timeout: timeout);

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      devices.clear();
      devices.addAll(results);
    });

    // Complete after timeout
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(devices);
      }
    });

    final result = await completer.future;
    await stopScan();
    return result;
  }

  /// Stop scanning for devices
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
  }

  /// Connect to a Bluetooth device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // Disconnect from current device if any
      await disconnect();

      // Connect to the new device
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      // Listen to connection state changes
      device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _barcodeCharacteristic = null;
        }
      });

      // Discover services
      final services = await device.discoverServices();
      
      // Look for a characteristic that might contain barcode data
      // Common UUIDs for barcode scanners (SPP profile)
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // Look for characteristics with notify property
          if (characteristic.properties.notify || characteristic.properties.indicate) {
            _barcodeCharacteristic = characteristic;
            
            // Subscribe to notifications
            await characteristic.setNotifyValue(true);
            
            _characteristicSubscription = characteristic.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                // Convert bytes to string (assuming ASCII encoding)
                final barcode = String.fromCharCodes(value).trim();
                if (barcode.isNotEmpty) {
                  _barcodeController.add(barcode);
                }
              }
            });
            
            break;
          }
        }
        if (_barcodeCharacteristic != null) break;
      }

      // Save device info to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDeviceId, device.remoteId.toString());
      await prefs.setString(_prefKeyDeviceName, device.platformName);
      
    } catch (e) {
      _connectedDevice = null;
      _barcodeCharacteristic = null;
      rethrow;
    }
  }

  /// Disconnect from the current device
  Future<void> disconnect() async {
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _barcodeCharacteristic = null;
    }
  }

  /// Try to reconnect to the last connected device
  Future<bool> reconnectToLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_prefKeyDeviceId);
    
    if (deviceId == null) return false;

    try {
      // Scan for the device
      final results = await startScan();
      final device = results
          .map((r) => r.device)
          .firstWhere(
            (d) => d.remoteId.toString() == deviceId,
            orElse: () => throw Exception('Device not found'),
          );
      
      await connectToDevice(device);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get the saved device info
  Future<Map<String, String>?> getSavedDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_prefKeyDeviceId);
    final deviceName = prefs.getString(_prefKeyDeviceName);
    
    if (deviceId == null) return null;
    
    return {
      'id': deviceId,
      'name': deviceName ?? 'Unknown Device',
    };
  }

  /// Clear saved device info
  Future<void> clearSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyDeviceId);
    await prefs.remove(_prefKeyDeviceName);
  }

  /// Dispose and cleanup
  void dispose() {
    _scanSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _barcodeController.close();
    _connectionStateController.close();
    disconnect();
  }
}
