import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'providers/channel_provider.dart';
import 'services/channel_service.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';

Future<void> _writeCrashLog(String error) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/crash_log.txt');
    final timestamp = DateTime.now().toString();
    final content = '$timestamp\n$error\n\n---\n';
    
    if (await file.exists()) {
      await file.writeAsString(content, mode: FileMode.append);
    } else {
      await file.writeAsString(content);
    }
    debugPrint('✅ Crash log saved: ${file.path}');
  } catch (e) {
    debugPrint('❌ Failed to write crash log: $e');
  }
}

void main() async {
  // Global error handler for Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔴 Flutter Error: ${details.exceptionAsString()}');
    debugPrint('Stack: ${details.stack}');
    _writeCrashLog(
      'FLUTTER ERROR\n${details.exceptionAsString()}\nSTACK:\n${details.stack}',
    );
  };

  // Global error handler for uncaught async errors
  runZonedGuarded(
    () async {
      try {
        // Initialize Flutter bindings
        WidgetsFlutterBinding.ensureInitialized();
        
        // Lock orientation
        try {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        } catch (e) {
          debugPrint('⚠️ Orientation lock failed: $e');
          _writeCrashLog('Orientation lock error: $e');
        }

        // Initialize Hive with error handling
        try {
          debugPrint('📦 Initializing Hive...');
          await Hive.initFlutter();
          debugPrint('✅ Hive initialized successfully');
          
          // Initialize ChannelService after Hive
          await ChannelService.initHive();
          debugPrint('✅ ChannelService initialized');
        } catch (e) {
          debugPrint('❌ Hive initialization failed: $e');
          _writeCrashLog('Hive init error: $e\nStack: ${StackTrace.current}');
          rethrow;
        }

        // Run the app
        debugPrint('🚀 Starting AngoMovieApp...');
        runApp(const AngoMovieApp());
      } catch (e, stack) {
        debugPrint('🔴 Main initialization error: $e');
        debugPrint('Stack: $stack');
        _writeCrashLog('MAIN INIT ERROR\n$e\nSTACK:\n$stack');
        rethrow;
      }
    },
    (error, stack) {
      debugPrint('🔴 Uncaught error in zone: $error');
      debugPrint('Stack: $stack');
      _writeCrashLog('ZONE ERROR\n$error\nSTACK:\n$stack');
    },
  );
}

class AngoMovieApp extends StatelessWidget {
  const AngoMovieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChannelProvider()),
      ],
      child: MaterialApp(
        title: 'AngoMovie IPTV',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
        builder: (context, child) {
          // Global error widget builder
          return _ErrorBoundary(child: child!);
        },
      ),
    );
  }
}

class _ErrorBoundary extends StatefulWidget {
  final Widget child;

  const _ErrorBoundary({required this.child});

  @override
  State<_ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<_ErrorBoundary> {
  String? _errorMessage;

  @override
  void didUpdateWidget(_ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() => _errorMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Erro ao carregar aplicativo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _errorMessage = null),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar Novamente'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Verifique: /data/data/com.angomovie.angomovie_iptv/app_flutter/crash_log.txt',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
