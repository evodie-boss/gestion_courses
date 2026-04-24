// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gestion_courses/screens/login_screen.dart';
import 'package:gestion_courses/screens/home_screen.dart';
import 'package:gestion_courses/screens/profile_screen.dart';
import 'package:gestion_courses/screens/splash_screen.dart';
import 'package:gestion_courses/services/auth_service.dart';
import 'package:gestion_courses/models/user_model.dart';
import 'package:gestion_courses/constants/app_theme.dart';
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
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Courses',
      theme: AppTheme.lightTheme,
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
  bool _showSplash = true;

  @override
  void initState() { //appelée automatiquement au démarrage d'un StatefulWidget
    super.initState();
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
        // Splash ou chargement Firebase
        if (_showSplash ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreenV2();
        }

        // 🔥 Si l’utilisateur est connecté
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // 🔥 Si l’utilisateur est déconnecté
        return const LoginScreen();
      },
    );
  }
}

// SUPPRIME cette ancienne classe SplashScreen qui était ici
// Elle est maintenant dans screens/splash_screen.dart