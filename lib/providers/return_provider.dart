import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/return_service.dart';

final returnServiceProvider = Provider<ReturnService>((ref) {
  return ReturnService();
});
