import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';

enum PcLinkingErrorType {
  invalidQr,
  notAuthenticated,
  authRequired,
  sessionNotFound,
  sessionExpired,
  alreadyLinked,
  networkError,
  unknown,
}

class PcLinkingException implements Exception {
  final PcLinkingErrorType type;
  final String message;
  const PcLinkingException(this.type, this.message);

  @override
  String toString() => message;
}

void _logPcLink(String message) {
  debugPrint('🔗 [PC_LINK] $message');
}

/// Mobile screen that scans the PC's QR code and authenticates the session.
/// Owner opens QuickBill → Settings → "Open on PC" → scans the QR shown on the PC.
class LinkToPcScreen extends ConsumerStatefulWidget {
  const LinkToPcScreen({super.key});

  @override
  ConsumerState<LinkToPcScreen> createState() => _LinkToPcScreenState();
}

class _LinkToPcScreenState extends ConsumerState<LinkToPcScreen> {
  bool _isProcessing = false;
  bool _isDone = false;
  String? _error;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _isDone) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    _logPcLink('QR code detected (length=${raw.length})');

    // Parse quickbill://link?session={sessionId}
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'quickbill' ||
        uri.host != 'link' ||
        uri.queryParameters['session'] == null) {
      _logPcLink('Invalid QR URI format: $raw');
      setState(() => _error = 'Invalid QR code. Please scan the QuickBill PC QR.');
      return;
    }

    final sessionId = uri.queryParameters['session']!.trim();
    if (sessionId.isEmpty) {
      _logPcLink('QR code has empty session parameter');
      setState(() => _error = 'Invalid QR code. Missing session ID.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final activeShopUid = prefs.getString('active_shop_uid');
      final shopUid = (activeShopUid != null && activeShopUid.isNotEmpty)
          ? activeShopUid
          : authUser?.uid;

      _logPcLink('Authenticated UID: ${authUser?.uid ?? "none"}');
      _logPcLink('Business/Shop ID: ${shopUid ?? "none"}');
      _logPcLink('Pairing Session ID: $sessionId');
      _logPcLink('Exact Firestore Path: pc_sessions/$sessionId');

      if (shopUid == null || shopUid.isEmpty) {
        throw const PcLinkingException(
          PcLinkingErrorType.notAuthenticated,
          'You are not signed in to a shop on this mobile device. Please sign in first.',
        );
      }

      final sessionRef = FirebaseFirestore.instance.collection('pc_sessions').doc(sessionId);

      // Atomic transaction: verify existence, check expiration, and update status
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(sessionRef);
        final exists = snapshot.exists;
        _logPcLink('Document Exists: $exists');

        if (!exists) {
          throw const PcLinkingException(
            PcLinkingErrorType.sessionNotFound,
            'PC pairing session was not found. Please refresh the QR code on your PC screen and scan again.',
          );
        }

        final data = snapshot.data();
        if (data == null) {
          throw const PcLinkingException(
            PcLinkingErrorType.sessionNotFound,
            'Corrupted session data. Please refresh the QR code on your PC.',
          );
        }

        // Check if session has expired (TTL)
        final expiresAtRaw = data['expiresAt'];
        if (expiresAtRaw != null) {
          DateTime? expiresAt;
          if (expiresAtRaw is Timestamp) {
            expiresAt = expiresAtRaw.toDate();
          } else if (expiresAtRaw is String) {
            expiresAt = DateTime.tryParse(expiresAtRaw);
          }
          if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
            _logPcLink('Session expired at $expiresAt (current: ${DateTime.now()})');
            throw const PcLinkingException(
              PcLinkingErrorType.sessionExpired,
              'This PC pairing session has expired. Please refresh the QR code on your PC screen.',
            );
          }
        }

        // Check current status
        final status = data['status'] as String?;
        if (status == 'authenticated') {
          _logPcLink('Session is already authenticated');
          throw const PcLinkingException(
            PcLinkingErrorType.alreadyLinked,
            'This PC is already linked to a shop.',
          );
        }

        _logPcLink('Writing authenticated state to pc_sessions/$sessionId with shopUid: $shopUid');
        transaction.update(sessionRef, {
          'status': 'authenticated',
          'shopUid': shopUid,
          'linkedAt': FieldValue.serverTimestamp(),
          'linkedByUid': authUser?.uid,
        });
      });

      _logPcLink('PC linking transaction succeeded for session: $sessionId');

      setState(() {
        _isDone = true;
        _isProcessing = false;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } on PcLinkingException catch (e) {
      _logPcLink('Operation failed (PcLinkingException): ${e.type} - ${e.message}');
      setState(() {
        _error = e.message;
        _isProcessing = false;
      });
    } on FirebaseException catch (e) {
      _logPcLink('Operation failed (FirebaseException): code=${e.code}, message=${e.message}');
      String userMessage;
      if (e.code == 'not-found') {
        userMessage = 'PC pairing session was not found. Please refresh the QR code on your PC screen.';
      } else if (e.code == 'permission-denied') {
        userMessage = 'Permission denied. Please ensure you are logged in as an authorized store user.';
      } else if (e.code == 'unavailable') {
        userMessage = 'Cloud service is currently unreachable. Please check your internet connection.';
      } else {
        userMessage = 'Failed to link PC: ${e.message ?? e.code}';
      }
      setState(() {
        _error = userMessage;
        _isProcessing = false;
      });
    } catch (e) {
      _logPcLink('Operation failed (Unexpected): $e');
      setState(() {
        _error = 'Failed to link PC: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Link to PC',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Camera viewfinder
          if (!_isDone)
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),

          // Success overlay
          if (_isDone)
            Container(
              color: const Color(0xFF0F172A),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryGreen,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppTheme.primaryGreen,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'PC Linked!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Windows PC is now connected.',
                      style: GoogleFonts.inter(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),

          // Scan overlay frame
          if (!_isDone)
            Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryGreen, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

          // Bottom instructions / status
          if (!_isDone)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isProcessing)
                      const CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      )
                    else if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _isProcessing = false;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ]
                    else ...[
                      Text(
                        'Point your camera at the QR code\nshown on your Windows PC',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showManualCodeDialog,
                        icon: const Icon(Icons.keyboard_rounded, color: AppTheme.primaryGreen, size: 16),
                        label: const Text(
                          'Enter 6-digit PC Code instead',
                          style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showManualCodeDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Enter PC Pairing Code',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 6-digit code shown below the QR on your PC screen.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: 20,
                letterSpacing: 6,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _linkWithPairingCode(codeCtrl.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Link PC'),
          ),
        ],
      ),
    );
  }

  Future<void> _linkWithPairingCode(String rawCode) async {
    final code = rawCode.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length != 6) {
      setState(() => _error = 'Please enter a valid 6-digit code.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    _logPcLink('Attempting to link PC with 6-digit code: [REDACTED]');

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final shopUid = prefs.getString('active_shop_uid') ?? authUser?.uid;

      _logPcLink('Auth Check - Current User: ${authUser?.uid}, Active Shop UID: $shopUid');

      if (shopUid == null || shopUid.isEmpty) {
        throw const PcLinkingException(
          PcLinkingErrorType.authRequired,
          'You must be logged in to QuickBill on this phone to link a PC.',
        );
      }

      _logPcLink('Querying pc_sessions for pending code...');
      final query = await FirebaseFirestore.instance
          .collection('pc_sessions')
          .where('pairingCode', isEqualTo: code)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _logPcLink('No pending document found for pairing code');
        throw const PcLinkingException(
          PcLinkingErrorType.sessionNotFound,
          'Pairing code was not found or has expired. Please refresh the code on your PC screen.',
        );
      }

      final docId = query.docs.first.id;
      final sessionRef = FirebaseFirestore.instance.collection('pc_sessions').doc(docId);
      _logPcLink('Found document $docId. Running atomic transaction to verify & update...');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(sessionRef);
        final exists = snapshot.exists;
        _logPcLink('Transaction get for $docId - exists: $exists');

        if (!exists) {
          throw const PcLinkingException(
            PcLinkingErrorType.sessionNotFound,
            'Pairing session was not found. Please refresh the code on your PC screen.',
          );
        }

        final data = snapshot.data();
        if (data == null) {
          throw const PcLinkingException(
            PcLinkingErrorType.sessionNotFound,
            'Corrupted session data. Please refresh the code on your PC.',
          );
        }

        // Check TTL expiration
        final expiresAtRaw = data['expiresAt'];
        if (expiresAtRaw != null) {
          DateTime? expiresAt;
          if (expiresAtRaw is Timestamp) {
            expiresAt = expiresAtRaw.toDate();
          } else if (expiresAtRaw is String) {
            expiresAt = DateTime.tryParse(expiresAtRaw);
          }
          if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
            _logPcLink('Session $docId expired at $expiresAt');
            throw const PcLinkingException(
              PcLinkingErrorType.sessionExpired,
              'This pairing code has expired. Please refresh the code on your PC screen.',
            );
          }
        }

        // Check if already authenticated
        final status = data['status'] as String?;
        if (status == 'authenticated') {
          _logPcLink('Session $docId is already authenticated');
          throw const PcLinkingException(
            PcLinkingErrorType.alreadyLinked,
            'This PC is already linked to a shop.',
          );
        }

        _logPcLink('Writing authenticated state to pc_sessions/$docId with shopUid: $shopUid');
        transaction.update(sessionRef, {
          'status': 'authenticated',
          'shopUid': shopUid,
          'linkedAt': FieldValue.serverTimestamp(),
          'linkedByUid': authUser?.uid,
        });
      });

      _logPcLink('PC linking transaction succeeded for session: $docId');

      setState(() {
        _isDone = true;
        _isProcessing = false;
      });

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } on PcLinkingException catch (e) {
      _logPcLink('Code link failed (PcLinkingException): ${e.type} - ${e.message}');
      setState(() {
        _error = e.message;
        _isProcessing = false;
      });
    } on FirebaseException catch (e) {
      _logPcLink('Code link failed (FirebaseException): code=${e.code}, message=${e.message}');
      String userMessage;
      if (e.code == 'not-found') {
        userMessage = 'Pairing code was not found. Please refresh the code on your PC screen.';
      } else if (e.code == 'permission-denied') {
        userMessage = 'Permission denied. Please ensure you are logged in as an authorized store user.';
      } else if (e.code == 'unavailable') {
        userMessage = 'Cloud service is currently unreachable. Please check your internet connection.';
      } else {
        userMessage = 'Failed to link PC: ${e.message ?? e.code}';
      }
      setState(() {
        _error = userMessage;
        _isProcessing = false;
      });
    } catch (e) {
      _logPcLink('Code link failed (Unexpected): $e');
      setState(() {
        _error = 'Failed to link PC: $e';
        _isProcessing = false;
      });
    }
  }
}
