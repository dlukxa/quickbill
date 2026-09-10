import 'dart:io';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import '../providers/preference_provider.dart';

class DrawerKickResult {
  final bool success;
  final String message;

  const DrawerKickResult({required this.success, required this.message});
}

/// Dedicated service for ejecting/opening the physical cash drawer in Retail POS.
/// Supports:
/// 1. Printer-driven RJ11/RJ12 kick (Epson, Xprinter, Rongta, POS-80, POS-58, Star Micronics)
///    via Windows Print Spooler (`winspool.drv` RAW byte injection), Network LAN TCP socket,
///    and Android Bluetooth SPP.
/// 2. Standalone USB Serial Trigger adapters (e.g. BT-100U on COM1..COM9).
class CashDrawerService {
  CashDrawerService._();
  static final CashDrawerService instance = CashDrawerService._();

  DateTime? _lastKickTime;
  File? _cachedPs1File;

  /// Universal ESC/POS kick pulse payload:
  /// - Pin 2 pulse: ESC p 0 25 250 -> [27, 112, 0, 25, 250] (Epson/Xprinter/Rongta/POS-80)
  /// - Pin 5 pulse: ESC p 1 25 250 -> [27, 112, 1, 25, 250] (Alternate solenoid pin)
  /// - Star Micronics: BEL -> [7]
  static const List<int> universalKickBytes = [
    0x1B, 0x70, 0x00, 0x19, 0xFA,
    0x1B, 0x70, 0x01, 0x19, 0xFA,
    0x07,
  ];

  /// Opens the cash drawer based on current AppSettings.
  /// Throttled to prevent solenoid strain if called multiple times within 600ms.
  Future<DrawerKickResult> openCashDrawer(
    AppSettings settings, {
    bool isManual = false,
  }) async {
    final now = DateTime.now();
    if (_lastKickTime != null && now.difference(_lastKickTime!).inMilliseconds < 600) {
      return const DrawerKickResult(success: true, message: 'Drawer already triggered.');
    }
    _lastKickTime = now;

    try {
      // 1. Standalone USB COM Port Trigger (e.g. BT-100U adapter)
      if (settings.cashDrawerTriggerType == 'com_port') {
        return await _kickComPort(settings.cashDrawerComPort);
      }

      // 2. Network / LAN / Wi-Fi Thermal Printer (Direct TCP socket)
      if (settings.printerConnectionType.toLowerCase() == 'network') {
        return await _kickNetworkPrinter(settings.printerIpAddress, settings.printerPort);
      }

      // 3. Windows Desktop Thermal Printer (Direct Spooler winspool.drv RAW write)
      if (Platform.isWindows) {
        return await _kickWindowsPrinter(settings.selectedPrinterName);
      }

      // 4. Android Bluetooth Thermal Printer
      if (Platform.isAndroid) {
        return await _kickBluetoothPrinter();
      }

      // 5. macOS / Linux Fallback
      if (Platform.isMacOS || Platform.isLinux) {
        return await _kickCupsPrinter(settings.selectedPrinterName);
      }

      return const DrawerKickResult(
        success: false,
        message: 'Unsupported cash drawer platform configuration.',
      );
    } catch (e) {
      debugPrint('CashDrawerService error: $e');
      return DrawerKickResult(
        success: false,
        message: 'Failed to open cash drawer: $e',
      );
    }
  }

  // ─── Network Socket Kick ───────────────────────────────────────────────────

  Future<DrawerKickResult> _kickNetworkPrinter(String ip, int port) async {
    Socket? socket;
    try {
      final cleanIp = ip.trim();
      if (cleanIp.isEmpty) {
        return const DrawerKickResult(
          success: false,
          message: 'Network printer IP is not configured.',
        );
      }

      socket = await Socket.connect(cleanIp, port, timeout: const Duration(milliseconds: 1500));
      socket.add(universalKickBytes);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 80));
      await socket.close();

      return DrawerKickResult(
        success: true,
        message: 'Drawer pulse sent to network printer ($cleanIp:$port).',
      );
    } catch (e) {
      try {
        await socket?.close();
      } catch (_) {}
      return DrawerKickResult(
        success: false,
        message: 'Could not connect to network printer ($ip:$port): $e',
      );
    }
  }

  // ─── Windows Spooler RAW Kick ──────────────────────────────────────────────

  Future<DrawerKickResult> _kickWindowsPrinter(String? printerName) async {
    try {
      final scriptFile = await _getOrCreateWindowsKickScript();
      final targetPrinter = printerName?.trim() ?? '';

      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptFile.path,
          '-printerName',
          targetPrinter,
        ],
        runInShell: true,
      ).timeout(const Duration(seconds: 4));

      final output = (result.stdout as String? ?? '').trim();
      if (result.exitCode == 0) {
        return DrawerKickResult(
          success: true,
          message: output.isNotEmpty ? output : 'Cash drawer ejected via Windows printer.',
        );
      } else {
        final err = (result.stderr as String? ?? '').trim();
        debugPrint('Windows drawer kick exitCode ${result.exitCode}: $err');
        // Fallback to direct raw copy if available
        return await _fallbackWindowsRawCopy(targetPrinter);
      }
    } catch (e) {
      debugPrint('Windows print spooler kick error: $e');
      return DrawerKickResult(
        success: false,
        message: 'Windows cash drawer kick error: $e',
      );
    }
  }

  /// Creates and caches the PowerShell Win32 spooler raw byte injector script
  Future<File> _getOrCreateWindowsKickScript() async {
    if (_cachedPs1File != null && await _cachedPs1File!.exists()) {
      return _cachedPs1File!;
    }

    final file = File('${Directory.systemTemp.path}/quickbill_drawer_kick.ps1');

    const script = r'''
param([string]$printerName = "")

if (-not $printerName -or $printerName.Trim() -eq "") {
    try {
        $p = Get-CimInstance Win32_Printer | Where-Object { $_.Default -eq $true } | Select-Object -First 1
        if (-not $p) {
            $p = Get-CimInstance Win32_Printer | Select-Object -First 1
        }
        if ($p) {
            $printerName = $p.Name
        }
    } catch {
        $printerName = ""
    }
}

if (-not $printerName -or $printerName.Trim() -eq "") {
    Write-Host "No installed Windows printer found."
    exit 1
}

$csharpCode = @"
using System;
using System.Runtime.InteropServices;

public class RawPrinterHelper {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public class DOCINFOA {
        [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
    }

    [DllImport("winspool.Drv", EntryPoint = "OpenPrinterA", SetLastError = true, CharSet = CharSet.Ansi, CallingConvention = CallingConvention.StdCall)]
    public static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPStr)] string szPrinter, out IntPtr hPrinter, IntPtr pd);

    [DllImport("winspool.Drv", EntryPoint = "ClosePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartDocPrinterA", SetLastError = true, CharSet = CharSet.Ansi, CallingConvention = CallingConvention.StdCall)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, int level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);

    [DllImport("winspool.Drv", EntryPoint = "EndDocPrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "WritePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);

    public static bool SendBytes(string printer, byte[] bytes) {
        IntPtr hPrinter;
        if (!OpenPrinter(printer, out hPrinter, IntPtr.Zero)) {
            return false;
        }

        DOCINFOA di = new DOCINFOA();
        di.pDocName = "QuickBill Cash Drawer";
        di.pDataType = "RAW";

        bool success = false;
        if (StartDocPrinter(hPrinter, 1, di)) {
            IntPtr pUnmanagedBytes = Marshal.AllocCoTaskMem(bytes.Length);
            Marshal.Copy(bytes, 0, pUnmanagedBytes, bytes.Length);
            int written;
            success = WritePrinter(hPrinter, pUnmanagedBytes, bytes.Length, out written);
            Marshal.FreeCoTaskMem(pUnmanagedBytes);
            EndDocPrinter(hPrinter);
        }
        ClosePrinter(hPrinter);
        return success;
    }
}
"@

try {
    Add-Type -TypeDefinition $csharpCode -ErrorAction SilentlyContinue
} catch {}

$kickBytes = [byte[]]@(27, 112, 0, 25, 250, 27, 112, 1, 25, 250, 7)

try {
    $ok = [RawPrinterHelper]::SendBytes($printerName, $kickBytes)
    if ($ok) {
        Write-Host "Drawer kicked successfully via printer: $printerName"
        exit 0
    } else {
        Write-Host "Unable to open printer spooler for: $printerName"
        exit 2
    }
} catch {
    Write-Host "Error sending pulse: $_"
    exit 3
}
''';

    await file.writeAsString(script);
    _cachedPs1File = file;
    return file;
  }

  /// Fallback command if PowerShell winspool fails
  Future<DrawerKickResult> _fallbackWindowsRawCopy(String printerName) async {
    try {
      if (printerName.isEmpty) {
        return const DrawerKickResult(
          success: false,
          message: 'No printer specified for raw binary copy.',
        );
      }

      final binFile = File('${Directory.systemTemp.path}/quickbill_drawer_kick.bin');
      await binFile.writeAsBytes(universalKickBytes);

      // Attempt copy to shared localhost printer queue
      final res = await Process.run(
        'cmd.exe',
        ['/c', 'copy', '/b', binFile.path, '\\\\127.0.0.1\\$printerName'],
        runInShell: true,
      ).timeout(const Duration(seconds: 2));

      if (res.exitCode == 0) {
        return DrawerKickResult(
          success: true,
          message: 'Drawer kick sent via printer share: $printerName',
        );
      }
    } catch (_) {}

    return DrawerKickResult(
      success: false,
      message: 'Could not communicate with Windows printer "$printerName".',
    );
  }

  // ─── USB Serial COM Port Kick (BT-100U Trigger Box) ─────────────────────────

  Future<DrawerKickResult> _kickComPort(String comPort) async {
    try {
      final cleanPort = comPort.trim().toUpperCase();
      if (cleanPort.isEmpty) {
        return const DrawerKickResult(
          success: false,
          message: 'COM port is not specified (e.g. COM1, COM2, COM3).',
        );
      }

      if (Platform.isWindows) {
        // Send byte pulse to virtual serial COM port via PowerShell System.IO.Ports
        final script = '''
try {
  \$port = New-Object System.IO.Ports.SerialPort "$cleanPort", 9600, None, 8, one
  \$port.Open()
  \$bytes = [byte[]]@(27, 112, 0, 25, 250, 1)
  \$port.Write(\$bytes, 0, \$bytes.Length)
  Start-Sleep -Milliseconds 100
  \$port.Close()
  Write-Host "COM port pulse sent successfully."
} catch {
  Write-Host "Error writing to $cleanPort: \$_"
  exit 1
}
''';
        final res = await Process.run(
          'powershell',
          ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
          runInShell: true,
        ).timeout(const Duration(seconds: 3));

        if (res.exitCode == 0) {
          return DrawerKickResult(
            success: true,
            message: 'Cash drawer ejected via $cleanPort.',
          );
        } else {
          // Alternative: direct cmd echo to COM device
          await Process.run('cmd.exe', ['/c', 'echo 1 > \\\\.\\$cleanPort'], runInShell: true);
          return DrawerKickResult(
            success: true,
            message: 'Pulse sent to $cleanPort.',
          );
        }
      }

      return DrawerKickResult(
        success: false,
        message: 'Serial COM trigger is currently supported on Windows.',
      );
    } catch (e) {
      return DrawerKickResult(
        success: false,
        message: 'Failed to write to $comPort: $e',
      );
    }
  }

  // ─── Android Bluetooth Kick ────────────────────────────────────────────────

  Future<DrawerKickResult> _kickBluetoothPrinter() async {
    try {
      final bluetooth = BlueThermalPrinter.instance;
      final bool isConnected = await bluetooth.isConnected ?? false;
      if (!isConnected) {
        return const DrawerKickResult(
          success: false,
          message: 'Bluetooth thermal printer is not connected.',
        );
      }

      await bluetooth.writeBytes(Uint8List.fromList(universalKickBytes));
      return const DrawerKickResult(
        success: true,
        message: 'Cash drawer pulse sent via Bluetooth printer.',
      );
    } catch (e) {
      return DrawerKickResult(
        success: false,
        message: 'Bluetooth cash drawer kick error: $e',
      );
    }
  }

  // ─── macOS / Linux CUPS Kick ───────────────────────────────────────────────

  Future<DrawerKickResult> _kickCupsPrinter(String? printerName) async {
    try {
      final binFile = File('${Directory.systemTemp.path}/quickbill_drawer_kick.bin');
      await binFile.writeAsBytes(universalKickBytes);

      final args = printerName != null && printerName.isNotEmpty
          ? ['-d', printerName, '-o', 'raw', binFile.path]
          : ['-o', 'raw', binFile.path];

      final res = await Process.run('lp', args).timeout(const Duration(seconds: 2));
      if (res.exitCode == 0) {
        return const DrawerKickResult(
          success: true,
          message: 'Drawer kick sent via CUPS raw queue.',
        );
      }
    } catch (e) {
      debugPrint('CUPS kick error: $e');
    }

    return const DrawerKickResult(
      success: false,
      message: 'Could not send drawer kick on this OS.',
    );
  }
}
