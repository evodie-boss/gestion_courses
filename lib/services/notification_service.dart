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
  static const double lowBalanceThreshold = 10000.0; // 10 000FCFA
  
  // Stream controllers pour les notifications en temps réel
  final _walletNotificationsController = StreamController<AppNotification>.broadcast();
  final _orderNotificationsController = StreamController<AppNotification>.broadcast();
  
  // Streams publics
  Stream<AppNotification> get walletNotifications => _walletNotificationsController.stream;
  Stream<AppNotification> get orderNotifications => _orderNotificationsController.stream;

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

  // Méthode pour écouter les nouvelles commandes
  Stream<AppNotification> listenForNewOrders(String userId) {
    return _firestore
        .collection('commandes')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final latestOrder = snapshot.docs.first;
        final orderData = latestOrder.data();
        
        // Vérifier si c'est une nouvelle commande (créée récemment)
        final orderDate = (orderData['date'] as Timestamp?)?.toDate();
        if (orderDate != null) {
          final now = DateTime.now();
          final difference = now.difference(orderDate);
          
          // Si la commande a moins de 5 minutes, c'est une nouvelle commande
          if (difference.inMinutes < 5) {
            final notification = AppNotification(
              id: latestOrder.id,
              title: 'Nouvelle commande 🛒',
              message: 'Vous avez une nouvelle commande de ${(orderData['total'] ?? 0).toStringAsFixed(0)}FCFA',
              type: NotificationType.order,
              timestamp: orderDate,
              data: {
                'orderId': latestOrder.id,
                'total': orderData['total'],
                'boutiqueId': orderData['boutiqueId'],
              },
            );
            
            await _saveNotification(userId, notification);
            return notification;
          }
        }
      }
      return AppNotification(
        id: '',
        title: '',
        message: '',
        type: NotificationType.info,
        timestamp: DateTime.now(),
      );
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
    _walletNotificationsController.close();
    _orderNotificationsController.close();
  }
}