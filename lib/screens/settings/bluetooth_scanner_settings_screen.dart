import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../config/theme.dart';
import '../../providers/bluetooth_scanner_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_button.dart';

class BluetoothScannerSettingsScreen extends ConsumerStatefulWidget {
  const BluetoothScannerSettingsScreen({super.key});

  @override
  ConsumerState<BluetoothScannerSettingsScreen> createState() =>
      _BluetoothScannerSettingsScreenState();
}

class _BluetoothScannerSettingsScreenState
    extends ConsumerState<BluetoothScannerSettingsScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String? _testBarcode;

  @override
  Widget build(BuildContext context) {
    final scannerState = ref.watch(bluetoothScannerProvider);
    final scannerNotifier = ref.read(bluetoothScannerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Scanner'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildConnectionStatus(scannerState, scannerNotifier),
          const SizedBox(height: 20),
          _buildScanSection(scannerNotifier),
          if (_scanResults.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildDeviceList(scannerNotifier),
          ],
          const SizedBox(height: 20),
          _buildTestSection(scannerState),
          const SizedBox(height: 20),
          _buildInfoSection(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(
      BluetoothScannerState state, BluetoothScannerNotifier notifier) {
    final isConnected = state.isConnected;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: isConnected ? Colors.green : Colors.grey,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? 'Connected' : 'Not Connected',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isConnected && state.connectedDevice != null)
                      Text(
                        state.connectedDevice!.platformName,
                        style: const TextStyle(color: Colors.grey),
                      )
                    else
                      const Text(
                        'No scanner connected',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
              if (isConnected)
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.errorRed),
                  onPressed: () async {
                    await notifier.disconnect();
                    await notifier.clearSavedDevice();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Disconnected from scanner')),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanSection(BluetoothScannerNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'FIND DEVICES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        GradientButton(
          onPressed: _isScanning ? null : () => _startScan(notifier),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isScanning)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(Icons.search, color: Colors.white),
              const SizedBox(width: 8),
              Text(_isScanning ? 'SCANNING...' : 'SCAN FOR DEVICES'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceList(BluetoothScannerNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AVAILABLE DEVICES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ..._scanResults.map((result) {
          final device = result.device;
          final name = device.platformName.isEmpty
              ? 'Unknown Device'
              : device.platformName;
          final rssi = result.rssi;

          return AppCard(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.bluetooth),
              ),
              title: Text(name),
              subtitle: Text('Signal: $rssi dBm'),
              trailing: ElevatedButton(
                onPressed: () => _connectToDevice(device, notifier),
                child: const Text('CONNECT'),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTestSection(BluetoothScannerState state) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TEST SCANNER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          if (!state.isConnected)
            const Text(
              'Connect a scanner to test',
              style: TextStyle(color: Colors.grey),
            )
          else ...[
            const Text('Scan a barcode with your connected device:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadiusDirectional.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _testBarcode ?? 'Waiting for scan...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: _testBarcode != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _testBarcode != null ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                  if (_testBarcode != null)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryBlue.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              const Text(
                'About Bluetooth Scanners',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Make sure your scanner is in pairing mode\n'
            '• Most scanners will appear as "Bluetooth" or similar\n'
            '• HID mode scanners work automatically as keyboard input\n'
            '• SPP/BLE mode scanners need to be connected here\n'
            '• Once connected, your scanner will work throughout the app',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _startScan(BluetoothScannerNotifier notifier) async {
    setState(() {
      _isScanning = true;
      _scanResults = [];
    });

    try {
      final results = await notifier.startScan();
      setState(() {
        _scanResults = results;
        _isScanning = false;
      });

      if (_scanResults.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No devices found. Make sure scanner is in pairing mode.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning: $e')),
        );
      }
    }
  }

  Future<void> _connectToDevice(
      BluetoothDevice device, BluetoothScannerNotifier notifier) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await notifier.connectToDevice(device);
      
      // Listen for test barcodes
      notifier.barcodeStream.listen((barcode) {
        if (mounted) {
          setState(() => _testBarcode = barcode);
        }
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.platformName}'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _scanResults = [];
          _testBarcode = null;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }
  }
}
