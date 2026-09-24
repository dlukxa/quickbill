import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/theme.dart';
import '../../services/staff_login_service.dart';
import '../../widgets/store_logo_widget.dart';

/// Default test shop UID pre-configured with demo products, categories, and cashiers
const String kDefaultTestShopUid = 'iiFadszr3lZYVMX61f7hbIB56492';

/// QR and Code-based shop linking screen for the Windows / Desktop app.
/// Supports multiple join methods:
///   1. Scan QR code from mobile app (Settings → Open on PC).
///   2. Enter the 6-digit PC pairing code in the mobile app.
///   3. Enter Shop Code / UID, Staff Code, or TEST directly on PC.
///   4. One-Click Test Mode for fast desktop testing.
///   5. Sign in directly with Store Owner Email & Password.
class DesktopQrLinkScreen extends StatefulWidget {
  final void Function(String shopUid) onLinked;

  const DesktopQrLinkScreen({super.key, required this.onLinked});

  @override
  State<DesktopQrLinkScreen> createState() => _DesktopQrLinkScreenState();
}

class _DesktopQrLinkScreenState extends State<DesktopQrLinkScreen>
    with SingleTickerProviderStateMixin {
  String? _sessionId;
  String? _pairingCode;
  String? _syncStatus;
  StreamSubscription<DocumentSnapshot>? _sessionSub;
  Timer? _pollTimer;
  Timer? _refreshTimer;
  double _countdown = 90.0;
  Timer? _countdownTimer;
  late AnimationController _pulseController;

  // Code Input State (for manual/test dialog)
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isActionLoading = false;
  String? _actionError;
  bool _showPassword = false;
  bool _isOwnerLoginExpanded = false;
  StateSetter? _dialogSetState;

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    } else {
      fn();
    }
    _dialogSetState?.call(() {});
  }

  void _completeLinking(String shopUid) {
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    widget.onLinked(shopUid);
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _createSession();
  }

  void _cleanupSession(String? sessionId) {
    if (sessionId == null) return;
    // 1. Fire-and-forget REST delete (platform independent)
    try {
      final client = HttpClient();
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/quickbill-2a76b/databases/(default)/documents/pc_sessions/$sessionId',
      );
      client.deleteUrl(uri).then((req) async {
        final resp = await req.close();
        await resp.drain();
        client.close();
      }).catchError((_) {
        client.close();
        return null;
      });
    } catch (_) {}

    // 2. Native Firestore delete if available
    if (Firebase.apps.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('pc_sessions')
          .doc(sessionId)
          .delete()
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _cleanupSession(_sessionId);
    _pollTimer?.cancel();
    _sessionSub?.cancel();
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    // Clean up previous timers and session doc if refreshing
    _pollTimer?.cancel();
    _sessionSub?.cancel();
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();

    _cleanupSession(_sessionId);

    // ── STEP 1: Generate session & code synchronously — zero delay, zero timeout ──
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    final sessionId = 'pc_${List.generate(20, (_) => chars[rng.nextInt(chars.length)]).join()}';
    final pairingCode = (100000 + rng.nextInt(900000)).toString();

    // ── STEP 2: Show QR immediately — user sees it right away ──
    if (!mounted) return;
    setState(() {
      _sessionId = sessionId;
      _pairingCode = pairingCode;
      _countdown = 90.0;
      _syncStatus = null;
    });

    // Start countdown timer immediately
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _countdown = (_countdown - 1).clamp(0, 90);
      });
    });

    // Auto-refresh after 90 seconds
    _refreshTimer = Timer(const Duration(seconds: 90), () {
      _createSession();
    });

    // ── STEP 3: Write to Firestore in the background (non-blocking) ──
    _writeSessionToFirestore(sessionId, pairingCode);
  }

  /// Writes the pairing session to Firestore in the background.
  /// Uses direct REST API first so Windows never hangs on native C++ Firebase plugins.
  Future<void> _writeSessionToFirestore(String sessionId, String pairingCode) async {
    bool written = false;

    // 1. Direct REST write to Firestore
    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/quickbill-2a76b/databases/(default)/documents/pc_sessions/$sessionId',
      );
      final req = await client.patchUrl(uri).timeout(const Duration(seconds: 5));
      req.headers.contentType = ContentType.json;
      final body = jsonEncode({
        'fields': {
          'status': {'stringValue': 'pending'},
          'pairingCode': {'stringValue': pairingCode},
          'expiresAt': {'stringValue': DateTime.now().add(const Duration(minutes: 5)).toIso8601String()},
          'createdAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
        }
      });
      req.write(body);
      final resp = await req.close().timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        written = true;
      }
      await resp.drain();
    } catch (e) {
      debugPrint('DesktopQrLinkScreen REST write session note: $e');
    } finally {
      client.close();
    }

    // 2. Also try native Firestore if already initialized
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('pc_sessions').doc(sessionId).set({
          'status': 'pending',
          'pairingCode': pairingCode,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
        }).timeout(const Duration(seconds: 4));
        written = true;
      } catch (e) {
        debugPrint('DesktopQrLinkScreen native Firestore write fallback note: $e');
      }
    }

    if (!written && mounted) {
      // Never wipe or hide QR code! Just display a subtle status indicator
      setState(() {
        _syncStatus = 'Offline mode (Cloud sync pending). Use Code or Test Mode below.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _syncStatus = null;
    });

    // ── STEP 4: Poll for mobile authentication via REST every 1.5s ──
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final shopUid = await _checkSessionStatusViaRest(sessionId);
      if (shopUid != null && mounted) {
        timer.cancel();
        _cleanupSession(sessionId);
        _completeLinking(shopUid);
      }
    });

    // ── STEP 5: Also listen via native Firestore stream if available ──
    if (Firebase.apps.isNotEmpty) {
      try {
        _sessionSub = FirebaseFirestore.instance
            .collection('pc_sessions')
            .doc(sessionId)
            .snapshots()
            .listen((snap) {
          if (!snap.exists) return;
          final data = snap.data();
          if (data == null) return;
          if (data['status'] == 'authenticated' && data['shopUid'] != null) {
            _pollTimer?.cancel();
            _sessionSub?.cancel();
            _cleanupSession(sessionId);
            _completeLinking(data['shopUid'] as String);
          }
        }, onError: (err) {
          debugPrint('DesktopQrLinkScreen native stream error: $err');
        });
      } catch (_) {}
    }
  }

  Future<String?> _checkSessionStatusViaRest(String sessionId) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/quickbill-2a76b/databases/(default)/documents/pc_sessions/$sessionId',
      );
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 4));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final fields = data['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          final status = fields['status']?['stringValue'] as String?;
          final shopUid = fields['shopUid']?['stringValue'] as String?;
          if (status == 'authenticated' && shopUid != null && shopUid.isNotEmpty) {
            return shopUid;
          }
        }
      }
    } catch (_) {
      // Ignore transient polling exceptions
    } finally {
      client.close();
    }
    return null;
  }

  Future<void> _linkWithCode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) {
      _safeSetState(() => _actionError = 'Please enter a shop code, staff code, or TEST');
      return;
    }

    _safeSetState(() {
      _isActionLoading = true;
      _actionError = null;
    });

    try {
      // 1. Fast path for test/demo mode (supports 999999, 123456, TEST, DEMO)
      final upper = code.toUpperCase();
      if (upper == 'TEST' || upper == 'DEMO' || upper == 'TESTING' || code == '123456' || code == '999999') {
        _completeLinking(kDefaultTestShopUid);
        return;
      }

      // 2. 6-digit code validation (Staff code or PC pairing code)
      if (RegExp(r'^\d{6}$').hasMatch(code)) {
        // A. Staff handshake code check
        try {
          final credentials = await StaffLoginService.instance.validateLoginCode(code);
          if (credentials != null && credentials['owner_uid'] != null) {
            _completeLinking(credentials['owner_uid'] as String);
            return;
          }
        } catch (e) {
          debugPrint('Staff login code check error: $e');
        }

        // B. PC session pairing code check
        try {
          final snap = await FirebaseFirestore.instance
              .collection('pc_sessions')
              .where('pairingCode', isEqualTo: code)
              .where('status', isEqualTo: 'authenticated')
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            final data = snap.docs.first.data();
            if (data['shopUid'] != null) {
              _completeLinking(data['shopUid'] as String);
              return;
            }
          }
        } catch (e) {
          debugPrint('PC pairing code check error: $e');
        }
      }

      // 3. Direct Shop UID check
      if (code.length >= 10) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(code)
              .get();
          if (userDoc.exists) {
            _completeLinking(code);
            return;
          }
        } catch (_) {
          // If offline or permission rules restrict direct doc get,
          // connect with the specified Shop UID directly
          _completeLinking(code);
          return;
        }
      }

      throw Exception('Code "$code" not recognized. Use "TEST" for instant testing, a 6-digit staff code, or your Shop UID.');
    } catch (e) {
      _safeSetState(() {
        _actionError = e.toString().replaceAll('Exception: ', '');
        _isActionLoading = false;
      });
    }
  }

  Future<void> _signInWithEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _safeSetState(() => _actionError = 'Please enter both email and password');
      return;
    }

    _safeSetState(() {
      _isActionLoading = true;
      _actionError = null;
    });

    if (Firebase.apps.isEmpty) {
      _safeSetState(() {
        _actionError = 'Direct cloud login requires online Firebase. Use One-Click Test Mode or enter shop code.';
        _isActionLoading = false;
      });
      return;
    }

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        _completeLinking(cred.user!.uid);
      } else {
        throw Exception('Authentication failed');
      }
    } catch (e) {
      _safeSetState(() {
        _actionError = 'Login failed: ${e.toString().replaceAll('Exception: ', '')}';
        _isActionLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo + Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StoreLogoWidget(
                    size: 48,
                    borderRadius: 12,
                    fallback: Image.asset(
                      'assets/images/logo.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryGreen, AppTheme.primaryBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'QuickBill POS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'WINDOWS DESKTOP EDITION',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white60,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Main Connection Card
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: _buildQrView(),
                ),
              ),

              const SizedBox(height: 32),

              // Steps Helper
              _buildStep('1', 'Open QuickBill on your phone and go to Settings > Link Desktop'),
              const SizedBox(height: 10),
              _buildStep('2', 'Point your camera at this screen to scan the QR code'),
              const SizedBox(height: 10),
              _buildStep('3', 'Select cashier & enter your 4-digit PIN to start billing!'),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualLoginDialog() {
    _actionError = null;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            _dialogSetState = setDialogState;
            return Dialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white12),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.vpn_key_rounded, color: AppTheme.primaryGreen, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Manual Link & Test Mode',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white60),
                            onPressed: () {
                              _dialogSetState = null;
                              Navigator.of(dialogCtx).pop();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: _buildCodeEntryView(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _dialogSetState = null;
    });
  }

  Widget _buildQrView() {
    return Column(
      children: [
        Text(
          'Scan to link your shop',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Open QuickBill on your phone → Settings → Open on PC',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // QR Code Container - Always rendered immediately
        if (_sessionId != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: 'quickbill://link?session=$_sessionId',
              version: QrVersions.auto,
              size: 200,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0F172A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Color(0xFF0F172A),
              ),
            ),
          )
        else
          SizedBox(
            width: 220,
            height: 220,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.lerp(AppTheme.primaryGreen, AppTheme.primaryBlue, _pulseController.value)!,
                  ),
                ),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Pairing Code Box
        if (_pairingCode != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pin_rounded, color: AppTheme.primaryGreen, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Pairing Code: ',
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
                ),
                Text(
                  '${_pairingCode!.substring(0, 3)} ${_pairingCode!.substring(3)}',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Copy Code',
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white70),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _pairingCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pairing code copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Sync Status Pill (Only shown if cloud sync pending/offline, does not hide QR)
        if (_syncStatus != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _syncStatus!,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade200),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _createSession,
                  child: const Icon(Icons.refresh_rounded, color: Colors.amber, size: 16),
                ),
              ],
            ),
          ),
        ],

        // Countdown Bar
        if (_sessionId != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _countdown / 90,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                _countdown > 25 ? AppTheme.primaryGreen : Colors.orange,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'QR refreshes in ${_countdown.toInt()}s',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          ),
        ],

        const SizedBox(height: 16),

        // Action Buttons Row
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _linkWithCode('TEST'),
              icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.black87),
              label: Text(
                'Open Instant Demo / Test Shop',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _showManualLoginDialog,
              icon: const Icon(Icons.keyboard_rounded, size: 16, color: Colors.white70),
              label: Text(
                'Enter Code / Login',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCodeEntryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. One-Click Instant Test Mode (Special for Windows Testing)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF10B981).withValues(alpha: 0.15),
                const Color(0xFF0284C7).withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instant Test Account',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Instant join for Windows test version',
                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Pre-loaded with sample products, categories, and cashier logins. Zero phone or QR scan needed.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isActionLoading ? null : () => _linkWithCode('TEST'),
                  icon: _isActionLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    _isActionLoading ? 'Connecting...' : 'Launch Test Account (Instant)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Divider
        Row(
          children: [
            const Expanded(child: Divider(color: Colors.white12)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR ENTER ACCOUNT CODE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Colors.white12)),
          ],
        ),

        const SizedBox(height: 16),

        // Error message if any
        if (_actionError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _actionError!,
                    style: GoogleFonts.inter(color: Colors.red.shade200, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Manual Code Input
        Text(
          'Shop Code, Staff Code, or TEST',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. 999999, TEST, or Shop UID',
                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                  prefixIcon: const Icon(Icons.pin_rounded, color: Colors.white38, size: 18),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen),
                  ),
                ),
                onSubmitted: (val) => _linkWithCode(val),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isActionLoading ? null : () => _linkWithCode(_codeController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Join'),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Store Owner Account Login (Email & Password)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _isOwnerLoginExpanded,
              onExpansionChanged: (exp) => setState(() => _isOwnerLoginExpanded = exp),
              leading: const Icon(Icons.store_rounded, color: Colors.white60, size: 20),
              title: Text(
                'Store Owner Login (Email & Password)',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Owner Email',
                    hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38, size: 18),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white38, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: Colors.white38,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                  ),
                  onSubmitted: (_) => _signInWithEmailPassword(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isActionLoading ? null : _signInWithEmailPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      _isActionLoading ? 'Signing in...' : 'Sign In as Owner',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(text, style: GoogleFonts.inter(fontSize: 13, color: Colors.white60)),
        ),
      ],
    );
  }
}
