// lib/gestion_portefeuille/models/portefeuille_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Portefeuille {
  String id;
  String userId;
  double balance;          // Solde actuel
  double monthlyBudget;    // Budget mensuel
  double monthlyExpenses;  // <-- NOUVEAU CHAMP !
  String currency;         // 'EUR' ou 'XOF'
  double exchangeRate;     // Taux de change EUR → FCFA
  DateTime lastUpdated;
  
  Portefeuille({
    required this.id,
    required this.userId,
    required this.balance,
    required this.monthlyBudget,
    this.monthlyExpenses = 0.0,  // <-- AJOUTER AVEC VALEUR PAR DÉFAUT
    this.currency = 'XOF',
    this.exchangeRate = 655.96,
    required this.lastUpdated,
  });
  
  // Constructeur pour nouveau portefeuille
  Portefeuille.newPortefeuille({
    required this.userId,
    this.balance = 0.0,
    this.monthlyBudget = 655960.0, // 1000€ en FCFA
    this.monthlyExpenses = 0.0,    // <-- AJOUTER
    this.currency = 'XOF',
    this.exchangeRate = 655.96,
  }) : id = '',
      lastUpdated = DateTime.now();
  
  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'balance': balance,
      'monthlyBudget': monthlyBudget,
      'monthlyExpenses': monthlyExpenses,  // <-- AJOUTER
      'currency': currency,
      'exchangeRate': exchangeRate,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
  
  // Convertir depuis Firestore
  factory Portefeuille.fromMap(Map<String, dynamic> map, String documentId) {
    // Fonction pour parser la date de manière sécurisée
    DateTime parseLastUpdated(dynamic dateField) {
      if (dateField is Timestamp) {
        return dateField.toDate();
      } else if (dateField is DateTime) {
        return dateField;
      } else if (dateField is String) {
        try {
          return DateTime.parse(dateField);
        } catch (e) {
          print('⚠️ Erreur parsing lastUpdated: $dateField');
        }
      } else if (dateField != null) {
        print('⚠️ Type de lastUpdated inattendu: ${dateField.runtimeType}');
      }
      // Fallback: date actuelle
      return DateTime.now();
    }
    
    return Portefeuille(
      id: documentId,
      userId: map['userId']?.toString() ?? '',
      balance: (map['balance'] ?? 0.0).toDouble(),
      monthlyBudget: (map['monthlyBudget'] ?? 655960.0).toDouble(),
      monthlyExpenses: (map['monthlyExpenses'] ?? 0.0).toDouble(),  // <-- AJOUTER
      currency: map['currency']?.toString() ?? 'XOF',
      exchangeRate: (map['exchangeRate'] ?? 655.96).toDouble(),
      lastUpdated: parseLastUpdated(map['lastUpdated']),
    );
  }
  
  // Convertir montant entre devises
  double convertToFCFA(double amountInEUR) {
    return amountInEUR * exchangeRate;
  }
  
  double convertToEUR(double amountInFCFA) {
    return amountInFCFA / exchangeRate;
  }
  
  // Getter pour symbole devise
  String get currencySymbol {
    return currency == 'EUR' ? '€' : 'FCFA';
  }
  
  // Formatter les montants
  String formatAmount(double amount) {
    if (currency == 'XOF') {
      return '${amount.toStringAsFixed(0)} FCFA';
    } else {
      return '${amount.toStringAsFixed(2)} €';
    }
  }
  
  // Formatter le solde
  String get formattedBalance {
    return formatAmount(balance);
  }
  
  // Formatter le budget
  String get formattedBudget {
    return formatAmount(monthlyBudget);
  }
  
  // Formatter les dépenses
  String get formattedExpenses {
    return formatAmount(monthlyExpenses);
  }
  
  // Calculer le budget restant
  double get remainingBudget {
    return monthlyBudget - monthlyExpenses;
  }
  
  // Pourcentage d'utilisation du budget
  double get budgetUsagePercentage {
    if (monthlyBudget <= 0) return 0.0;
    return (monthlyExpenses / monthlyBudget) * 100;
  }
  
  // Vérifier si budget est dépassé
  bool get isBudgetExceeded {
    return monthlyExpenses > monthlyBudget;
  }
  
  // Vérifier si budget approche de la limite (80%)
  bool get isBudgetWarning {
    return budgetUsagePercentage >= 80.0;
  }
  
  // Vérifier si solde est bas
  bool isLowBalance([double threshold = 10000.0]) {
    return balance < threshold;
  }
  
  // Mettre à jour le solde ET les dépenses
  Portefeuille updateAfterExpense(double amount) {
    return Portefeuille(
      id: id,
      userId: userId,
      balance: balance - amount,
      monthlyBudget: monthlyBudget,
      monthlyExpenses: monthlyExpenses + amount,  // <-- INCÉMENTER LES DÉPENSES
      currency: currency,
      exchangeRate: exchangeRate,
      lastUpdated: DateTime.now(),
    );
  }
  
  // Mettre à jour après un ajout de fonds
  Portefeuille updateAfterIncome(double amount) {
    return Portefeuille(
      id: id,
      userId: userId,
      balance: balance + amount,
      monthlyBudget: monthlyBudget,
      monthlyExpenses: monthlyExpenses,  // Les dépenses ne changent pas
      currency: currency,
      exchangeRate: exchangeRate,
      lastUpdated: DateTime.now(),
    );
  }
  
  // Mettre à jour le budget
  Portefeuille updateBudget(double newBudget) {
    return Portefeuille(
      id: id,
      userId: userId,
      balance: balance,
      monthlyBudget: newBudget,
      monthlyExpenses: monthlyExpenses,
      currency: currency,
      exchangeRate: exchangeRate,
      lastUpdated: DateTime.now(),
    );
  }
  
  // Réinitialiser les dépenses mensuelles (à appeler en début de mois)
  Portefeuille resetMonthlyExpenses() {
    return Portefeuille(
      id: id,
      userId: userId,
      balance: balance,
      monthlyBudget: monthlyBudget,
      monthlyExpenses: 0.0,  // <-- RÉINITIALISER À 0
      currency: currency,
      exchangeRate: exchangeRate,
      lastUpdated: DateTime.now(),
    );
  }
  
  // Changer de devise
  Portefeuille changeCurrency(String newCurrency) {
    double newBalance = balance;
    double newBudget = monthlyBudget;
    double newExpenses = monthlyExpenses;
    
    if (currency == 'EUR' && newCurrency == 'XOF') {
      newBalance = convertToFCFA(balance);
      newBudget = convertToFCFA(monthlyBudget);
      newExpenses = convertToFCFA(monthlyExpenses);
    } else if (currency == 'XOF' && newCurrency == 'EUR') {
      newBalance = convertToEUR(balance);
      newBudget = convertToEUR(monthlyBudget);
      newExpenses = convertToEUR(monthlyExpenses);
    }
    
    return Portefeuille(
      id: id,
      userId: userId,
      balance: newBalance,
      monthlyBudget: newBudget,
      monthlyExpenses: newExpenses,
      currency: newCurrency,
      exchangeRate: exchangeRate,
      lastUpdated: DateTime.now(),
    );
  }
  
  // Méthode pour dupliquer
  Portefeuille copyWith({
    String? id,
    String? userId,
    double? balance,
    double? monthlyBudget,
    double? monthlyExpenses,
    String? currency,
    double? exchangeRate,
    DateTime? lastUpdated,
  }) {
    return Portefeuille(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
  
  @override
  String toString() {
    return 'Portefeuille{id: $id, balance: $balance, budget: $monthlyBudget, expenses: $monthlyExpenses, currency: $currency}';
  }
}