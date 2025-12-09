// lib/test_portefeuille.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import './gestion_portefeuille/screens/wallet_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyTestApp());
}

class MyTestApp extends StatelessWidget {
  const MyTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portefeuille - Test',
      theme: ThemeData(
        primaryColor: const Color(0xFF0F9E99),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F9E99),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F9E99),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const WalletScreen(userId: 'user_test_evodie'),
    );
  }
}