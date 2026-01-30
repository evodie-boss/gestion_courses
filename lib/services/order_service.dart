// lib/services/order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gestion_courses/gestion_boutiques/models/commande.dart';
import 'package:gestion_courses/gestion_portefeuille/services/portefeuille_service.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PortefeuilleService _portefeuilleService = PortefeuilleService();

  // Créer une commande
  Future<Commande> createOrder({
    required String boutiqueId,
    required List<Map<String, dynamic>> courses,
    required double total,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 1. Vérifier si le solde est suffisant
      final canPay = await _portefeuilleService.canMakeExpense(
        user.uid, 
        total, 
        'XOF'
      );
      
      if (!canPay) {
        throw Exception('Solde insuffisant pour cette commande');
      }

      // 2. Créer la commande
      final commandeId = DateTime.now().millisecondsSinceEpoch.toString();
      final commande = Commande(
        id: commandeId,
        userId: user.uid,
        boutiqueId: boutiqueId,
        courses: courses,
        total: total,
        statut: 'En cours',
        date: DateTime.now(),
      );

      // 3. Enregistrer la commande
      await _firestore
          .collection('commandes')
          .doc(commande.id)
          .set(commande.toMap());

      // 4. Créer la transaction de dépense
      await _createTransactionFromOrder(user.uid, commande);

      // 5. Diminuer le solde et incrémenter monthlyExpenses
      await _updatePortefeuilleAfterOrder(user.uid, commande);

      print('✅ Commande créée: ${commande.id} pour ${commande.total} FCFA');
      return commande;
      
    } catch (e) {
      print('❌ Erreur createOrder: $e');
      rethrow;
    }
  }

  // Créer une transaction pour la commande
  Future<void> _createTransactionFromOrder(
      String userId, Commande commande) async {
    try {
      final transactionId = DateTime.now().millisecondsSinceEpoch.toString();
      final transaction = {
        'id': transactionId,
        'userId': userId,
        'amount': commande.total,
        'type': 'depense',
        'category': 'commande',
        'description': 'Commande #${commande.id.substring(0, 8)}...',
        'date': Timestamp.now(),
        'currency': 'XOF',
        'commandeId': commande.id,
        'boutiqueId': commande.boutiqueId,
      };

      // CORRECTION: Utiliser transactionId qui est un String
      await _firestore
          .collection('transactions')
          .doc(transactionId)  // <-- String directement
          .set(transaction);
          
      print('✅ Transaction créée pour commande ${commande.id}');
    } catch (e) {
      print('❌ Erreur _createTransactionFromOrder: $e');
      rethrow;
    }
  }

  // Mettre à jour le portefeuille après commande
  Future<void> _updatePortefeuilleAfterOrder(
      String userId, Commande commande) async {
    try {
      final portefeuilleDoc = _firestore.collection('portefeuille').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(portefeuilleDoc);
        if (!snapshot.exists) {
          final newPortefeuille = {
            'userId': userId,
            'balance': 0.0,
            'monthlyBudget': 655960.0,
            'monthlyExpenses': commande.total,
            'currency': 'XOF',
            'exchangeRate': 655.96,
            'lastUpdated': Timestamp.now(),
          };
          transaction.set(portefeuilleDoc, newPortefeuille);
          print('📝 Portefeuille créé pour utilisateur $userId');
          return;
        }

        final data = snapshot.data()!;
        final currentBalance = (data['balance'] ?? 0.0).toDouble();
        final currentMonthlyExpenses = (data['monthlyExpenses'] ?? 0.0).toDouble();

        if (currentBalance < commande.total) {
          throw Exception('Solde insuffisant! Vous avez $currentBalance FCFA, besoin de ${commande.total} FCFA');
        }

        final newBalance = currentBalance - commande.total;
        final newMonthlyExpenses = currentMonthlyExpenses + commande.total;

        transaction.update(portefeuilleDoc, {
          'balance': newBalance,
          'monthlyExpenses': newMonthlyExpenses,
          'lastUpdated': Timestamp.now(),
        });

        print('💰 Portefeuille mis à jour:');
        print('   Solde: $currentBalance → $newBalance FCFA');
        print('   Dépenses: $currentMonthlyExpenses → $newMonthlyExpenses FCFA');
      });
      
    } catch (e) {
      print('❌ Erreur _updatePortefeuilleAfterOrder: $e');
      rethrow;
    }
  }

  // Récupérer les commandes d'un utilisateur
  Stream<List<Commande>> getUserOrders(String userId) {
    return _firestore
        .collection('commandes')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Commande.fromMap(doc.data()))
          .toList();
    });
  }

  // Mettre à jour le statut d'une commande
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore
          .collection('commandes')
          .doc(orderId)
          .update({
            'statut': newStatus,
            'lastUpdated': Timestamp.now(),
          });
      print('🔄 Statut de commande $orderId mis à jour: $newStatus');
    } catch (e) {
      print('❌ Erreur updateOrderStatus: $e');
      rethrow;
    }
  }

  // Récupérer une commande par ID
  Future<Commande?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('commandes').doc(orderId).get();
      if (doc.exists) {
        return Commande.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Erreur getOrderById: $e');
      return null;
    }
  }

  // Annuler une commande (et rembourser)
  Future<void> cancelOrder(String orderId) async {
    try {
      final order = await getOrderById(orderId);
      if (order == null) throw Exception('Commande non trouvée');

      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      if (order.userId != user.uid) {
        throw Exception('Vous n\'êtes pas autorisé à annuler cette commande');
      }

      // Rembourser le portefeuille
      await _refundOrder(order);

      // Mettre à jour le statut
      await updateOrderStatus(orderId, 'Annulée');

      print('🔄 Commande $orderId annulée et remboursée');
    } catch (e) {
      print('❌ Erreur cancelOrder: $e');
      rethrow;
    }
  }

  // Rembourser une commande
  Future<void> _refundOrder(Commande order) async {
    try {
      final portefeuilleDoc = _firestore.collection('portefeuille').doc(order.userId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(portefeuilleDoc);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final currentBalance = (data['balance'] ?? 0.0).toDouble();
        final currentMonthlyExpenses = (data['monthlyExpenses'] ?? 0.0).toDouble();

        final newBalance = currentBalance + order.total;
        final newMonthlyExpenses = currentMonthlyExpenses - order.total;

        transaction.update(portefeuilleDoc, {
          'balance': newBalance,
          'monthlyExpenses': newMonthlyExpenses < 0 ? 0.0 : newMonthlyExpenses,
          'lastUpdated': Timestamp.now(),
        });
      });

      // Créer transaction de remboursement
      final refundTransactionId = DateTime.now().millisecondsSinceEpoch.toString();
      final refundTransaction = {
        'id': refundTransactionId,
        'userId': order.userId,
        'amount': order.total,
        'type': 'ajout',
        'category': 'remboursement',
        'description': 'Remboursement commande #${order.id.substring(0, 8)}...',
        'date': Timestamp.now(),
        'currency': 'XOF',
        'commandeId': order.id,
      };

      // CORRECTION: Utiliser refundTransactionId qui est un String
      await _firestore
          .collection('transactions')
          .doc(refundTransactionId)  // <-- String directement
          .set(refundTransaction);

      print('💰 Remboursement effectué pour commande ${order.id}');
      
    } catch (e) {
      print('❌ Erreur _refundOrder: $e');
      rethrow;
    }
  }

  // Statistiques des commandes
  Future<Map<String, dynamic>> getOrderStats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('commandes')
          .where('userId', isEqualTo: userId)
          .get();

      final orders = snapshot.docs.map((doc) => Commande.fromMap(doc.data())).toList();
      
      double totalSpent = 0;
      int completedCount = 0;
      int pendingCount = 0;
      int cancelledCount = 0;

      for (var order in orders) {
        totalSpent += order.total;
        
        switch (order.statut.toLowerCase()) {
          case 'livrée':
          case 'terminée':
            completedCount++;
            break;
          case 'annulée':
            cancelledCount++;
            break;
          default:
            pendingCount++;
        }
      }

      return {
        'totalOrders': orders.length,
        'totalSpent': totalSpent,
        'completedCount': completedCount,
        'pendingCount': pendingCount,
        'cancelledCount': cancelledCount,
        'averageOrderValue': orders.isNotEmpty ? totalSpent / orders.length : 0,
      };
    } catch (e) {
      print('❌ Erreur getOrderStats: $e');
      return {
        'totalOrders': 0,
        'totalSpent': 0.0,
        'completedCount': 0,
        'pendingCount': 0,
        'cancelledCount': 0,
        'averageOrderValue': 0.0,
      };
    }
  }

  // Méthode utilitaire pour formater les montants
  String formatAmount(double amount) {
    return '${amount.toStringAsFixed(0)} FCFA';
  }
}