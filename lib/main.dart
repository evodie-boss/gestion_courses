// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gestion_courses/screens/login_screen.dart';
import 'package:gestion_courses/screens/home_screen.dart';
import 'package:gestion_courses/screens/profile_screen.dart';
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
        // AuthService est un ChangeNotifier, donc on utilise ChangeNotifierProvider
        ChangeNotifierProvider(
          create: (_) => AuthService(),
          lazy:
              false, // Important: crée immédiatement pour écouter authStateChanges
        ),
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
      title: 'Gestion Courses',
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Ajoutez un StreamBuilder pour gérer l'état de chargement initial
    return StreamBuilder<UserModel?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Afficher un écran de chargement pendant l'initialisation
          return const SplashScreen();
        }

        // Utiliser l'utilisateur courant
        if (authService.currentUser != null) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE9E0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF0F9E99),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.shopping_basket_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'ShopEasy',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F9E99),
              ),
            ),
            const SizedBox(height: 10),
            const CircularProgressIndicator(color: Color(0xFF0F9E99)),
          ],
        ),
      ),
    );
  }
}