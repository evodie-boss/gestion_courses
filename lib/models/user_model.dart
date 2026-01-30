// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String numeroPhone;
  final double soldePortefeuille;
  final String createdAt;

  UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.numeroPhone,
    required this.soldePortefeuille,
    required this.createdAt,
  });

  // Ajoutez un getter pour fullName
  String get fullName => '$prenom $nom';

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'numeroPhone': numeroPhone,
      'soldePortefeuille': soldePortefeuille,
      'createdAt': createdAt,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }


  // Créer depuis Firestore Document - CORRECTION ICI
  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data()!;
    return UserModel(
      id: snapshot.id,
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      email: data['email'] ?? '',
      numeroPhone: data['numeroPhone'] ?? '',
      soldePortefeuille: (data['soldePortefeuille'] ?? 0.0).toDouble(),
      createdAt: data['createdAt'] ?? '',
    );
  }

  // Alternative simplifiée si la méthode ci-dessus ne fonctionne pas
  factory UserModel.fromFirestoreSimple(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      email: data['email'] ?? '',
      numeroPhone: data['numeroPhone'] ?? '',
      soldePortefeuille: (data['soldePortefeuille'] ?? 0.0).toDouble(),
      createdAt: data['createdAt'] ?? '',
    );
  }

  UserModel copyWith({
    String? nom,
    String? prenom,
    String? numeroPhone,
    double? soldePortefeuille,
  }) {
    return UserModel(
      id: id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      email: email,
      numeroPhone: numeroPhone ?? this.numeroPhone,
      soldePortefeuille: soldePortefeuille ?? this.soldePortefeuille,
      createdAt: createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, nom: $nom, prenom: $prenom, email: $email)';
  }
}
