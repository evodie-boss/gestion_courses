// lib/gestion_portefeuille/models/portefeuille_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Portefeuille {
  String id;
  String userId;
  double balance;          // Solde actuel
  double monthlyBudget;    // Budget mensuel
  String currency;         // 'EUR' ou 'XOF'
  double exchangeRate;     // Taux de change EUR → FCFA
  DateTime lastUpdated;
  
  Portefeuille({
    required this.id,
    required this.userId,
    required this.balance,
    required this.monthlyBudget,
    this.currency = 'XOF',
    this.exchangeRate = 655.96,
    required this.lastUpdated,
  });
  
  // Constructeur pour nouveau portefeuille
  Portefeuille.newPortefeuille({
    required this.userId,
    this.balance = 0.0,
    this.monthlyBudget = 655960.0, // 1000€ en FCFA
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
      'currency': currency,
      'exchangeRate': exchangeRate,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
  
  // Convertir depuis Firestore
  factory Portefeuille.fromMap(Map<String, dynamic> map, String documentId) {
    return Portefeuille(
      id: documentId,
      userId: map['userId'] ?? '',
      balance: (map['balance'] ?? 0.0).toDouble(),
      monthlyBudget: (map['monthlyBudget'] ?? 655960.0).toDouble(),
      currency: map['currency'] ?? 'XOF',
      exchangeRate: (map['exchangeRate'] ?? 655.96).toDouble(),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
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
  
  // Calculer le budget restant
  double calculateRemainingBudget(double monthlyExpenses) {
    return monthlyBudget - monthlyExpenses;
  }
}