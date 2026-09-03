import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/theme.dart';
import '../../services/staff_login_service.dart';

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
  String? _error;
  StreamSubscription<DocumentSnapshot>? _sessionSub;
  Timer? _refreshTimer;
  double _countdown = 90.0;
  Timer? _countdownTimer;
  late AnimationController _pulseController;

  // Tab & Code Input State
  int _selectedTab = 0; // 0: QR Scan, 1: Enter Code / Sign In
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isActionLoading = false;
  String? _actionError;
  bool _showPassword = false;
  bool _isOwnerLoginExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _createSession();
  }

  @override
  void dispose() {
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
    try {
      String sessionId;
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          sessionId = FirebaseAuth.instance.currentUser!.uid;
        } else {
          final userCred = await FirebaseAuth.instance.signInAnonymously();
          sessionId = userCred.user!.uid;
        }
      } catch (authError) {
        debugPrint('DesktopQrLinkScreen auth fallback: $authError');
        sessionId = 'pc_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch % 100000}';
      }

      // 6-digit numeric pairing code
      final pairingCode = (100000 + Random().nextInt(900000)).toString();

      // Write a pending session document
      await FirebaseFirestore.instance
          .collection('pc_sessions')
          .doc(sessionId)
          .set({
        'status': 'pending',
        'pairingCode': pairingCode,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(seconds: 100)).toIso8601String(),
      });

      if (!mounted) return;
      setState(() {
        _sessionId = sessionId;
        _pairingCode = pairingCode;
        _countdown = 90.0;
        _error = null;
      });

      // Listen for mobile to authenticate the session
      _sessionSub?.cancel();
      _sessionSub = FirebaseFirestore.instance
          .collection('pc_sessions')
          .doc(sessionId)
          .snapshots()
          .listen((snap) {
        if (!snap.exists) return;
        final data = snap.data()!;
        if (data['status'] == 'authenticated' && data['shopUid'] != null) {
          _sessionSub?.cancel();
          _refreshTimer?.cancel();
          _countdownTimer?.cancel();
          widget.onLinked(data['shopUid'] as String);
        }
      }, onError: (err) {
        if (!mounted) return;
        setState(() {
          _error = 'Connection lost: $err';
        });
      });

      // Auto-refresh QR after 90 seconds
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(seconds: 90), _createSession);

      // Countdown timer for UI
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _countdown -= 1;
          if (_countdown <= 0) _countdown = 0;
        });
      });
    } catch (e) {
      debugPrint('DesktopQrLinkScreen: error creating session: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _linkWithCode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) {
      setState(() => _actionError = 'Please enter a shop code, staff code, or TEST');
      return;
    }

    setState(() {
      _isActionLoading = true;
      _actionError = null;
    });

    try {
      // 1. Fast path for test/demo mode
      final upper = code.toUpperCase();
      if (upper == 'TEST' || upper == 'DEMO' || upper == 'TESTING' || code == '123456') {
        widget.onLinked(kDefaultTestShopUid);
        return;
      }

      // 2. 6-digit code validation (Staff code or PC pairing code)
      if (RegExp(r'^\d{6}$').hasMatch(code)) {
        // A. Staff handshake code check
        try {
          final credentials = await StaffLoginService.instance.validateLoginCode(code);
          if (credentials != null && credentials['owner_uid'] != null) {
            widget.onLinked(credentials['owner_uid'] as String);
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
              widget.onLinked(data['shopUid'] as String);
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
            widget.onLinked(code);
            return;
          }
        } catch (_) {
          // If offline or permission rules restrict direct doc get,
          // connect with the specified Shop UID directly
          widget.onLinked(code);
          return;
        }
      }

      throw Exception('Code "$code" not recognized. Use "TEST" for instant testing, a 6-digit staff code, or your Shop UID.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = e.toString().replaceAll('Exception: ', '');
        _isActionLoading = false;
      });
    }
  }

  Future<void> _signInWithEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _actionError = 'Please enter both email and password');
      return;
    }

    setState(() {
      _isActionLoading = true;
      _actionError = null;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        widget.onLinked(cred.user!.uid);
      } else {
        throw Exception('Authentication failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
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
                  child: Column(
                    children: [
                      // Tab Segmented Switcher
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabButton(
                                index: 0,
                                icon: Icons.qr_code_rounded,
                                label: 'Scan QR Code',
                              ),
                            ),
                            Expanded(
                              child: _buildTabButton(
                                index: 1,
                                icon: Icons.vpn_key_rounded,
                                label: 'Enter Code / Test',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // TAB 0: QR Scan View
                      if (_selectedTab == 0) _buildQrView(),

                      // TAB 1: Code / Test Mode / Login View
                      if (_selectedTab == 1) _buildCodeEntryView(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Steps Helper
              _buildStep('1', 'Scan QR with phone OR enter code above'),
              const SizedBox(height: 10),
              _buildStep('2', 'Select cashier & enter your 4-digit PIN'),
              const SizedBox(height: 10),
              _buildStep('3', 'Ready to bill on Windows Desktop!'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _actionError = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
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

        // QR Code Container
        if (_sessionId != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
        else if (_error != null)
          Container(
            width: 220,
            height: 220,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.red.shade300, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _createSession,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text('Retry', style: GoogleFonts.inter(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
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
          const SizedBox(height: 14),
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
        TextButton.icon(
          onPressed: () => setState(() => _selectedTab = 1),
          icon: const Icon(Icons.keyboard_rounded, size: 16, color: AppTheme.primaryGreen),
          label: Text(
            'No phone camera? Enter code or test mode →',
            style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontSize: 13),
          ),
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
                  hintText: 'e.g. iiFadszr3lZYVMX61f7hbIB56492 or TEST',
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
        Text(text, style: GoogleFonts.inter(fontSize: 13, color: Colors.white60)),
      ],
    );
  }
}
