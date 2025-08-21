import 'package:flutter/material.dart';
import 'package:menstrual_health_ai/providers/auth_provider.dart';
import 'package:menstrual_health_ai/providers/theme_provider.dart';
import 'package:menstrual_health_ai/providers/user_data_provider.dart';
import 'package:menstrual_health_ai/screens/auth/login_screen.dart';
import 'package:menstrual_health_ai/screens/dashboard/bottom_nav.dart';
import 'package:menstrual_health_ai/screens/onboarding/onboarding_screens.dart';
import 'package:menstrual_health_ai/screens/onboarding/splash_screens.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Menstrual Health AI',
          theme: themeProvider.getTheme(),
          debugShowCheckedModeBanner: false,
          home: const AppInitializer(),
        );
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _hasCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Check if user has completed onboarding
      _hasCompletedOnboarding =
          prefs.getBool('hasCompletedOnboarding') ?? false;

      if (kDebugMode) {
        print('🚀 App Initialization:');
        print('  - hasCompletedOnboarding: $_hasCompletedOnboarding');
      }

      // Check authentication status - this will load from storage and validate
      final isAuthenticated = await authProvider.checkAuth();

      if (kDebugMode) {
        print('  - isAuthenticated: $isAuthenticated');
        print('  - currentUser: ${authProvider.currentUser?.name}');
        print('  - hasToken: ${authProvider.token != null}');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ App initialization error: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // If user is authenticated
        if (authProvider.isAuthenticated) {
          // If user has completed onboarding, go to dashboard
          if (_hasCompletedOnboarding) {
            return const BottomNav();
          } else {
            // If not completed onboarding, go to onboarding screens
            return const OnboardingScreens();
          }
        }

        // If not authenticated, show splash/login flow
        return const SplashScreens();
      },
    );
  }
}

//tanmoy@gmail.com
//Tanm0976   987507
