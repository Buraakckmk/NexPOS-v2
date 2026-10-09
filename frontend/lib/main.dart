import "dart:async";
import "dart:io";
import "dart:ui";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:sqflite_common_ffi/sqflite_ffi.dart";

import "core/constants/api_constants.dart";
import "providers/auth_provider.dart";
import "providers/stats_provider.dart";
import "screens/login_screen.dart";
import "services/app_feedback_service.dart";
import "services/api_client.dart";
import "services/auth_service.dart";
import "services/local_error_log_service.dart";
import "services/sync_service.dart";
import "services/socket_service.dart";
import "theme/app_theme.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    await ApiConstants.init();
  } catch (e) {
    debugPrint("Error initializing ApiConstants: $e");
  }

  ApiClient.configureBaseUrl();

  // Sync ve Socket servisleri arka planda başlat (UI'yi bloke etme)
  final syncService = SyncService();
  syncService.start();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LocalErrorLogService.instance.log(
      source: "flutter_error",
      message: details.exceptionAsString(),
      details: details.context?.toDescription(),
      stackTrace: details.stack,
    );
  };

  ErrorWidget.builder = (details) => Material(
    color: AppTheme.bg,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Color(0xFFFCA5A5),
            ),
            SizedBox(height: 12),
            Text(
              "Bir ekran hatası oluştu.",
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              "Lütfen bu sayfayı yeniden açın veya işlemi tekrar deneyin.",
              style: TextStyle(color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("[platform-error] $error\n$stack");
    LocalErrorLogService.instance.log(
      source: "platform_dispatcher",
      message: error.toString(),
      stackTrace: stack,
    );
    return true;
  };

  runZonedGuarded(
    () {
      // Socket bağlantısını arka planda başlat (app açıldıktan sonra)
      Future.microtask(() => _initializeSocket());

      runApp(const PosApp());
    },
    (error, stack) {
      debugPrint("[zone-error] $error\n$stack");
      LocalErrorLogService.instance.log(
        source: "run_zoned_guarded",
        message: error.toString(),
        stackTrace: stack,
      );
    },
  );
}

/// Socket bağlantısını arka planda başlat (timeout ile)
Future<void> _initializeSocket() async {
  try {
    debugPrint("Socket connection starting...");
    final socketService = SocketService();

    // Timeout ile socket bağlantısını başlat (non-blocking)
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        socketService.connect();
        debugPrint("Socket connection initiated");
      } catch (e) {
        debugPrint("Socket connect error in microtask: $e");
      }
    });
  } catch (e) {
    debugPrint("Error in _initializeSocket: $e");
  }
}

/// Dokunmatik ekranlarda (Windows POS vb.) parmakla kaydırmayı (swipe) etkinleştiren davranış.
class PosScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthService())),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
      ],
      child: MaterialApp(
        navigatorKey: AppFeedbackService.navigatorKey,
        scaffoldMessengerKey: AppFeedbackService.scaffoldMessengerKey,
        title: "NEXPOS",
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        scrollBehavior: PosScrollBehavior(),
        home: const LoginScreen(),
      ),
    );
  }
}
