import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global state provider for desktop sidebar collapsed (icon-only) vs sized-up (expanded)
final desktopSidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Global state provider for desktop sidebar width in pixels
final desktopSidebarWidthProvider = StateProvider<double>((ref) => 240.0);

/// Global state provider for the active desktop view index (0=POS, 1=Dashboard, 2=Inventory, etc.)
final desktopNavIndexProvider = StateProvider<int>((ref) => 0);
