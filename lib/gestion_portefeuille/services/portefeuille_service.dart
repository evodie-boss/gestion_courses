// lib/gestion_portefeuille/services/portefeuille_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/portefeuille_model.dart';
import '../models/transaction_model.dart' as transaction_model;

class PortefeuilleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'portefeuille';

  // Méthode privée pour les stats vides
  Map<String, dynamic> _getEmptyStats() {
    return {
      'balance': 0.0,
      'monthlyBudget': 0.0,
      'monthlyExpenses': 0.0,
      'remainingBudget': 0.0,
      'budgetPercentage': 0.0,
      'currency': 'XOF',
      'isLowBalance': false,
      'isBudgetWarning': false,
      'isBudgetExceeded': false,
    };
  }

  // 1. Récupérer ou créer le portefeuille d'un utilisateur
  // Dans la méthode getOrCreatePortefeuille, ajouter monthlyExpenses:
  Future<Portefeuille> getOrCreatePortefeuille(String userId) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(userId).get();

      if (doc.exists) {
        return Portefeuille.fromMap(doc.data()!, doc.id);
      } else {
        // Créer un nouveau portefeuille AVEC monthlyExpenses
        final newPortefeuille = Portefeuille.newPortefeuille(userId: userId);
        await _firestore
            .collection(_collectionName)
            .doc(userId)
            .set(newPortefeuille.toMap());

        print('✅ Nouveau portefeuille créé pour: $userId');
        return newPortefeuille;
      }
    } catch (e) {
      print('❌ Erreur getOrCreatePortefeuille: $e');
      rethrow;
    }
  }

  // 2. Récupérer le portefeuille (Stream)
  Stream<Portefeuille> getPortefeuilleStream(String userId) {
    return _firestore
        .collection(_collectionName)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        // Créer un portefeuille par défaut
        return Portefeuille.newPortefeuille(userId: userId);
      }
      return Portefeuille.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  // 3. Mettre à jour le solde après transaction
  Future<void> updateBalance(
      String userId, transaction_model.Transaction transaction) async {
    try {
      // Récupérer le portefeuille actuel
      final portefeuille = await getOrCreatePortefeuille(userId);

      // Convertir si besoin
      double amount = transaction.amount;
      if (transaction.currency != portefeuille.currency) {
        if (transaction.currency == 'EUR' && portefeuille.currency == 'XOF') {
          amount = portefeuille.convertToFCFA(amount);
        } else if (transaction.currency == 'XOF' &&
            portefeuille.currency == 'EUR') {
          amount = portefeuille.convertToEUR(amount);
        }
      }

      // Mettre à jour le solde
      double newBalance = portefeuille.balance;
      if (transaction.type == 'ajout') {
        newBalance += amount;
        print('➕ Ajout de ${portefeuille.formatAmount(amount)} au solde');
      } else if (transaction.type == 'depense') {
        // Vérifier si solde suffisant
        if (portefeuille.balance >= amount) {
          newBalance -= amount;
          print('➖ Dépense de ${portefeuille.formatAmount(amount)} du solde');
        } else {
          throw Exception(
              'Solde insuffisant! Vous avez ${portefeuille.formatAmount(portefeuille.balance)}');
        }
      }

      // Mettre à jour dans Firestore
      await _firestore.collection(_collectionName).doc(userId).update({
        'balance': newBalance,
        'lastUpdated': Timestamp.now(),
      });

      print('💰 Nouveau solde: ${portefeuille.formatAmount(newBalance)}');
    } catch (e) {
      print('❌ Erreur updateBalance: $e');
      rethrow;
    }
  }

  // 4. Annuler une transaction (pour suppression/modification)
  Future<void> reverseTransaction(
      String userId, transaction_model.Transaction transaction) async {
    try {
      final portefeuille = await getOrCreatePortefeuille(userId);

      // Convertir si besoin
      double amount = transaction.amount;
      if (transaction.currency != portefeuille.currency) {
        if (transaction.currency == 'EUR' && portefeuille.currency == 'XOF') {
          amount = portefeuille.convertToFCFA(amount);
        } else if (transaction.currency == 'XOF' &&
            portefeuille.currency == 'EUR') {
          amount = portefeuille.convertToEUR(amount);
        }
      }

      // Inverser l'effet sur le solde
      double newBalance = portefeuille.balance;
      if (transaction.type == 'ajout') {
        newBalance -= amount; // Annuler un ajout
        print('↪️ Annulation ajout: -${portefeuille.formatAmount(amount)}');
      } else if (transaction.type == 'depense') {
        newBalance += amount; // Annuler une dépense
        print('↪️ Annulation dépense: +${portefeuille.formatAmount(amount)}');
      }

      // Mettre à jour dans Firestore
      await _firestore.collection(_collectionName).doc(userId).update({
        'balance': newBalance,
        'lastUpdated': Timestamp.now(),
      });

      print(
          '💰 Solde après annulation: ${portefeuille.formatAmount(newBalance)}');
    } catch (e) {
      print('❌ Erreur reverseTransaction: $e');
      rethrow;
    }
  }

  // 5. Modifier le budget mensuel
  Future<void> updateMonthlyBudget(String userId, double newBudget) async {
    try {
      await _firestore.collection(_collectionName).doc(userId).update({
        'monthlyBudget': newBudget,
        'lastUpdated': Timestamp.now(),
      });
      print('🎯 Budget mensuel mis à jour: $newBudget');
    } catch (e) {
      print('❌ Erreur updateMonthlyBudget: $e');
      rethrow;
    }
  }

  // 6. Mettre à jour le taux de change
  Future<void> updateExchangeRate(String userId, double newRate) async {
    try {
      await _firestore.collection(_collectionName).doc(userId).update({
        'exchangeRate': newRate,
        'lastUpdated': Timestamp.now(),
      });
      print('💱 Taux de change mis à jour: $newRate');
    } catch (e) {
      print('❌ Erreur updateExchangeRate: $e');
      rethrow;
    }
  }

  // 7. Changer la devise
  Future<void> changeCurrency(String userId, String newCurrency) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        final double currentBalance = (data['balance'] ?? 0.0).toDouble();
        final String currentCurrency = data['currency'] ?? 'XOF';
        final double exchangeRate = (data['exchangeRate'] ?? 655.96).toDouble();

        // Convertir le solde si changement de devise
        double newBalance = currentBalance;
        if (currentCurrency != newCurrency) {
          if (currentCurrency == 'EUR' && newCurrency == 'XOF') {
            newBalance = currentBalance * exchangeRate;
          } else if (currentCurrency == 'XOF' && newCurrency == 'EUR') {
            newBalance = currentBalance / exchangeRate;
          }
        }

        await _firestore.collection(_collectionName).doc(userId).update({
          'currency': newCurrency,
          'balance': newBalance,
          'lastUpdated': Timestamp.now(),
        });
        print('💱 Devise changée: $newCurrency');
      }
    } catch (e) {
      print('❌ Erreur changeCurrency: $e');
      rethrow;
    }
  }

  // 8. Réinitialiser le portefeuille
  Future<void> resetPortefeuille(String userId) async {
    try {
      final defaultPortefeuille = Portefeuille.newPortefeuille(userId: userId);
      await _firestore
          .collection(_collectionName)
          .doc(userId)
          .set(defaultPortefeuille.toMap());
      print('🔄 Portefeuille réinitialisé');
    } catch (e) {
      print('❌ Erreur resetPortefeuille: $e');
      rethrow;
    }
  }

  // 9. Ajouter des fonds directement (rechargement)
  Future<void> addFunds(String userId, double amount, String currency) async {
    try {
      final portefeuille = await getOrCreatePortefeuille(userId);

      // Convertir si besoin
      double amountToAdd = amount;
      if (currency != portefeuille.currency) {
        if (currency == 'EUR' && portefeuille.currency == 'XOF') {
          amountToAdd = portefeuille.convertToFCFA(amount);
        } else if (currency == 'XOF' && portefeuille.currency == 'EUR') {
          amountToAdd = portefeuille.convertToEUR(amount);
        }
      }

      final newBalance = portefeuille.balance + amountToAdd;

      await _firestore.collection(_collectionName).doc(userId).update({
        'balance': newBalance,
        'lastUpdated': Timestamp.now(),
      });

      print(
          '💳 Rechargement de ${portefeuille.formatAmount(amountToAdd)} effectué');
      print('💰 Nouveau solde: ${portefeuille.formatAmount(newBalance)}');
    } catch (e) {
      print('❌ Erreur addFunds: $e');
      rethrow;
    }
  }

  // 10. Vérifier si dépense possible
  Future<bool> canMakeExpense(
      String userId, double amount, String currency) async {
    try {
      final portefeuille = await getOrCreatePortefeuille(userId);

      // Convertir si besoin
      double amountToCheck = amount;
      if (currency != portefeuille.currency) {
        if (currency == 'EUR' && portefeuille.currency == 'XOF') {
          amountToCheck = portefeuille.convertToFCFA(amount);
        } else if (currency == 'XOF' && portefeuille.currency == 'EUR') {
          amountToCheck = portefeuille.convertToEUR(amount);
        }
      }

      return portefeuille.balance >= amountToCheck;
    } catch (e) {
      print('❌ Erreur canMakeExpense: $e');
      return false;
    }
  }

  // 11. NOUVEAU: Calculer les dépenses mensuelles - VERSION CORRIGÉE
  Future<double> calculateMonthlyExpenses(String userId) async {
    try {
      // Récupérer le portefeuille AVEC monthlyExpenses stocké
      final portefeuille = await getOrCreatePortefeuille(userId);

      // Retourner DIRECTEMENT les monthlyExpenses du portefeuille
      print(
          '📊 Dépenses mensuelles depuis Firestore: ${portefeuille.formatAmount(portefeuille.monthlyExpenses)}');
      return portefeuille.monthlyExpenses;
    } catch (e) {
      print('❌ Erreur calculateMonthlyExpenses: $e');
      return 0.0;
    }
  }

  // 12. NOUVEAU: Calculer le budget restant
  Future<double> calculateRemainingBudget(String userId) async {
    try {
      final portefeuille = await getOrCreatePortefeuille(userId);
      final monthlyExpenses = await calculateMonthlyExpenses(userId);
      final remainingBudget = portefeuille.monthlyBudget - monthlyExpenses;

      print('🎯 Budget restant: ${portefeuille.formatAmount(remainingBudget)}');
      return remainingBudget;
    } catch (e) {
      print('❌ Erreur calculateRemainingBudget: $e');
      final portefeuille = await getOrCreatePortefeuille(userId);
      return portefeuille.monthlyBudget;
    }
  }

  // 13. NOUVEAU: Vérifier les alertes avec calculs réels
  Future<Map<String, dynamic>> checkAlerts(String userId) async {
    try {
      final portefeuille = await getOrCreatePortefeuille(userId);
      final monthlyExpenses = await calculateMonthlyExpenses(userId);

      final budgetPercentage = portefeuille.monthlyBudget > 0
          ? (monthlyExpenses / portefeuille.monthlyBudget) * 100
          : 0.0;

      final remainingBudget = portefeuille.monthlyBudget - monthlyExpenses;

      return {
        'isLowBalance': portefeuille.isLowBalance(),
        'isBudgetWarning': budgetPercentage >= 80.0 && budgetPercentage < 100.0,
        'isBudgetExceeded': monthlyExpenses > portefeuille.monthlyBudget,
        'percentageUsed': budgetPercentage,
        'monthlyExpenses': monthlyExpenses,
        'remainingBudget': remainingBudget,
        'monthlyBudget': portefeuille.monthlyBudget,
      };
    } catch (e) {
      print('❌ Erreur checkAlerts: $e');
      return {
        'isLowBalance': false,
        'isBudgetWarning': false,
        'isBudgetExceeded': false,
        'percentageUsed': 0.0,
        'monthlyExpenses': 0.0,
        'remainingBudget': 0.0,
        'monthlyBudget': 0.0,
      };
    }
  }

  // 14. NOUVEAU: Récupérer les statistiques en temps réel
  Stream<Map<String, dynamic>> getStatsStream(String userId) {
    return _firestore
        .collection(_collectionName)
        .doc(userId)
        .snapshots()
        .asyncMap((snapshot) async {
      if (!snapshot.exists) {
        return _getEmptyStats();
      }

      final portefeuille = Portefeuille.fromMap(snapshot.data()!, snapshot.id);
      final monthlyExpenses = await calculateMonthlyExpenses(userId);
      final budgetPercentage = portefeuille.monthlyBudget > 0
          ? (monthlyExpenses / portefeuille.monthlyBudget) * 100
          : 0.0;

      return {
        'portefeuille': portefeuille,
        'balance': portefeuille.balance,
        'monthlyBudget': portefeuille.monthlyBudget,
        'monthlyExpenses': monthlyExpenses,
        'remainingBudget': portefeuille.monthlyBudget - monthlyExpenses,
        'budgetPercentage': budgetPercentage,
        'currency': portefeuille.currency,
        'isLowBalance': portefeuille.isLowBalance(),
        'isBudgetWarning': budgetPercentage >= 80.0 && budgetPercentage < 100.0,
        'isBudgetExceeded': monthlyExpenses > portefeuille.monthlyBudget,
      };
    });
  }
}
