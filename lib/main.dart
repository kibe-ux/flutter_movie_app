import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/premium_service.dart';
import 'widgets/auth_wrapper.dart';
import 'screens/movie_download_shell_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/watch_history_screen.dart';
import 'screens/downloaded_movies_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    // If this prints, Firebase is not configured for the current platform.
    // See lib/firebase_options.dart for instructions.
    debugPrint('⚠️  Firebase initialization failed: $e');
  }

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  runApp(const MovieDownloadApp());
}

class MovieDownloadApp extends StatelessWidget {
  const MovieDownloadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => PremiumService()),
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
        home: const AuthWrapper(
          child: MovieDownloadShellScreen(),
        ),
        routes: {
          '/favorites': (context) => const FavoritesScreen(),
          '/downloads': (context) => const DownloadedMoviesScreen(),
          '/watch-history': (context) => const WatchHistoryScreen(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}
