// lib/services/notification_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_courses/constants/app_colors.dart';

/// Modèle de notification
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.info,
      ),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      data: map['data'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'data': data,
    };
  }
}

enum NotificationType {
  info,
  wallet,      // Notification liée au portefeuille
  order,       // Notification liée aux commandes
  warning,     // Avertissement
  success,     // Succès
}

/// Service de gestion des notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Seuil de solde faible (en FCFA)
  static const double lowBalanceThreshold = 10000.0;

  // Stream controllers pour les notifications en temps réel
  final _walletNotificationsController =
      StreamController<AppNotification>.broadcast();
  final _orderNotificationsController =
      StreamController<AppNotification>.broadcast();
  final _notificationEventsController =
      StreamController<AppNotification>.broadcast();

  // Streams publics
  Stream<AppNotification> get walletNotifications =>
      _walletNotificationsController.stream;
  Stream<AppNotification> get orderNotifications => _orderNotificationsController.stream;
  Stream<AppNotification> get notificationEvents =>
      _notificationEventsController.stream;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _walletSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _createdBoutiquesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _ownedBoutiquesSubscription;

  String? _activeUserId;
  double? _lastKnownBalance;
  bool _walletAlertActive = false;
  final Set<String> _processedOrderIds = <String>{};
  Set<String> _createdBoutiqueIds = <String>{};
  Set<String> _ownedBoutiqueIds = <String>{};

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .doc(userId)
        .collection('user_notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> startMonitoring(String userId) async {
    if (_activeUserId == userId) return;

    await stopMonitoring();
    _activeUserId = userId;

    await _seedExistingOrders();
    await _refreshOwnedBoutiques(userId);
    _listenToOwnedBoutiques(userId);
    _listenToWallet(userId);
    _listenToOrders();
  }

  Future<void> stopMonitoring() async {
    await _walletSubscription?.cancel();
    await _ordersSubscription?.cancel();
    await _createdBoutiquesSubscription?.cancel();
    await _ownedBoutiquesSubscription?.cancel();

    _walletSubscription = null;
    _ordersSubscription = null;
    _createdBoutiquesSubscription = null;
    _ownedBoutiquesSubscription = null;
    _activeUserId = null;
    _lastKnownBalance = null;
    _walletAlertActive = false;
    _processedOrderIds.clear();
    _createdBoutiqueIds = <String>{};
    _ownedBoutiqueIds = <String>{};
  }

  // Méthode pour vérifier le solde et générer une notification si nécessaire
  Future<void> checkWalletBalance(String userId) async {
    try {
      final walletDoc = await _firestore
          .collection('portefeuille')
          .doc(userId)
          .get();

      if (walletDoc.exists) {
        final balance = (walletDoc.data()?['balance'] ?? 0.0).toDouble();
        
        if (balance <= lowBalanceThreshold) {
          final notification = AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Solde faible 💰',
            message: balance == 0
                ? 'Votre portefeuille est vide! Rechargez-le pour continuer vos courses.'
                : 'Votre solde est faible (${balance.toStringAsFixed(0)}FCFA). Pensez à le recharger.',
            type: NotificationType.wallet,
            timestamp: DateTime.now(),
            data: {'balance': balance, 'threshold': lowBalanceThreshold},
          );
          
          _walletNotificationsController.add(notification);
          await _saveNotification(userId, notification);
        }
      }
    } catch (e) {
      print('❌ Erreur checkWalletBalance: $e');
    }
  }

  Future<void> _seedExistingOrders() async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      _processedOrderIds.addAll(snapshot.docs.map((doc) => doc.id));
    } catch (e) {
      print('❌ Erreur _seedExistingOrders: $e');
    }
  }

  Future<void> _refreshOwnedBoutiques(String userId) async {
    try {
      final results = await Future.wait([
        _firestore
            .collection('boutiques')
            .where('createdBy', isEqualTo: userId)
            .get(),
        _firestore
            .collection('boutiques')
            .where('ownerId', isEqualTo: userId)
            .get(),
      ]);

      _createdBoutiqueIds = results[0].docs.map((doc) => doc.id).toSet();
      _ownedBoutiqueIds = results[1].docs.map((doc) => doc.id).toSet();
    } catch (e) {
      print('❌ Erreur _refreshOwnedBoutiques: $e');
    }
  }

  void _listenToOwnedBoutiques(String userId) {
    _createdBoutiquesSubscription = _firestore
        .collection('boutiques')
        .where('createdBy', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _createdBoutiqueIds = snapshot.docs.map((doc) => doc.id).toSet();
    });

    _ownedBoutiquesSubscription = _firestore
        .collection('boutiques')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _ownedBoutiqueIds = snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  void _listenToWallet(String userId) {
    _walletSubscription = _firestore
        .collection('portefeuille')
        .doc(userId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final balance = (snapshot.data()?['balance'] ?? 0.0).toDouble();
      final isLowBalance = balance <= lowBalanceThreshold;
      final shouldNotify = isLowBalance &&
          (!_walletAlertActive ||
              (_lastKnownBalance != null &&
                  _lastKnownBalance! > lowBalanceThreshold));

      _lastKnownBalance = balance;
      _walletAlertActive = isLowBalance;

      if (!shouldNotify) return;

      final notification = AppNotification(
        id: 'wallet_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Solde faible',
        message: balance <= 0
            ? 'Votre portefeuille est vide. Rechargez-le pour continuer.'
            : 'Votre solde est faible: ${balance.toStringAsFixed(0)} FCFA.',
        type: NotificationType.wallet,
        timestamp: DateTime.now(),
        data: {'balance': balance},
      );

      _walletNotificationsController.add(notification);
      _notificationEventsController.add(notification);
      await _saveNotification(userId, notification);
    });
  }

  void _listenToOrders() {
    _ordersSubscription = _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) async {
      final activeUserId = _activeUserId;
      if (activeUserId == null) return;

      final ownedBoutiqueIds = {..._createdBoutiqueIds, ..._ownedBoutiqueIds};
      if (ownedBoutiqueIds.isEmpty) return;

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final doc = change.doc;
        if (_processedOrderIds.contains(doc.id)) continue;
        _processedOrderIds.add(doc.id);

        final data = doc.data();
        final boutiqueId = data?['boutiqueId']?.toString();
        if (boutiqueId == null || !ownedBoutiqueIds.contains(boutiqueId)) {
          continue;
        }

        final createdAt = (data?['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null &&
            DateTime.now().difference(createdAt).inHours > 12) {
          continue;
        }

        final total = (data?['total'] as num?)?.toDouble() ?? 0.0;
        final boutiqueName = data?['boutiqueName']?.toString();

        final notification = AppNotification(
          id: 'order_${doc.id}',
          title: 'Nouvelle commande',
          message: boutiqueName != null && boutiqueName.isNotEmpty
              ? 'Nouvelle commande pour $boutiqueName: ${total.toStringAsFixed(0)} FCFA.'
              : 'Vous avez reçu une commande de ${total.toStringAsFixed(0)} FCFA.',
          type: NotificationType.order,
          timestamp: createdAt ?? DateTime.now(),
          data: {
            'orderId': doc.id,
            'boutiqueId': boutiqueId,
            'total': total,
          },
        );

        _orderNotificationsController.add(notification);
        _notificationEventsController.add(notification);
        await _saveNotification(activeUserId, notification);
      }
    });
  }

  // Sauvegarder la notification dans Firestore
  Future<void> _saveNotification(String userId, AppNotification notification) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('user_notifications')
          .doc(notification.id)
          .set(notification.toMap());
    } catch (e) {
      print('❌ Erreur _saveNotification: $e');
    }
  }

  // Récupérer les notifications non lues
  Future<List<AppNotification>> getUnreadNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('user_notifications')
          .where('isRead', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('❌ Erreur getUnreadNotifications: $e');
      return [];
    }
  }

  // Marquer une notification comme lue
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('user_notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('❌ Erreur markAsRead: $e');
    }
  }

  // Marquer toutes les notifications comme lues
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('user_notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('❌ Erreur markAllAsRead: $e');
    }
  }

  // Obtenir le nombre de notifications non lues
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('user_notifications')
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Erreur getUnreadCount: $e');
      return 0;
    }
  }

  // Afficher une notification locale (SnackBar)
  static void showLocalNotification(BuildContext context, AppNotification notification) {
    Color backgroundColor;
    IconData icon;

    switch (notification.type) {
      case NotificationType.wallet:
        backgroundColor = Colors.amber.shade700;
        icon = Icons.account_balance_wallet;
        break;
      case NotificationType.order:
        backgroundColor = AppColors.tropicalTeal;
        icon = Icons.shopping_cart;
        break;
      case NotificationType.warning:
        backgroundColor = Colors.orange;
        icon = Icons.warning_amber_rounded;
        break;
      case NotificationType.success:
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      default:
        backgroundColor = AppColors.tropicalTeal;
        icon = Icons.info;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void dispose() {
    stopMonitoring();
    _walletNotificationsController.close();
    _orderNotificationsController.close();
    _notificationEventsController.close();
  }
}
