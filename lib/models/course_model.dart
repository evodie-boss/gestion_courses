// lib/course_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum CourseStatus { todo, done }
enum CoursePriority { high, medium, low }

class Course {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double amount;
  final CoursePriority priority;
  final CourseStatus status;
  final DateTime createdAt;
  final DateTime? dueDate;

  Course({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.amount,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.dueDate,
  });

  factory Course.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    // createdAt may be Timestamp or absent
    DateTime created;
    final createdRaw = data['createdAt'];
    if (createdRaw is Timestamp) {
      created = createdRaw.toDate();
    } else if (createdRaw is DateTime) {
      created = createdRaw;
    } else {
      created = DateTime.now();
    }

    DateTime? due;
    final dueRaw = data['dueDate'];
    if (dueRaw is Timestamp) {
      due = dueRaw.toDate();
    } else if (dueRaw is DateTime) {
      due = dueRaw;
    } else {
      due = null;
    }

    return Course(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      priority: _stringToPriority(data['priority'] ?? 'low'),
      status: _stringToStatus(data['status'] ?? 'todo'),
      createdAt: created,
      dueDate: due,
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestampForCreated = false}) {
    final map = <String, dynamic>{
      'userId': userId,
      'title': title,
      'description': description,
      'amount': amount,
      'priority': priority.name,
      'status': status.name,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
    };

    if (useServerTimestampForCreated) {
      map['createdAt'] = FieldValue.serverTimestamp();
    } else {
      map['createdAt'] = Timestamp.fromDate(createdAt);
    }

    return map;
  }

  static CoursePriority _stringToPriority(String value) {
    switch (value) {
      case 'high':
        return CoursePriority.high;
      case 'medium':
        return CoursePriority.medium;
      case 'low':
      default:
        return CoursePriority.low;
    }
  }

  static CourseStatus _stringToStatus(String value) {
    switch (value) {
      case 'done':
        return CourseStatus.done;
      case 'todo':
      default:
        return CourseStatus.todo;
    }
  }

  Course copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    double? amount,
    CoursePriority? priority,
    CourseStatus? status,
    DateTime? createdAt,
    DateTime? dueDate,
  }) {
    return Course(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}

// ============================================
// EXTENSIONS ET UTILITAIRES POUR COURSEPRIORITY
// ============================================

/// Extension pour ajouter des fonctionnalités à l'énumération CoursePriority
extension CoursePriorityExtension on CoursePriority {
  /// Retourne le nom d'affichage en français
  String get displayName {
    switch (this) {
      case CoursePriority.high:
        return 'Élevée';
      case CoursePriority.medium:
        return 'Moyenne';
      case CoursePriority.low:
        return 'Faible';
    }
  }

  /// Retourne le nom abrégé
  String get shortName {
    switch (this) {
      case CoursePriority.high:
        return 'HIGH';
      case CoursePriority.medium:
        return 'MED';
      case CoursePriority.low:
        return 'LOW';
    }
  }

  /// Retourne un emoji représentatif
  String get emoji {
    switch (this) {
      case CoursePriority.high:
        return '🔥';
      case CoursePriority.medium:
        return '⚡';
      case CoursePriority.low:
        return '🌱';
    }
  }

  /// Retourne la description détaillée
  String get description {
    switch (this) {
      case CoursePriority.high:
        return 'Priorité élevée - À traiter en premier';
      case CoursePriority.medium:
        return 'Priorité moyenne - À traiter rapidement';
      case CoursePriority.low:
        return 'Priorité faible - Peut attendre';
    }
  }

  /// Retourne la couleur associée à cette priorité
  Color get color {
    switch (this) {
      case CoursePriority.high:
        return const Color(0xFFEF4444); // Rouge
      case CoursePriority.medium:
        return const Color(0xFFF59E0B); // Orange ambre
      case CoursePriority.low:
        return const Color(0xFF10B981); // Vert émeraude
    }
  }

  /// Retourne la couleur de fond (plus claire)
  Color get backgroundColor {
    switch (this) {
      case CoursePriority.high:
        return const Color(0xFFFEE2E2); // Rouge clair
      case CoursePriority.medium:
        return const Color(0xFFFEF3C7); // Orange clair
      case CoursePriority.low:
        return const Color(0xFFD1FAE5); // Vert clair
    }
  }

  /// Retourne l'icône associée
  IconData get icon {
    switch (this) {
      case CoursePriority.high:
        return Icons.whatshot;
      case CoursePriority.medium:
        return Icons.trending_up;
      case CoursePriority.low:
        return Icons.trending_down;
    }
  }

  /// Retourne l'ordre numérique (0 = haute priorité)
  int get order {
    switch (this) {
      case CoursePriority.high:
        return 0;
      case CoursePriority.medium:
        return 1;
      case CoursePriority.low:
        return 2;
    }
  }

  /// Vérifie si c'est une priorité haute
  bool get isHigh => this == CoursePriority.high;

  /// Vérifie si c'est une priorité moyenne
  bool get isMedium => this == CoursePriority.medium;

  /// Vérifie si c'est une priorité basse
  bool get isLow => this == CoursePriority.low;

  /// Retourne la priorité suivante dans l'ordre (pour cycle)
  CoursePriority get next {
    final index = (order + 1) % CoursePriority.values.length;
    return CoursePriority.values[index];
  }

  /// Retourne la priorité précédente dans l'ordre (pour cycle)
  CoursePriority get previous {
    final index = (order - 1 + CoursePriority.values.length) % CoursePriority.values.length;
    return CoursePriority.values[index];
  }

  /// Convertit en valeur pour le slider (0-2)
  double get sliderValue => order.toDouble();

  /// Crée une priorité à partir d'une valeur de slider
  static CoursePriority fromSliderValue(double value) {
    final index = value.round();
    if (index >= 0 && index < CoursePriority.values.length) {
      return CoursePriority.values[index];
    }
    return CoursePriority.low;
  }
}

// ============================================
// EXTENSIONS ET UTILITAIRES POUR COURSESTATUS
// ============================================

/// Extension pour ajouter des fonctionnalités à l'énumération CourseStatus
extension CourseStatusExtension on CourseStatus {
  /// Retourne le nom d'affichage en français
  String get displayName {
    switch (this) {
      case CourseStatus.todo:
        return 'À faire';
      case CourseStatus.done:
        return 'Terminé';
    }
  }

  /// Retourne la couleur associée à ce statut
  Color get color {
    switch (this) {
      case CourseStatus.done:
        return const Color(0xFF10B981); // Vert
      case CourseStatus.todo:
        return const Color(0xFF6B7280); // Gris
    }
  }

  /// Retourne l'icône associée
  IconData get icon {
    switch (this) {
      case CourseStatus.done:
        return Icons.check_circle;
      case CourseStatus.todo:
        return Icons.radio_button_unchecked;
    }
  }

  /// Vérifie si la tâche est terminée
  bool get isDone => this == CourseStatus.done;

  /// Vérifie si la tâche est à faire
  bool get isTodo => this == CourseStatus.todo;
}

// ============================================
// CLASSE POUR LES STATISTIQUES DE COURSE
// ============================================

/// Classe pour stocker les statistiques d'un groupe de courses
class CourseStats {
  final int total;
  final int completed;
  final double totalAmount;
  final double pendingAmount;

  CourseStats({
    required this.total,
    required this.completed,
    required this.totalAmount,
    required this.pendingAmount,
  });

  /// Pourcentage de complétion
  double get completionPercentage {
    return total > 0 ? (completed / total) * 100 : 0;
  }

  /// Nombre de courses en attente
  int get pending {
    return total - completed;
  }

  /// Montant total complété
  double get completedAmount {
    return totalAmount - pendingAmount;
  }

  /// Pourcentage du montant complété
  double get amountCompletionPercentage {
    return totalAmount > 0 ? (completedAmount / totalAmount) * 100 : 0;
  }

  /// Formate le pourcentage de complétion
  String get formattedCompletionPercentage {
    return '${completionPercentage.toStringAsFixed(1)}%';
  }

  /// Formate le pourcentage du montant complété
  String get formattedAmountCompletionPercentage {
    return '${amountCompletionPercentage.toStringAsFixed(1)}%';
  }

  /// Crée une copie avec les valeurs mises à jour
  CourseStats copyWith({
    int? total,
    int? completed,
    double? totalAmount,
    double? pendingAmount,
  }) {
    return CourseStats(
      total: total ?? this.total,
      completed: completed ?? this.completed,
      totalAmount: totalAmount ?? this.totalAmount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
    );
  }

  /// Ajoute les statistiques d'une autre instance
  CourseStats operator +(CourseStats other) {
    return CourseStats(
      total: total + other.total,
      completed: completed + other.completed,
      totalAmount: totalAmount + other.totalAmount,
      pendingAmount: pendingAmount + other.pendingAmount,
    );
  }
}

/// Statistiques par priorité
class PriorityStats {
  final Map<CoursePriority, CourseStats> stats;

  PriorityStats(this.stats);

  /// Récupère les statistiques pour une priorité spécifique
  CourseStats getStatsForPriority(CoursePriority priority) {
    return stats[priority] ?? CourseStats(
      total: 0,
      completed: 0,
      totalAmount: 0,
      pendingAmount: 0,
    );
  }

  /// Total général toutes priorités confondues
  CourseStats get overall {
    return CourseStats(
      total: stats.values.fold(0, (sum, stat) => sum + stat.total),
      completed: stats.values.fold(0, (sum, stat) => sum + stat.completed),
      totalAmount: stats.values.fold(0.0, (sum, stat) => sum + stat.totalAmount),
      pendingAmount: stats.values.fold(0.0, (sum, stat) => sum + stat.pendingAmount),
    );
  }
}