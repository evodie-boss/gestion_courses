// lib/gestion_portefeuille/services/wallet_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart' as my_models;
import './portefeuille_service.dart'; // ← NOUVEAU IMPORT

class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'transactions';
  final PortefeuilleService _portefeuilleService = PortefeuilleService(); // ← NOUVEAU

  // 1. Ajouter une transaction
  Future<void> addTransaction(my_models.Transaction transaction) async {
    try {
      // 1. Vérifier le solde si c'est une dépense
      if (transaction.type == 'depense') {
        final portefeuille = await _portefeuilleService.getOrCreatePortefeuille(transaction.userId);
        
        // Convertir le montant si besoin
        double amountToCheck = transaction.amount;
        if (transaction.currency != portefeuille.currency) {
          if (transaction.currency == 'EUR' && portefeuille.currency == 'XOF') {
            amountToCheck = portefeuille.convertToFCFA(amountToCheck);
          } else if (transaction.currency == 'XOF' && portefeuille.currency == 'EUR') {
            amountToCheck = portefeuille.convertToEUR(amountToCheck);
          }
        }
        
        // Vérifier si solde suffisant
        if (portefeuille.balance < amountToCheck) {
          throw Exception('Solde insuffisant! Vous avez ${portefeuille.formatAmount(portefeuille.balance)}');
        }
      }

      // 2. Ajouter la transaction
      await _firestore
          .collection(_collectionName)
          .doc(transaction.id.isEmpty ? null : transaction.id)
          .set(transaction.toMap());
      
      // 3. Mettre à jour le solde dans le portefeuille
      await _portefeuilleService.updateBalance(transaction.userId, transaction);
      
      print('✅ Transaction ajoutée et solde mis à jour');
    } catch (e) {
      print('❌ Erreur ajout: $e');
      rethrow;
    }
  }

  // 2. Récupérer toutes les transactions d'un utilisateur
  Stream<List<my_models.Transaction>> getTransactionsStream(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return my_models.Transaction.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // 3. Récupérer les transactions du mois en cours (sans index)
  Stream<List<my_models.Transaction>> getCurrentMonthTransactions(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      // Filtrer localement par mois courant
      final now = DateTime.now();
      return snapshot.docs
          .where((doc) {
            final date = (doc.data()['date'] as Timestamp).toDate();
            return date.month == now.month && date.year == now.year;
          })
          .map((doc) => my_models.Transaction.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // 4. Supprimer une transaction
  Future<void> deleteTransaction(String transactionId, String userId) async {
    try {
      // Récupérer la transaction pour connaître son montant et type
      final doc = await _firestore.collection(_collectionName).doc(transactionId).get();
      if (doc.exists) {
        final transaction = my_models.Transaction.fromMap(doc.data()!, doc.id);
        
        // Supprimer la transaction
        await _firestore.collection(_collectionName).doc(transactionId).delete();
        
        // Annuler l'effet sur le solde (inverser la transaction)
        await _portefeuilleService.reverseTransaction(userId, transaction);
        
        print('✅ Transaction supprimée et solde ajusté');
      }
    } catch (e) {
      print('❌ Erreur suppression: $e');
      rethrow;
    }
  }

  // 5. Mettre à jour une transaction
  Future<void> updateTransaction(my_models.Transaction oldTransaction, my_models.Transaction newTransaction) async {
    try {
      // 1. Annuler l'ancienne transaction
      await _portefeuilleService.reverseTransaction(oldTransaction.userId, oldTransaction);
      
      // 2. Vérifier le solde pour la nouvelle transaction si c'est une dépense
      if (newTransaction.type == 'depense') {
        final portefeuille = await _portefeuilleService.getOrCreatePortefeuille(newTransaction.userId);
        
        // Convertir le montant si besoin
        double amountToCheck = newTransaction.amount;
        if (newTransaction.currency != portefeuille.currency) {
          if (newTransaction.currency == 'EUR' && portefeuille.currency == 'XOF') {
            amountToCheck = portefeuille.convertToFCFA(amountToCheck);
          } else if (newTransaction.currency == 'XOF' && portefeuille.currency == 'EUR') {
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
      await _portefeuilleService.updateBalance(newTransaction.userId, newTransaction);
      
      print('✅ Transaction mise à jour et solde ajusté');
    } catch (e) {
      print('❌ Erreur mise à jour: $e');
      rethrow;
    }
  }

  // 6. Calculer le solde total
  Future<double> calculateBalance(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .get();

      double balance = 0.0;
      for (var doc in snapshot.docs) {
        final transaction = my_models.Transaction.fromMap(doc.data(), doc.id);
        if (transaction.type == 'ajout') {
          balance += transaction.amount;
        } else {
          balance -= transaction.amount;
        }
      }
      return balance;
    } catch (e) {
      print('❌ Erreur calcul solde: $e');
      return 0.0;
    }
  }

  // 7. Calculer les dépenses du mois (version simple)
  Future<double> calculateMonthlyExpenses(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'depense')
          .get();

      double total = 0.0;
      final now = DateTime.now();
      
      for (var doc in snapshot.docs) {
        final transaction = my_models.Transaction.fromMap(doc.data(), doc.id);
        if (transaction.date.month == now.month && 
            transaction.date.year == now.year) {
          total += transaction.amount;
        }
      }
      return total;
    } catch (e) {
      print('❌ Erreur calcul dépenses: $e');
      return 0.0;
    }
  }

  // 8. Récupérer le portefeuille (Nouvelle méthode) ← NOUVEAU
  Future<Map<String, dynamic>> getPortefeuilleData(String userId) async {
    try {
      final portefeuille = await _portefeuilleService.getOrCreatePortefeuille(userId);
      final transactions = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .get();
      
      final List<my_models.Transaction> allTransactions = transactions.docs
          .map((doc) => my_models.Transaction.fromMap(doc.data(), doc.id))
          .toList();
      
      final monthlyExpenses = _calculateMonthlyExpensesFromList(allTransactions);
      final remainingBudget = portefeuille.monthlyBudget - monthlyExpenses;
      
      return {
        'portefeuille': portefeuille,
        'balance': portefeuille.balance,
        'monthlyBudget': portefeuille.monthlyBudget,
        'monthlyExpenses': monthlyExpenses,
        'remainingBudget': remainingBudget,
        'currency': portefeuille.currency,
        'transactions': allTransactions,
      };
    } catch (e) {
      print('❌ Erreur getPortefeuilleData: $e');
      rethrow;
    }
  }

  // Méthode helper pour calculer les dépenses mensuelles
  double _calculateMonthlyExpensesFromList(List<my_models.Transaction> transactions) {
    final now = DateTime.now();
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
}