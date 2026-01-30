// lib/gestion_portefeuille/services/budget_calculator.dart

import '../models/transaction_model.dart' as my_models;

class BudgetCalculator {
  // 1. Calculer le solde total
  static double calculateBalance(List<my_models.Transaction> transactions) {
    double balance = 0.0;
    for (var transaction in transactions) {
      if (transaction.type == 'ajout') {
        balance += transaction.amount;
      } else {
        balance -= transaction.amount;
      }
    }
    return balance;
  }

  // 2. Calculer les dépenses du mois
  static double calculateMonthlyExpenses(List<my_models.Transaction> transactions) {
    DateTime now = DateTime.now();
    double total = 0.0;
    
    for (var transaction in transactions) {
      if (transaction.type == 'depense' && 
          transaction.date.month == now.month && 
          transaction.date.year == now.year) {
        total += transaction.amount;
      }
    }
    return total;
  }

  // 3. Calculer le budget restant
  static double calculateRemainingBudget(double monthlyBudget, List<my_models.Transaction> transactions) {
    final expenses = calculateMonthlyExpenses(transactions);
    return monthlyBudget - expenses;
  }

  // 4. Pourcentage du budget utilisé
  static double calculateBudgetPercentage(double monthlyBudget, List<my_models.Transaction> transactions) {
    if (monthlyBudget <= 0) return 0.0;
    final expenses = calculateMonthlyExpenses(transactions);
    return (expenses / monthlyBudget) * 100;
  }

  // 5. Vérifier les alertes
  static Map<String, dynamic> checkAlerts(double monthlyBudget, List<my_models.Transaction> transactions) {
    final expenses = calculateMonthlyExpenses(transactions);
    final remaining = monthlyBudget - expenses;
    final percentage = calculateBudgetPercentage(monthlyBudget, transactions);

    return {
      'isBudgetExceeded': expenses > monthlyBudget,
      'isBudgetWarning': percentage >= 80,
      'isLowBalance': calculateBalance(transactions) < 50,
      'remainingBudget': remaining,
      'percentageUsed': percentage,
    };
  }

  // 6. Statistiques simples
  static Map<String, dynamic> getStatistics(List<my_models.Transaction> transactions) {
    final now = DateTime.now();
    double totalDepenses = 0.0;
    double totalAjouts = 0.0;
    double depensesMois = 0.0;
    
    for (var transaction in transactions) {
      if (transaction.type == 'depense') {
        totalDepenses += transaction.amount;
        if (transaction.date.month == now.month && transaction.date.year == now.year) {
          depensesMois += transaction.amount;
        }
      } else {
        totalAjouts += transaction.amount;
      }
    }

    return {
      'totalDepenses': totalDepenses,
      'totalAjouts': totalAjouts,
      'depensesMois': depensesMois,
      'nombreTransactions': transactions.length,
    };
  }
}