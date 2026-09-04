import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'config/theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/auth_service.dart';
import 'providers/preference_provider.dart';
import 'providers/employee_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_wrapper.dart';
import 'services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/gradient_button.dart';
import 'screens/startup/startup_loading_screen.dart';
import 'screens/startup/language_selection_screen.dart';
import 'utils/fallback_localizations.dart';
import 'screens/desktop/desktop_wrapper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'dart:ffi';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    if (Platform.isWindows) {
      try {
        open.overrideFor(OperatingSystem.windows, () {
          final exeDir = File(Platform.resolvedExecutable).parent.path;
          final localDll = File('$exeDir\\sqlite3.dll');
          if (localDll.existsSync()) {
            return DynamicLibrary.open(localDll.path);
          }
          return DynamicLibrary.open('sqlite3.dll');
        });
      } catch (e) {
        debugPrint('⚠️ open.overrideFor notice: $e');
      }
    }
    databaseFactory = databaseFactoryFfi;
    try {
      sqfliteFfiInit();
    } catch (e, stack) {
      debugPrint('⚠️ sqfliteFfiInit initialization notice: $e\n$stack');
    }
  }

    // ZEN ERROR SHIELD - Replaces the 'Red Screen' globally with our premium design
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('GLOBAL APP ERROR: ${details.exception}');
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.transparent,
          child: Container(
            color: const Color(0xFFF1F5F9), // Light background
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), // AppTheme.primaryGreen 
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 64),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Smoothing Things Out',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'A small technical hurdle occurred. We\'re working to make it perfect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    };

  runApp(
    RestartWidget(
      child: const ProviderScope(
        child: QuickBillLoaderApp(),
      ),
    ),
  );
}

/// A wrapper widget that allows programmatic restarting of the entire app.
/// It works by providing a new UniqueKey to its child, forcing a complete rebuild
/// from the root, effectively wiping out all State and ProviderScope instances.
class RestartWidget extends StatefulWidget {
  final Widget child;

  const RestartWidget({super.key, required this.child});

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}

class QuickBillLoaderApp extends StatefulWidget {
  const QuickBillLoaderApp({super.key});

  @override
  State<QuickBillLoaderApp> createState() => _QuickBillLoaderAppState();
}

class _QuickBillLoaderAppState extends State<QuickBillLoaderApp> {
  bool _isInitialized = false;

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        title: 'QuickBill POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: StartupLoadingScreen(
          onInitializationComplete: () {
            setState(() {
              _isInitialized = true;
            });
          },
        ),
      );
    }

    return const QuickBillApp();
  }
}

class QuickBillApp extends ConsumerWidget {
  const QuickBillApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authStateProvider);
    final isDark = settings.isDarkMode;

    // ─── Windows / macOS Desktop ─────────────────────────────────────────────
    if (Platform.isWindows || Platform.isMacOS) {
      return MaterialApp(
        title: 'QuickBill POS — Desktop',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FallbackMaterialLocalizationDelegate(),
          FallbackCupertinoLocalizationDelegate(),
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'), // English
          Locale('si'), // Sinhala
          Locale('ta'), // Tamil
          Locale('hi'), // Hindi (India)
          Locale('bn'), // Bengali (Bangladesh)
          Locale('dv'), // Dhivehi (Maldives)
        ],
        locale: Locale(settings.languageCode),
        home: const DesktopWrapper(),
      );
    }

    // ─── Mobile / Other Platforms ─────────────────────────────────────────────
    return MaterialApp(
      title: 'QuickBill POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: (authState.value == null)
          ? ThemeMode.light
          : (isDark ? ThemeMode.dark : ThemeMode.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('si'), // Sinhala
        Locale('ta'), // Tamil
        Locale('hi'), // Hindi (India)
        Locale('bn'), // Bengali (Bangladesh)
        Locale('dv'), // Dhivehi (Maldives)
      ],
      locale: Locale(settings.languageCode),
      home: settings.hasSelectedLanguage ? const AuthWrapper() : const LanguageSelectionScreen(),
      onUnknownRoute: (routeSettings) => MaterialPageRoute(
        builder: (_) => settings.hasSelectedLanguage ? const AuthWrapper() : const LanguageSelectionScreen(),
      ),
    );
  }
}
