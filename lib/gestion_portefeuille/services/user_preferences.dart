// lib/gestion_portefeuille/services/user_preferences.dart

import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _monthlyBudgetKey = 'monthly_budget';
  static const String _currencyKey = 'currency';

  // Sauvegarder le budget mensuel
  static Future<void> saveMonthlyBudget(double budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_monthlyBudgetKey, budget);
  }

  // Récupérer le budget mensuel
  static Future<double> getMonthlyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_monthlyBudgetKey) ?? 1000.0; // Valeur par défaut
  }

  // Sauvegarder la devise
  static Future<void> saveCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, currency);
  }

  // Récupérer la devise
  static Future<String> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyKey) ?? '€'; // Euro par défaut
  }

  // Réinitialiser les préférences
  static Future<void> resetPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_monthlyBudgetKey);
    await prefs.remove(_currencyKey);
  }
}