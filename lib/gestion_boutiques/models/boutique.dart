import 'package:cloud_firestore/cloud_firestore.dart';

class Boutique {
  String? id;
  String adresse;
  double balance;  
  String categories;
  DateTime? createdAt;
  DateTime? updatedAt;
  double latitude;
  double longitude;
  double distanceKm = 0.0;
  String nom;

  Boutique({
    this.id,
    required this.adresse,
    required this.balance,
    required this.categories,
    this.createdAt,
    this.updatedAt,
    required this.latitude,
    required this.longitude,
    this.distanceKm = 0.0, // <==== AJOUTEZ CETTE INITIALISATION
    required this.nom,
  });

  // Convertir un document Firestore en objet Boutique
  factory Boutique.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Boutique(
      id: doc.id,
      adresse: data['adresse'] ?? '',
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      categories: data['categories'] ?? '',
      createdAt: data['created_at'] != null 
          ? (data['created_at'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updated_at'] != null 
          ? (data['updated_at'] as Timestamp).toDate() 
          : null,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      nom: data['nom'] ?? '',
    );
  }

  // Convertir l'objet Boutique en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'adresse': adresse,
      'categories': categories,
      'latitude': latitude,
      'longitude': longitude,
      'nom': nom,
      'updated_at': FieldValue.serverTimestamp(),
      if (createdAt == null) 'created_at': FieldValue.serverTimestamp(),
    };
  }

  // Mettre à jour l'objet avec les données de Firestore
  void updateFromFirestore(Map<String, dynamic> data) {
    adresse = data['adresse'] ?? adresse;
    categories = data['categories'] ?? categories;
    latitude = (data['latitude'] as num?)?.toDouble() ?? latitude;
    longitude = (data['longitude'] as num?)?.toDouble() ?? longitude;
    nom = data['nom'] ?? nom;
    
    if (data['created_at'] != null) {
      createdAt = (data['created_at'] as Timestamp).toDate();
    }
    
    if (data['updated_at'] != null) {
      updatedAt = (data['updated_at'] as Timestamp).toDate();
    }
  }

  // Créer une copie de l'objet
  Boutique copyWith({
    String? id,
    String? adresse,
    String? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    String? nom,
  }) {
    return Boutique(
      id: id ?? this.id,
      adresse: adresse ?? this.adresse,
      balance: balance,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      nom: nom ?? this.nom,
    );
  }

  @override
  String toString() {
    return 'Boutique{id: $id, nom: $nom, categories: $categories, adresse: $adresse}';
  }
}