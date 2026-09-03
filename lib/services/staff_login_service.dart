import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee.dart';

class StaffLoginService {
  static final StaffLoginService instance = StaffLoginService._init();
  StaffLoginService._init();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a 6-digit numeric code and store the handshake in Firestore
  Future<String> generateLoginCode(Employee employee, String ownerUid, String ownerEmail, String ownerPassword) async {
    final code = _generateRandomCode();
    final expiry = DateTime.now().add(const Duration(minutes: 10));

    await _firestore.collection('temp_logins').doc(code).set({
      'employee_id': employee.id,
      'employee_name': employee.name,
      'owner_uid': ownerUid,
      'owner_email': ownerEmail,
      'owner_password': ownerPassword, // Encrypted/hashed in a real app, but here we use it for the handshake
      'expires_at': Timestamp.fromDate(expiry),
      'used': false,
    });

    return code;
  }

  /// Validate a code and return the credentials if successful
  Future<Map<String, dynamic>?> validateLoginCode(String rawCode) async {
    final code = rawCode.trim();
    try {
      final docRef = _firestore.collection('temp_logins').doc(code);
      final doc = await docRef.get(const GetOptions(source: Source.serverAndCache));

      if (!doc.exists) {
        print('STAFF_LOGIN_DEBUG: Code $code does not exist in Firestore.');
        return null;
      }

      final data = doc.data()!;
      final expiry = (data['expires_at'] as Timestamp).toDate();
      final used = data['used'] as bool? ?? false;
      final now = DateTime.now();

      print('STAFF_LOGIN_DEBUG: Code $code found. Expiry: $expiry (Now: $now). Used: $used');

      if (now.isAfter(expiry) || used) {
        print('STAFF_LOGIN_DEBUG: Code $code is either expired or used. Deleting...');
        // Clean up expired or used codes
        await docRef.delete();
        return null;
      }

      // Mark as used immediately to prevent reuse
      await docRef.update({'used': true});


    return {
      'owner_uid': data['owner_uid'],
      'email': data['owner_email'],
      'password': data['owner_password'],
      'employee_id': data['employee_id'],
    };
    } catch (e) {
      print('STAFF_LOGIN_DEBUG: Exception checking code: $e');
      rethrow;
    }
  }

  String _generateRandomCode() {
    final rnd = Random();
    return (100000 + rnd.nextInt(900000)).toString();
  }
  
  /// Helper to clean up the document after successful sign-in
  Future<void> deleteCode(String code) async {
    await _firestore.collection('temp_logins').doc(code).delete();
  }
}
