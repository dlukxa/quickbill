import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';

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
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    // Parse quickbill://link?session={sessionId}
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'quickbill' ||
        uri.host != 'link' ||
        uri.queryParameters['session'] == null) {
      setState(() => _error = 'Invalid QR code. Please scan the QuickBill PC QR.');
      return;
    }

    final sessionId = uri.queryParameters['session']!;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Get the owner's shopUid from SharedPreferences (set during login)
      final prefs = await SharedPreferences.getInstance();
      final shopUid = prefs.getString('active_shop_uid') ??
          FirebaseAuth.instance.currentUser?.uid;
      if (shopUid == null) throw Exception('Not logged in');

      await FirebaseFirestore.instance
          .collection('pc_sessions')
          .doc(sessionId)
          .update({
        'status': 'authenticated',
        'shopUid': shopUid,
        'linkedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isDone = true;
        _isProcessing = false;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
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
                    else if (_error != null)
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
                      )
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

    try {
      final prefs = await SharedPreferences.getInstance();
      final shopUid = prefs.getString('active_shop_uid') ??
          FirebaseAuth.instance.currentUser?.uid;
      if (shopUid == null) throw Exception('Not logged in on mobile');

      final query = await FirebaseFirestore.instance
          .collection('pc_sessions')
          .where('pairingCode', isEqualTo: code)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('Pairing code not found or expired.');
      }

      final docId = query.docs.first.id;
      await FirebaseFirestore.instance
          .collection('pc_sessions')
          .doc(docId)
          .update({
        'status': 'authenticated',
        'shopUid': shopUid,
        'linkedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isDone = true;
        _isProcessing = false;
      });

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isProcessing = false;
      });
    }
  }
}
