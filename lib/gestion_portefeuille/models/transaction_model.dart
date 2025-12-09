// lib/gestion_portefeuille/models/transaction_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  String id;
  String userId;
  String type; // 'depense' ou 'ajout'
  double amount;
  String description;
  DateTime date;
  DateTime createdAt;
  String currency; // 'EUR' ou 'XOF' ← NOUVEAU CHAMP

  Transaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
    required this.currency, // ← AJOUTÉ
  });

  // Constructeur pour nouvelle transaction
  Transaction.newTransaction({
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.currency = 'XOF', // ← AJOUTÉ, XOF par défaut
  }) : id = '',
      createdAt = DateTime.now();

  // Convertir Transaction -> Map (pour Firestore)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'amount': amount,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'currency': currency, // ← AJOUTÉ
    };
  }

  // Convertir Map -> Transaction (depuis Firestore)
  factory Transaction.fromMap(Map<String, dynamic> map, String documentId) {
    return Transaction(
      id: documentId,
      userId: map['userId'] ?? '',
      type: map['type'] ?? 'depense',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      currency: map['currency'] ?? 'XOF', // ← AJOUTÉ
    );
  }

  // Getter pour afficher le type en français
  String get typeDisplay {
    return type == 'depense' ? 'Dépense' : 'Ajout';
  }

  // Getter pour la couleur selon le type
  String get colorType {
    return type == 'depense' ? '#FF5252' : '#4CAF50';
  }

  // Getter pour l'icône
  String get icon {
    return type == 'depense' ? '📉' : '📈';
  }

  // Getter pour le symbole de devise ← NOUVEAU
  String get currencySymbol {
    return currency == 'EUR' ? '€' : 'FCFA';
  }

  // Formater le montant avec devise ← NOUVEAU
  String get formattedAmount {
    if (currency == 'XOF') {
      return '${amount.toStringAsFixed(0)} FCFA';
    } else {
      return '${amount.toStringAsFixed(2)} €';
    }
  }
}

// Types disponibles
const List<String> transactionTypes = ['depense', 'ajout'];