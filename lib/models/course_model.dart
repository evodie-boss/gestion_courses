// lib/models/course_model.dart
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
  
  final int quantity; // Quantité
  final double unitPrice; // Prix unitaire
  final String unit; // Unité
  final bool isEssential; // Article essentiel

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
    this.quantity = 1,
    this.unitPrice = 0,
    this.unit = 'pièce',
    this.isEssential = false,
  });

  // Getter pour calculer le montant à partir du prix unitaire et de la quantité
  double get calculatedAmount => unitPrice * quantity;

  factory Course.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Gestion de createdAt
    DateTime created;
    final createdRaw = data['createdAt'];
    if (createdRaw is Timestamp) {
      created = createdRaw.toDate();
    } else if (createdRaw is DateTime) {
      created = createdRaw;
    } else {
      created = DateTime.now();
    }

    // Gestion de dueDate
    DateTime? due;
    final dueRaw = data['dueDate'];
    if (dueRaw is Timestamp) {
      due = dueRaw.toDate();
    } else if (dueRaw is DateTime) {
      due = dueRaw;
    } else {
      due = null;
    }

    // Récupération des champs avec valeurs par défaut
    final quantity = data['quantity'] != null ? (data['quantity'] as num).toInt() : 1;
    final unitPrice = (data['unitPrice'] ?? 0).toDouble();
    final unit = data['unit']?.toString() ?? 'pièce';
    final isEssential = data['isEssential'] ?? false;

    // Calcul du montant (privilégier amount stocké, sinon calculer)
    double amount;
    final storedAmount = data['amount'];
    if (storedAmount != null) {
      amount = (storedAmount as num).toDouble();
    } else {
      // Calculer à partir du prix unitaire et de la quantité
      amount = unitPrice * quantity;
    }

    return Course(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      amount: amount,
      priority: _stringToPriority(data['priority']?.toString() ?? 'low'),
      status: _stringToStatus(data['status']?.toString() ?? 'todo'),
      createdAt: created,
      dueDate: due,
      quantity: quantity,
      unitPrice: unitPrice,
      unit: unit,
      isEssential: isEssential,
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestampForCreated = false}) {
    final map = <String, dynamic>{
      'userId': userId,
      'title': title,
      'description': description,
      'amount': amount, // On stocke le montant total
      'priority': priority.name,
      'status': status.name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'unit': unit,
      'isEssential': isEssential,
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
    switch (value.toLowerCase()) {
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
    switch (value.toLowerCase()) {
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
    int? quantity,
    double? unitPrice,
    String? unit,
    bool? isEssential,
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
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      isEssential: isEssential ?? this.isEssential,
    );
  }

  // Méthode pour ajuster le prix (pour l'optimisation budgétaire)
  Course adjustPrice(double percentage) {
    if (isEssential || percentage <= 0) return this;
    
    final newUnitPrice = unitPrice * (1 - percentage / 100);
    final newAmount = newUnitPrice * quantity;
    
    return copyWith(
      unitPrice: newUnitPrice,
      amount: newAmount,
    );
  }

  // Méthode pour ajuster la quantité (pour l'optimisation budgétaire)
  Course adjustQuantity(int newQuantity) {
    if (newQuantity <= 0) return this;
    
    final newAmount = unitPrice * newQuantity;
    
    return copyWith(
      quantity: newQuantity,
      amount: newAmount,
    );
  }

  @override
  String toString() {
    return 'Course{id: $id, title: $title, amount: $amount, quantity: $quantity, unitPrice: $unitPrice}';
  }
}

// ============================================
// EXTENSIONS ET UTILITAIRES POUR COURSEPRIORITY
// ============================================

extension CoursePriorityExtension on CoursePriority {
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

  Color get color {
    switch (this) {
      case CoursePriority.high:
        return const Color(0xFFEF4444);
      case CoursePriority.medium:
        return const Color(0xFFF59E0B);
      case CoursePriority.low:
        return const Color(0xFF10B981);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case CoursePriority.high:
        return const Color(0xFFFEE2E2);
      case CoursePriority.medium:
        return const Color(0xFFFEF3C7);
      case CoursePriority.low:
        return const Color(0xFFD1FAE5);
    }
  }

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

  bool get isHigh => this == CoursePriority.high;
  bool get isMedium => this == CoursePriority.medium;
  bool get isLow => this == CoursePriority.low;

  CoursePriority get next {
    final index = (order + 1) % CoursePriority.values.length;
    return CoursePriority.values[index];
  }

  CoursePriority get previous {
    final index =
        (order - 1 + CoursePriority.values.length) % CoursePriority.values.length;
    return CoursePriority.values[index];
  }

  double get sliderValue => order.toDouble();

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

extension CourseStatusExtension on CourseStatus {
  String get displayName {
    switch (this) {
      case CourseStatus.todo:
        return 'À faire';
      case CourseStatus.done:
        return 'Terminé';
    }
  }

  Color get color {
    switch (this) {
      case CourseStatus.done:
        return const Color(0xFF10B981);
      case CourseStatus.todo:
        return const Color(0xFF6B7280);
    }
  }

  IconData get icon {
    switch (this) {
      case CourseStatus.done:
        return Icons.check_circle;
      case CourseStatus.todo:
        return Icons.radio_button_unchecked;
    }
  }

  bool get isDone => this == CourseStatus.done;
  bool get isTodo => this == CourseStatus.todo;
}

// ============================================
// CLASSE POUR LES STATISTIQUES DE COURSE
// ============================================

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

  double get completionPercentage {
    return total > 0 ? (completed / total) * 100 : 0;
  }

  int get pending => total - completed;

  double get completedAmount => totalAmount - pendingAmount;

  double get amountCompletionPercentage {
    return totalAmount > 0 ? (completedAmount / totalAmount) * 100 : 0;
  }

  String get formattedCompletionPercentage {
    return '${completionPercentage.toStringAsFixed(1)}%';
  }

  String get formattedAmountCompletionPercentage {
    return '${amountCompletionPercentage.toStringAsFixed(1)}%';
  }

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

  CourseStats operator +(CourseStats other) {
    return CourseStats(
      total: total + other.total,
      completed: completed + other.completed,
      totalAmount: totalAmount + other.totalAmount,
      pendingAmount: pendingAmount + other.pendingAmount,
    );
  }
}

class PriorityStats {
  final Map<CoursePriority, CourseStats> stats;

  PriorityStats(this.stats);

  CourseStats getStatsForPriority(CoursePriority priority) {
    return stats[priority] ??
        CourseStats(total: 0, completed: 0, totalAmount: 0, pendingAmount: 0);
  }

  CourseStats get overall {
    return CourseStats(
      total: stats.values.fold(0, (sum, stat) => sum + stat.total),
      completed: stats.values.fold(0, (sum, stat) => sum + stat.completed),
      totalAmount: stats.values.fold(0.0, (sum, stat) => sum + stat.totalAmount),
      pendingAmount: stats.values.fold(0.0, (sum, stat) => sum + stat.pendingAmount),
    );
  }
}

// ============================================
// UTILITAIRES POUR L'OPTIMISATION BUDGÉTAIRE
// ============================================

class BudgetOptimizer {
  /// Calcule le budget nécessaire pour toutes les courses
  static double calculateRequiredBudget(List<Course> courses) {
    return courses.fold(0.0, (sum, course) => sum + course.amount);
  }

  /// Filtre les courses par priorité
  static List<Course> filterByPriority(List<Course> courses, CoursePriority priority) {
    return courses.where((course) => course.priority == priority).toList();
  }

  /// Récupère uniquement les courses essentielles
  static List<Course> getEssentialCourses(List<Course> courses) {
    return courses.where((course) => course.isEssential).toList();
  }

  /// Récupère uniquement les courses non-essentielles
  static List<Course> getNonEssentialCourses(List<Course> courses) {
    return courses.where((course) => !course.isEssential).toList();
  }

  /// Trie les courses par importance (essentielles d'abord, puis par priorité)
  static List<Course> sortByImportance(List<Course> courses) {
    final sorted = List<Course>.from(courses);
    sorted.sort((a, b) {
      // Essentiels d'abord
      if (a.isEssential && !b.isEssential) return -1;
      if (!a.isEssential && b.isEssential) return 1;
      
      // Puis par priorité
      if (a.priority.order != b.priority.order) {
        return a.priority.order.compareTo(b.priority.order);
      }
      
      // Puis par date limite (les plus urgentes d'abord)
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      
      return 0;
    });
    return sorted;
  }

  /// Vérifie si le budget est suffisant pour les courses
  static BudgetCheckResult checkBudget(
    List<Course> courses,
    double availableBudget,
  ) {
    final requiredBudget = calculateRequiredBudget(courses);
    final deficit = requiredBudget - availableBudget;
    final essentialCourses = getEssentialCourses(courses);
    final essentialBudget = calculateRequiredBudget(essentialCourses);
    
    return BudgetCheckResult(
      requiredBudget: requiredBudget,
      availableBudget: availableBudget,
      deficit: deficit,
      essentialBudget: essentialBudget,
      hasEnoughForEssentials: availableBudget >= essentialBudget,
      hasEnoughForAll: availableBudget >= requiredBudget,
    );
  }
}

class BudgetCheckResult {
  final double requiredBudget;
  final double availableBudget;
  final double deficit;
  final double essentialBudget;
  final bool hasEnoughForEssentials;
  final bool hasEnoughForAll;

  BudgetCheckResult({
    required this.requiredBudget,
    required this.availableBudget,
    required this.deficit,
    required this.essentialBudget,
    required this.hasEnoughForEssentials,
    required this.hasEnoughForAll,
  });

  String get statusMessage {
    if (hasEnoughForAll) {
      return 'Budget suffisant pour toutes les courses';
    } else if (hasEnoughForEssentials) {
      return 'Budget suffisant uniquement pour les articles essentiels';
    } else {
      return 'Budget insuffisant même pour les articles essentiels';
    }
  }

  double get deficitPercentage {
    return requiredBudget > 0 ? (deficit / requiredBudget) * 100 : 0;
  }
}