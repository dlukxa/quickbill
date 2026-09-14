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
import 'services/startup_logger.dart';
import 'widgets/developer_diagnostic_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'dart:ffi';

void _logErrorToFile(dynamic error, dynamic stack) {
  StartupLogger.logError('Runtime', error, stack is StackTrace ? stack : null);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupLogger.log('QuickBill POS engine entry: main() initialized');

  // Protect against fatal crashes from uncaught errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    StartupLogger.logError('FlutterRuntime', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    StartupLogger.logError('UncaughtAsync', error, stack);
    return true; // Prevents process termination
  };

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    if (Platform.isWindows) {
      try {
        open.overrideFor(OperatingSystem.windows, () {
          try {
            final exeDir = File(Platform.resolvedExecutable).parent.path;
            final localDll = File('$exeDir\\sqlite3.dll');
            if (localDll.existsSync()) {
              return DynamicLibrary.open(localDll.path);
            }
          } catch (e) {
            debugPrint('⚠️ Error opening local sqlite3.dll: $e');
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

    // ZEN ERROR SHIELD & DEVELOPER DIAGNOSTICS - Replaces the 'Red Screen' with technical details
    ErrorWidget.builder = (FlutterErrorDetails details) {
      StartupLogger.logError('WidgetBuild', details.exception, details.stack);
      return DeveloperDiagnosticScreen(details: details);
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
            StartupLogger.log('QuickBillLoaderApp: onInitializationComplete fired -> transitioning to QuickBillApp');
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

    // ─── Windows / macOS / Linux Desktop ─────────────────────────────────────
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      StartupLogger.log('QuickBillApp.build() -> Mounting DesktopWrapper');
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
