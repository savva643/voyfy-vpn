import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vpni/screens/splash_screen.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/servers_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/vpn_provider.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize API service
  await ApiService.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ru', 'RU')
      ],
      path: 'assets/translations',
      saveLocale: true,
      fallbackLocale: const Locale('en', 'US'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VpnProvider()),
        ChangeNotifierProvider(create: (_) => ServersProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            debugShowCheckedModeBanner: false,
            title: 'Voyfy VPN',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

/// App Initializer
/// Handles initialization of providers and navigation
class AppInitializer extends StatefulWidget {
  const AppInitializer({Key? key}) : super(key: key);

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;
  String _initStatus = 'Загрузка...';
  double _initProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize providers
    final authProvider = context.read<AuthProvider>();
    final vpnProvider = context.read<VpnProvider>();
    final serversProvider = context.read<ServersProvider>();
    final themeProvider = context.read<ThemeProvider>();

    // Initialize theme (fast)
    setState(() {
      _initStatus = 'Загрузка темы...';
      _initProgress = 0.1;
    });
    await themeProvider.initialize();

    // Initialize auth (check for existing session)
    setState(() {
      _initStatus = 'Проверка авторизации...';
      _initProgress = 0.3;
    });
    await authProvider.initialize();

    // Initialize VPN service (may take time on Windows for UAC)
    setState(() {
      _initStatus = 'Инициализация VPN сервиса...';
      _initProgress = 0.5;
    });
    await vpnProvider.initialize();

    // Load servers if authenticated
    if (authProvider.isAuthenticated) {
      setState(() {
        _initStatus = 'Загрузка серверов...';
        _initProgress = 0.8;
      });
      await serversProvider.fetchServers();
    }

    setState(() {
      _initStatus = 'Готово!';
      _initProgress = 1.0;
    });

    // Small delay to show "Ready" state
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreenWithProgress(
          status: _initStatus,
          progress: _initProgress,
        ),
      );
    }

    // Navigate based on auth state
    final authProvider = context.watch<AuthProvider>();

    // Return splash screen which handles navigation
    return const SplashScreen();
  }
}

/// Splash screen with initialization progress
class SplashScreenWithProgress extends StatelessWidget {
  final String status;
  final double progress;

  const SplashScreenWithProgress({
    Key? key,
    required this.status,
    required this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0B1220) : Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [const Color(0xFF0B1220), const Color(0xFF1A1A2E)]
                : [Colors.white, const Color(0xFFF8F9FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0038FF).withOpacity(isDarkMode ? 0.4 : 0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Brand Name
                Text(
                  'Voyfy VPN',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 48),
                // Progress indicator
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDarkMode ? Colors.white24 : Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0038FF)),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // Status text
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

