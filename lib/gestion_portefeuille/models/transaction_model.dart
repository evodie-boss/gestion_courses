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
  String currency; // 'EUR' ou 'XOF'

  Transaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
    required this.currency,
  });

  // Constructeur pour nouvelle transaction
  Transaction.newTransaction({
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.currency = 'XOF',
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
      'currency': currency,
    };
  }

  // Convertir Map -> Transaction (depuis Firestore) - CORRIGÉ
  factory Transaction.fromMap(Map<String, dynamic> map, String documentId) {
    // Fonction pour parser les dates de manière sécurisée
    DateTime parseDate(dynamic dateField) {
      if (dateField is Timestamp) {
        return dateField.toDate();
      } else if (dateField is DateTime) {
        return dateField;
      } else if (dateField is String) {
        try {
          return DateTime.parse(dateField);
        } catch (e) {
          print('⚠️ Erreur parsing date string: $dateField');
        }
      } else if (dateField != null) {
        print('⚠️ Type de date inattendu: ${dateField.runtimeType}');
      }
      // Fallback: date actuelle
      return DateTime.now();
    }

    return Transaction(
      id: documentId,
      userId: map['userId']?.toString() ?? '',
      type: map['type']?.toString() ?? 'depense',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description']?.toString() ?? '',
      date: parseDate(map['date']),
      createdAt: parseDate(map['createdAt']),
      currency: map['currency']?.toString() ?? 'XOF',
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

  // Getter pour le symbole de devise
  String get currencySymbol {
    return currency == 'EUR' ? '€' : 'FCFA';
  }

  // Formater le montant avec devise
  String get formattedAmount {
    if (currency == 'XOF') {
      return '${amount.toStringAsFixed(0)} FCFA';
    } else {
      return '${amount.toStringAsFixed(2)} €';
    }
  }

  // Méthode pour dupliquer une transaction
  Transaction copyWith({
    String? id,
    String? userId,
    String? type,
    double? amount,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    String? currency,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      currency: currency ?? this.currency,
    );
  }

  // Méthode pour comparer deux transactions
  bool isSameAs(Transaction other) {
    return id == other.id &&
        userId == other.userId &&
        type == other.type &&
        amount == other.amount &&
        description == other.description &&
        date.isAtSameMomentAs(other.date) &&
        createdAt.isAtSameMomentAs(other.createdAt) &&
        currency == other.currency;
  }
}

// Types disponibles
const List<String> transactionTypes = ['depense', 'ajout'];