// lib/gestion_portefeuille/services/portefeuille_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/portefeuille_model.dart';
import '../models/transaction_model.dart' as transaction_model;

class PortefeuilleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'portefeuille';
  
  // 1. Récupérer ou créer le portefeuille d'un utilisateur
  Future<Portefeuille> getOrCreatePortefeuille(String userId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return Portefeuille.fromMap(doc.data()!, doc.id);
      } else {
        // Créer un nouveau portefeuille
        final newPortefeuille = Portefeuille.newPortefeuille(userId: userId);
        await _firestore
            .collection(_collectionName)
            .doc(userId)
            .set(newPortefeuille.toMap());
        
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
  Future<void> updateBalance(String userId, transaction_model.Transaction transaction) async {
    try {
      // Récupérer le portefeuille actuel
      final portefeuille = await getOrCreatePortefeuille(userId);
      
      // Convertir si besoin
      double amount = transaction.amount;
      if (transaction.currency != portefeuille.currency) {
        if (transaction.currency == 'EUR' && portefeuille.currency == 'XOF') {
          amount = portefeuille.convertToFCFA(amount);
        } else if (transaction.currency == 'XOF' && portefeuille.currency == 'EUR') {
          amount = portefeuille.convertToEUR(amount);
        }
      }
      
      // Mettre à jour le solde
      if (transaction.type == 'ajout') {
        portefeuille.balance += amount;
      } else if (transaction.type == 'depense') {
        // Vérifier si solde suffisant
        if (portefeuille.balance >= amount) {
          portefeuille.balance -= amount;
        } else {
          throw Exception('Solde insuffisant! Vous avez ${portefeuille.formatAmount(portefeuille.balance)}');
        }
      }
      
      portefeuille.lastUpdated = DateTime.now();
      
      // Sauvegarder dans Firestore
      await _firestore
          .collection(_collectionName)
          .doc(userId)
          .set(portefeuille.toMap());
          
      print('✅ Solde mis à jour: ${portefeuille.formatAmount(portefeuille.balance)}');
      
    } catch (e) {
      print('❌ Erreur updateBalance: $e');
      rethrow;
    }
  }
  
  // 4. Annuler une transaction (pour suppression/modification)
  Future<void> reverseTransaction(String userId, transaction_model.Transaction transaction) async {
    try {
      final portefeuille = await getOrCreatePortefeuille(userId);
      
      // Convertir si besoin
      double amount = transaction.amount;
      if (transaction.currency != portefeuille.currency) {
        if (transaction.currency == 'EUR' && portefeuille.currency == 'XOF') {
          amount = portefeuille.convertToFCFA(amount);
        } else if (transaction.currency == 'XOF' && portefeuille.currency == 'EUR') {
          amount = portefeuille.convertToEUR(amount);
        }
      }
      
      // Inverser l'effet sur le solde
      if (transaction.type == 'ajout') {
        portefeuille.balance -= amount; // Annuler un ajout
      } else if (transaction.type == 'depense') {
        portefeuille.balance += amount; // Annuler une dépense
      }
      
      portefeuille.lastUpdated = DateTime.now();
      
      // Sauvegarder
      await _firestore
          .collection(_collectionName)
          .doc(userId)
          .set(portefeuille.toMap());
          
      print('✅ Transaction annulée, solde ajusté: ${portefeuille.formatAmount(portefeuille.balance)}');
      
    } catch (e) {
      print('❌ Erreur reverseTransaction: $e');
      rethrow;
    }
  }
  
  // 5. Modifier le budget mensuel
  Future<void> updateMonthlyBudget(String userId, double newBudget) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(userId)
          .update({
            'monthlyBudget': newBudget,
            'lastUpdated': Timestamp.now(),
          });
      print('✅ Budget mis à jour: $newBudget');
    } catch (e) {
      print('❌ Erreur updateMonthlyBudget: $e');
      rethrow;
    }
  }
  
  // 6. Changer la devise
  Future<void> changeCurrency(String userId, String newCurrency) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(userId)
          .get();
      
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
        
        await _firestore
            .collection(_collectionName)
            .doc(userId)
            .update({
              'currency': newCurrency,
              'balance': newBalance,
              'lastUpdated': Timestamp.now(),
            });
        print('✅ Devise changée: $newCurrency');
      }
    } catch (e) {
      print('❌ Erreur changeCurrency: $e');
      rethrow;
    }
  }
  
  // 7. Réinitialiser le portefeuille
  Future<void> resetPortefeuille(String userId) async {
    try {
      final defaultPortefeuille = Portefeuille.newPortefeuille(userId: userId);
      await _firestore
          .collection(_collectionName)
          .doc(userId)
          .set(defaultPortefeuille.toMap());
      print('✅ Portefeuille réinitialisé');
    } catch (e) {
      print('❌ Erreur resetPortefeuille: $e');
      rethrow;
    }
  }
  
  // 8. Ajouter des fonds directement
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
      
      portefeuille.balance += amountToAdd;
      portefeuille.lastUpdated = DateTime.now();
      
      await _firestore
          .collection(_collectionName)
          .doc(userId)
          .set(portefeuille.toMap());
          
      print('✅ Fonds ajoutés: ${portefeuille.formatAmount(amountToAdd)}');
      
    } catch (e) {
      print('❌ Erreur addFunds: $e');
      rethrow;
    }
  }
  
  // 9. Vérifier si dépense possible
  Future<bool> canMakeExpense(String userId, double amount, String currency) async {
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
}