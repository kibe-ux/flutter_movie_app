import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/rewards_service.dart';
import 'services/ad_service.dart';
import 'services/crash_reporting_service.dart';
import 'services/home_startup_service.dart';
import 'screens/logo_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/watch_history_screen.dart';
import 'screens/downloaded_movies_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/my_list_screen.dart';
import 'utils/my_list.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MovieDownloadApp(initialize: _initializeApp));
}

Future<void> _initializeApp() async {
  // MyList uses FirebaseAuth, so Firebase must exist before MyList starts.
  // Running them together caused MyList to occasionally access FirebaseAuth
  // before the default Firebase app had been created.
  await _initializeFirebase();
  await CrashReportingService.initialize();
  try {
    await Future.wait([
      _loadEnvironment(),
      MyList().init(),
    ]);
  } catch (error, stack) {
    await CrashReportingService.recordError(error, stack,
        reason: 'App initialization failed');
    rethrow;
  }

  // Initialize Ads and preload first interstitial
  unawaited(
      AdService().init().catchError((Object error, StackTrace stack) async {
    debugPrint('Ads initialization failed: $error');
    await CrashReportingService.recordError(error, stack,
        reason: 'Ads initialization failed');
  }));
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    rethrow;
  }
}

Future<void> _loadEnvironment() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }
}

class MovieDownloadApp extends StatelessWidget {
  const MovieDownloadApp({super.key, this.initialize});

  final Future<void> Function()? initialize;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, RewardsService>(
          create: (_) => RewardsService(),
          update: (_, auth, rewards) => rewards!
            ..setUser(
              auth.currentUser?.isAnonymous == true
                  ? null
                  : auth.currentUser?.uid,
            ),
        ),
      ],
      child: MaterialApp(
        title: 'Movie Download App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0A0A),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00D4FF),
            brightness: Brightness.dark,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0A0A0A),
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            iconTheme: IconThemeData(color: Colors.white),
          ),
        ),
        home: LogoScreen(
            initialize: initialize, startupService: HomeStartupService()),
        routes: {
          '/favorites': (context) => const FavoritesScreen(),
          '/downloads': (context) => const DownloadedMoviesScreen(),
          '/watch-history': (context) => const WatchHistoryScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/my-list': (context) => const MyListScreen(),
        },
      ),
    );
  }
}
