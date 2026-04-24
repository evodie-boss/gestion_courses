// lib/gestion_portefeuille/services/wallet_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart' as my_models;
import './portefeuille_service.dart';

class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'transactions';
  final PortefeuilleService _portefeuilleService = PortefeuilleService();

  // 1. Ajouter une transaction ET mettre à jour le budget
  Future<void> addTransaction(my_models.Transaction transaction) async {
    try {
      print('💰 Début ajout transaction: ${transaction.description}');

      // 1. Vérifier le solde si c'est une dépense
      if (transaction.type == 'depense') {
        final portefeuille = await _portefeuilleService
            .getOrCreatePortefeuille(transaction.userId);

        // Convertir le montant si besoin
        double amountToCheck = transaction.amount;
        if (transaction.currency != portefeuille.currency) {
          if (transaction.currency == 'EUR' && portefeuille.currency == 'XOF') {
            amountToCheck = portefeuille.convertToFCFA(amountToCheck);
          } else if (transaction.currency == 'XOF' &&
              portefeuille.currency == 'EUR') {
            amountToCheck = portefeuille.convertToEUR(amountToCheck);
          }
        }

        // Vérifier si solde suffisant
        if (portefeuille.balance < amountToCheck) {
          throw Exception(
              'Solde insuffisant! Vous avez ${portefeuille.formatAmount(portefeuille.balance)}');
        }

        // Vérifier si budget dépassé
        final monthlyExpenses = await _portefeuilleService
            .calculateMonthlyExpenses(transaction.userId);
        final totalAfterTransaction = monthlyExpenses + amountToCheck;

        if (totalAfterTransaction > portefeuille.monthlyBudget) {
          print(
              '⚠️ Attention: Cette transaction dépassera votre budget mensuel!');
        }
      }

      // 2. Ajouter la transaction
      final transactionData = transaction.toMap();
      final transactionRef =
          await _firestore.collection(_collectionName).add(transactionData);

      print('✅ Transaction ajoutée avec ID: ${transactionRef.id}');

      // 3. Mettre à jour le solde dans le portefeuille
      await _portefeuilleService.updateBalance(transaction.userId, transaction);

      print('✅ Solde et statistiques mis à jour');
    } catch (e) {
      print('❌ Erreur ajout transaction: $e');
      rethrow;
    }
  }

  // 2. Récupérer toutes les transactions d'un utilisateur (CORRIGÉ)
  Stream<List<my_models.Transaction>> getTransactionsStream(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        // L'orderBy('date', descending: true) a été retiré pour éviter l'erreur d'index
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return my_models.Transaction.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // 3. Récupérer les transactions du mois en cours (CORRIGÉ)
  Stream<List<my_models.Transaction>> getCurrentMonthTransactions(
      String userId) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
        // L'orderBy('date', descending: true) a été retiré pour éviter l'erreur d'index
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return my_models.Transaction.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // 4. Supprimer une transaction ET ajuster le budget
  Future<void> deleteTransaction(String transactionId, String userId) async {
    try {
      print('🗑️ Début suppression transaction: $transactionId');

      // Récupérer la transaction pour connaître son montant et type
      final doc =
          await _firestore.collection(_collectionName).doc(transactionId).get();
      if (!doc.exists) {
        throw Exception('Transaction non trouvée');
      }

      final transaction = my_models.Transaction.fromMap(doc.data()!, doc.id);

      // Supprimer la transaction
      await _firestore.collection(_collectionName).doc(transactionId).delete();

      // Annuler l'effet sur le solde (inverser la transaction)
      await _portefeuilleService.reverseTransaction(userId, transaction);

      print('✅ Transaction supprimée et statistiques ajustées');
    } catch (e) {
      print('❌ Erreur suppression: $e');
      rethrow;
    }
  }

  // 5. Mettre à jour une transaction ET ajuster le budget
  Future<void> updateTransaction(my_models.Transaction oldTransaction,
      my_models.Transaction newTransaction) async {
    try {
      print('✏️ Début mise à jour transaction: ${oldTransaction.id}');

      // 1. Annuler l'ancienne transaction
      await _portefeuilleService.reverseTransaction(
          oldTransaction.userId, oldTransaction);

      // 2. Vérifier le solde pour la nouvelle transaction si c'est une dépense
      if (newTransaction.type == 'depense') {
        final portefeuille = await _portefeuilleService
            .getOrCreatePortefeuille(newTransaction.userId);

        // Convertir le montant si besoin
        double amountToCheck = newTransaction.amount;
        if (newTransaction.currency != portefeuille.currency) {
          if (newTransaction.currency == 'EUR' &&
              portefeuille.currency == 'XOF') {
            amountToCheck = portefeuille.convertToFCFA(amountToCheck);
          } else if (newTransaction.currency == 'XOF' &&
              portefeuille.currency == 'EUR') {
            amountToCheck = portefeuille.convertToEUR(amountToCheck);
          }
        }

        // Vérifier si solde suffisant
        if (portefeuille.balance < amountToCheck) {
          throw Exception('Solde insuffisant!');
        }
      }

      // 3. Mettre à jour la transaction
      await _firestore
          .collection(_collectionName)
          .doc(newTransaction.id)
          .update(newTransaction.toMap());

      // 4. Appliquer la nouvelle transaction
      await _portefeuilleService.updateBalance(
          newTransaction.userId, newTransaction);

      print('✅ Transaction mise à jour et statistiques ajustées');
    } catch (e) {
      print('❌ Erreur mise à jour: $e');
      rethrow;
    }
  }

  // 6. Récupérer les statistiques mensuelles en temps réel
  Stream<Map<String, dynamic>> getMonthlyStatsStream(String userId) {
    return _portefeuilleService.getStatsStream(userId);
  }

  // 7. Calculer les dépenses du mois en temps réel - VERSION CORRIGÉE
  Future<double> calculateMonthlyExpenses(String userId) async {
    // Déléguer au PortefeuilleService qui utilise maintenant monthlyExpenses
    return await _portefeuilleService.calculateMonthlyExpenses(userId);
  }

  // 8. Calculer les revenus du mois
  Future<double> calculateMonthlyIncome(String userId) async {
    try {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final snapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'ajout')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
          .where('date',
              isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
          .get();

      double total = 0.0;
      final portefeuille =
          await _portefeuilleService.getOrCreatePortefeuille(userId);

      for (var doc in snapshot.docs) {
        final transaction = my_models.Transaction.fromMap(doc.data()!, doc.id);
        double amount = transaction.amount;

        // Convertir si devise différente
        if (transaction.currency != portefeuille.currency) {
          if (transaction.currency == 'EUR' && portefeuille.currency == 'XOF') {
            amount = portefeuille.convertToFCFA(amount);
          } else if (transaction.currency == 'XOF' &&
              portefeuille.currency == 'EUR') {
            amount = portefeuille.convertToEUR(amount);
          }
        }
        total += amount;
      }

      print(
          '💰 Revenus mensuels calculés: ${portefeuille.formatAmount(total)}');
      return total;
    } catch (e) {
      print('❌ Erreur calcul revenus: $e');
      return 0.0;
    }
  }

  // 9. NOUVEAU: Récupérer l'historique des statistiques (CORRIGÉ - Tri local)
  Stream<List<Map<String, dynamic>>> getStatsHistoryStream(String userId) {
    return _firestore
        .collection('monthly_stats')
        .where('userId', isEqualTo: userId)
        // Les orderBy et limit ont été retirés pour éviter l'erreur d'index
        .snapshots()
        .map((snapshot) {
      final statsList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'monthlyExpenses': (data['monthlyExpenses'] ?? 0.0).toDouble(),
          'monthlyIncome': (data['monthlyIncome'] ?? 0.0).toDouble(),
          'remainingBudget': (data['remainingBudget'] ?? 0.0).toDouble(),
          'budgetPercentage': (data['budgetPercentage'] ?? 0.0).toDouble(),
          'month': data['month'] ?? 0,
          'year': data['year'] ?? 0,
          'updatedAt': data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.now(),
        };
      }).toList();

      // Tri local par année et mois (pour compenser le retrait de l'orderBy dans Firestore)
      statsList.sort((a, b) {
        if (a['year'] != b['year']) {
          return b['year'].compareTo(a['year']); // Tri descendant par année
        }
        return b['month'].compareTo(a['month']); // Tri descendant par mois
      });

      // Limitation locale aux 12 derniers mois
      return statsList.take(12).toList();
    });
  }

  // 10. NOUVEAU: Mettre à jour les statistiques mensuelles
  Future<void> updateMonthlyStatistics(String userId) async {
    try {
      final monthlyExpenses = await calculateMonthlyExpenses(userId);
      final monthlyIncome = await calculateMonthlyIncome(userId);
      final portefeuille =
          await _portefeuilleService.getOrCreatePortefeuille(userId);

      final statsData = {
        'userId': userId,
        'monthlyExpenses': monthlyExpenses,
        'monthlyIncome': monthlyIncome,
        'remainingBudget': portefeuille.monthlyBudget - monthlyExpenses,
        'budgetPercentage': portefeuille.monthlyBudget > 0
            ? (monthlyExpenses / portefeuille.monthlyBudget) * 100
            : 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
        'month': DateTime.now().month,
        'year': DateTime.now().year,
      };

      // Stocker dans une collection séparée pour historique
      final statsId =
          '${userId}_${DateTime.now().year}_${DateTime.now().month}';
      await _firestore
          .collection('monthly_stats')
          .doc(statsId)
          .set(statsData, SetOptions(merge: true));

      print('📈 Statistiques mensuelles mises à jour');
    } catch (e) {
      print('❌ Erreur mise à jour statistiques: $e');
    }
  }

  // 11. Récupérer le budget restant
  Future<double> getRemainingBudget(String userId) async {
    return await _portefeuilleService.calculateRemainingBudget(userId);
  }

  // 12. Vérifier les alertes
  Future<Map<String, dynamic>> checkAlerts(String userId) async {
    return await _portefeuilleService.checkAlerts(userId);
  }
}
