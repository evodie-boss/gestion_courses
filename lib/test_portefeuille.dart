// lib/test_final.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import './gestion_portefeuille/screens/wallet_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialisé avec succès');
  } catch (e) {
    print('❌ Erreur Firebase: $e');
  }
  
  runApp(const TestFinalApp());
}

class TestFinalApp extends StatelessWidget {
  const TestFinalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Final Portefeuille',
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
      home: const HomeTestScreen(),
    );
  }
}

class HomeTestScreen extends StatelessWidget {
  const HomeTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test du Module Portefeuille'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Module Portefeuille - Tests',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WalletScreen(userId: 'test_user_1'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F9E99),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text(
                'Tester l\'application',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ID Utilisateur: test_user_1',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            const Text(
              'Fonctionnalités à tester:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildFeatureItem('✅ Transactions (Ajout/Dépense)'),
            _buildFeatureItem('✅ Conversion € ↔ FCFA'),
            _buildFeatureItem('✅ Statistiques mensuelles'),
            _buildFeatureItem('✅ Paramètres budget'),
            _buildFeatureItem('✅ Alertes solde/budget'),
            _buildFeatureItem('✅ Historique des transactions'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}