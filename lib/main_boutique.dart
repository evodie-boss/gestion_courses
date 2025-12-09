import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gestion_courses/gestion_boutiques/pages/boutiques.dart';
import 'firebase_options.dart'; // IMPORTANT: Ajouter cette importation

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // CORRECTION: Utiliser les options Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // ← CE QUI MANQUE
  );
  
  runApp(const ElegantBoutiqueApp());
}

class ElegantBoutiqueApp extends StatelessWidget {
  const ElegantBoutiqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StyleShop - Gestion de Boutiques',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F9E99),
          primary: const Color(0xFF0F9E99),
          secondary: const Color(0xFFEFE9E0),
          background: const Color(0xFFFAF7F2),
          surface: Colors.white,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 2,
          iconTheme: IconThemeData(color: Color(0xFF333333)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F9E99),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const ElegantBoutiquePage(),
      },
    );
  }
}