// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gestion_courses/screens/login_screen.dart';
import 'package:gestion_courses/screens/home_screen.dart';
import 'package:gestion_courses/screens/profile_screen.dart';
import 'package:gestion_courses/screens/splash_screen.dart'; // NOUVEAU fichier
import 'package:gestion_courses/services/auth_service.dart';
import 'package:gestion_courses/models/user_model.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(), lazy: false),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Courses', // GARDE ce nom
      theme: ThemeData(
        primaryColor: const Color(0xFF0F9E99),
        scaffoldBackgroundColor: const Color(0xFFEFE9E0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F9E99),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF0F9E99),
          unselectedItemColor: Colors.grey,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {'/profile': (context) => const ProfileScreen()},
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialized = false;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Affiche le splash pendant au moins 2 secondes
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<UserModel?>(
      stream: authService.user,
      builder: (context, snapshot) {
        // Si on doit encore montrer le splash OU si Firebase charge
        if (_showSplash ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreenV2();
        }

        if (authService.currentUser != null) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
// SUPPRIME cette ancienne classe SplashScreen qui était ici
// Elle est maintenant dans screens/splash_screen.dart