import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../models/employee.dart';
import '../../services/auth_service.dart';
import '../../services/staff_login_service.dart';

class StaffLoginHandshakeDialog extends ConsumerStatefulWidget {
  final Employee employee;
  const StaffLoginHandshakeDialog({super.key, required this.employee});

  static void show(BuildContext context, Employee employee) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StaffLoginHandshakeDialog(employee: employee),
    );
  }

  @override
  ConsumerState<StaffLoginHandshakeDialog> createState() => _StaffLoginHandshakeDialogState();
}

class _StaffLoginHandshakeDialogState extends ConsumerState<StaffLoginHandshakeDialog> {
  String? _code;
  final ValueNotifier<int> _secondsRemaining = ValueNotifier<int>(120);
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifyAndGenerate();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _secondsRemaining.dispose();
    super.dispose();
  }

  Future<void> _verifyAndGenerate() async {
    if (!mounted) return;
    
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      final email = user.email ?? user.phoneNumber ?? 'phone_user';
      const passwordPlaceholder = 'bypass_password';

      final code = await StaffLoginService.instance.generateLoginCode(
        widget.employee,
        user.uid,
        email,
        passwordPlaceholder,
      );

      if (mounted) {
        setState(() {
          _code = code;
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining.value > 0) {
        _secondsRemaining.value--;
      } else {
        timer.cancel();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isLoading ? 'Generating Code' : 'Login for ${widget.employee.name}'),
      content: SizedBox(
        width: 300,
        child: _isLoading 
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 40),
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text('Creating secure code...', style: TextStyle(color: AppTheme.textSecondary)),
                SizedBox(height: 40),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: _code ?? '',
                      version: QrVersions.auto,
                      size: 200.0,
                      gapless: false,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('STAFF CODE:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text(
                  _code ?? '------',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                ),
                const SizedBox(height: 24),
                ValueListenableBuilder<int>(
                  valueListenable: _secondsRemaining,
                  builder: (context, seconds, _) {
                    return Text(
                      'Expires in $seconds seconds',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ],
            ),
      ),
      actions: _isLoading ? [] : [
        TextButton.icon(
          onPressed: () {
            Share.share(
              'QuickBill POS Staff Login\n'
              'Employee: ${widget.employee.name}\n'
              'Login Code: ${_code}\n'
              'Valid for 2 minutes.',
            );
          },
          icon: const Icon(Icons.share),
          label: const Text('Share'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
