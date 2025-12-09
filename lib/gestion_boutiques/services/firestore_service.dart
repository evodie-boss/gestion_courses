// services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gestion_courses/gestion_boutiques/models/products.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get productsCollection => 
      _firestore.collection('products');

  // Récupérer tous les produits
  Stream<List<Product>> getProductsStream() {
    return productsCollection
        .where('is_active', isEqualTo: true)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Product.fromFirestore(doc);
      }).toList();
    });
  }

  // Récupérer les produits d'une boutique spécifique
  Stream<List<Product>> getProductsByBoutique(String boutiqueId) {
    return productsCollection
        .where('boutique_id', isEqualTo: boutiqueId)
        .where('is_active', isEqualTo: true)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Product.fromFirestore(doc);
      }).toList();
    });
  }

  // Récupérer les produits par catégorie
  Stream<List<Product>> getProductsByCategory(String category) {
    return productsCollection
        .where('categorie', isEqualTo: category)
        .where('is_active', isEqualTo: true)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Product.fromFirestore(doc);
      }).toList();
    });
  }

  // Ajouter un nouveau produit
  Future<Product> addProduct(Product product) async {
    try {
      // Vérifier si l'utilisateur est connecté
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Préparer les données
      final productData = product.toFirestore();
      
      // Ajouter l'ID de l'utilisateur comme boutique_id si non fourni
      if (product.boutiqueId == null || product.boutiqueId!.isEmpty) {
        productData['boutique_id'] = user.uid;
      }

      // Ajouter le produit dans Firestore
      final docRef = await productsCollection.add(productData);
      
      // Récupérer le produit créé
      final doc = await docRef.get();
      return Product.fromFirestore(doc);
      
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout du produit: $e');
    }
  }

  // Mettre à jour un produit
  Future<void> updateProduct(Product product) async {
    try {
      await productsCollection
          .doc(product.id)
          .update(product.toFirestore());
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour: $e');
    }
  }

  // Supprimer un produit (soft delete)
  Future<void> deleteProduct(String productId) async {
    try {
      await productsCollection
          .doc(productId)
          .update({
            'is_active': false,
            'updated_at': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Erreur lors de la suppression: $e');
    }
  }

  // Rechercher des produits
  Stream<List<Product>> searchProducts(String query) {
    if (query.isEmpty) {
      return getProductsStream();
    }

    return productsCollection
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Product.fromFirestore(doc);
      }).where((product) {
        final searchLower = query.toLowerCase();
        return product.name.toLowerCase().contains(searchLower) ||
               product.description.toLowerCase().contains(searchLower) ||
               product.category.toLowerCase().contains(searchLower);
      }).toList();
    });
  }

  // Récupérer les catégories disponibles
  Future<List<String>> getCategories() async {
    try {
      final snapshot = await productsCollection
          .where('is_active', isEqualTo: true)
          .get();
      
      final categories = snapshot.docs
          .map((doc) => doc['categorie'] as String)
          .toSet()
          .toList();
      
      categories.sort();
      return categories;
    } catch (e) {
      return [];
    }
  }
}