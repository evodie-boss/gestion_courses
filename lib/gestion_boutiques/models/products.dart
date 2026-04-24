import 'package:cloud_firestore/cloud_firestore.dart';
// models/product.dart
class Product {
  String? boutiqueId; // ID de la boutique
  String id; // ID du produit dans Firestore
  String name;
  double price;
  String category;
  String imageUrl;
  String description;
  DateTime createdAt;
  DateTime updatedAt;
  bool isActive;
  List<String>? colors;
  List<String>? sizes;

  Product({
    this.boutiqueId,
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.imageUrl,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.colors,
    this.sizes,
  });

  // Convertir depuis Firestore Document
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Product(
      boutiqueId: data['boutique_id'] ?? '',
      id: doc.id,
      name: data['nom'] ?? '',
      price: (data['prix'] as num).toDouble(),
      category: data['categorie'] ?? '',
      imageUrl: data['image'] ?? '',
      description: data['description'] ?? '',
      createdAt: data['created_at'] != null 
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: data['is_active'] ?? true,
    );
  }

  // Convertir vers Firestore Document
  Map<String, dynamic> toFirestore() {
    return {
      'boutique_id': boutiqueId,
      'nom': name,
      'prix': price,
      'categorie': category,
      'image': imageUrl,
      'description': description,
      'updated_at': FieldValue.serverTimestamp(),
      'is_active': isActive,
    };
  }

  // Pour créer un nouveau produit
  static Product newProduct({
    required String boutiqueId,
    required String name,
    required double price,
    required String category,
    required String imageUrl,
    required String description,
  }) {
    final now = DateTime.now();
    return Product(
      boutiqueId: boutiqueId,
      id: '', // L'ID sera généré par Firestore
      name: name,
      price: price,
      category: category,
      imageUrl: imageUrl,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }
}