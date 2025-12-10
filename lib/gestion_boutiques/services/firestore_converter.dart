import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:gestion_courses/gestion_boutiques/models/products.dart';

class FirestoreConverter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Convertir DocumentSnapshot en Product
  static Future<Product> documentToProduct(DocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      final data = doc.data();
      
      if (data == null) {
        return Product(
          boutiqueId: '',
          id: doc.id,
          name: 'Produit indisponible',
          price: 0.0,
          category: '',
          imageUrl: '',
          description: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );
      }
      
      // Récupérer l'URL de l'image
      String imageUrl = data['image']?.toString() ?? '';
      
      // Si c'est une image stockée dans Firestore (format "firestore:ID")
      if (imageUrl.startsWith('firestore:')) {
        imageUrl = await _getImageFromFirestore(imageUrl);
      }
      
      return Product(
        boutiqueId: data['boutique_id']?.toString() ?? '',
        id: doc.id,
        name: data['nom']?.toString() ?? 'Sans nom',
        price: (data['prix'] is num ? (data['prix'] as num).toDouble() : 0.0),
        category: data['categorie']?.toString() ?? '',
        imageUrl: imageUrl,
        description: data['description']?.toString() ?? '',
        createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );
    } catch (e) {
      print('❌ Erreur conversion document ${doc.id}: $e');
      return Product(
        boutiqueId: '',
        id: doc.id,
        name: 'Erreur de chargement',
        price: 0.0,
        category: '',
        imageUrl: '',
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: false,
      );
    }
  }

  // Récupérer une image stockée dans Firestore
  static Future<String> _getImageFromFirestore(String firestoreRef) async {
    try {
      final imageId = firestoreRef.replaceFirst('firestore:', '');
      final doc = await _firestore.collection('product_images').doc(imageId).get();
      
      if (doc.exists) {
        final data = doc.data();
        final base64Image = data?['image_base64']?.toString();
        
        if (base64Image != null && base64Image.isNotEmpty) {
          // Convertir base64 en data URL pour Image.memory
          return 'data:image/jpeg;base64,$base64Image';
        }
      }
      return ''; // Image non trouvée
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'image Firestore: $e');
      return '';
    }
  }

  // Convertir QuerySnapshot en liste de Products
  static Future<List<Product>> queryToProducts(QuerySnapshot<Map<String, dynamic>> query) async {
    final products = <Product>[];
    
    for (final doc in query.docs) {
      try {
        final product = await documentToProduct(doc);
        products.add(product);
      } catch (e) {
        print('❌ Erreur conversion document ${doc.id}: $e');
      }
    }
    
    return products;
  }

  // Convertir Product en Map pour Firestore
  static Map<String, dynamic> productToMap(Product product) {
    return <String, dynamic>{
      'boutique_id': product.boutiqueId ?? '',
      'nom': product.name,
      'prix': product.price,
      'categorie': product.category,
      'image': product.imageUrl,
      'description': product.description,
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  // Convertir un Map (depuis Firestore) en Product
  static Future<Product> mapToProduct(Map<String, dynamic> data, String documentId) async {
    String imageUrl = data['image']?.toString() ?? '';
    
    // Si c'est une image Firestore, la convertir
    if (imageUrl.startsWith('firestore:')) {
      imageUrl = await _getImageFromFirestore(imageUrl);
    }
    
    return Product(
      boutiqueId: data['boutique_id']?.toString() ?? '',
      id: documentId,
      name: data['nom']?.toString() ?? 'Sans nom',
      price: (data['prix'] is num ? (data['prix'] as num).toDouble() : 0.0),
      category: data['categorie']?.toString() ?? '',
      imageUrl: imageUrl,
      description: data['description']?.toString() ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
    );
  }

  // Créer un nouveau produit à partir des données du formulaire
  static Product createNewProduct({
    required String name,
    required double price,
    required String category,
    required String imageUrl,
    required String description,
    String? boutiqueId,
  }) {
    return Product(
      boutiqueId: boutiqueId,
      id: '', // L'ID sera généré par Firestore
      name: name,
      price: price,
      category: category,
      imageUrl: imageUrl,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
    );
  }

  // Vérifier si un document est valide
  static bool isValidDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return false;
    
    final data = doc.data();
    if (data == null) return false;
    
    if (data['nom'] == null || data['nom'].toString().isEmpty) return false;
    if (data['prix'] == null) return false;
    if (data['categorie'] == null || data['categorie'].toString().isEmpty) return false;
    
    return true;
  }

  // Filtrer les produits par catégorie
  static List<Product> filterByCategory(List<Product> products, String category) {
    if (category == 'all' || category.isEmpty) return products;
    return products.where((product) => product.category == category).toList();
  }

  // Rechercher des produits
  static List<Product> searchProducts(List<Product> products, String query) {
    if (query.isEmpty) return products;
    
    final lowercaseQuery = query.toLowerCase();
    return products.where((product) {
      return product.name.toLowerCase().contains(lowercaseQuery) ||
             product.description.toLowerCase().contains(lowercaseQuery) ||
             product.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Trier les produits par prix
  static List<Product> sortProducts(List<Product> products, {bool ascending = false}) {
    final List<Product> sorted = List.from(products);
    sorted.sort((a, b) {
      if (ascending) {
        return a.price.compareTo(b.price);
      } else {
        return b.price.compareTo(a.price);
      }
    });
    return sorted;
  }

  // Trier par nom
  static List<Product> sortProductsByName(List<Product> products, {bool ascending = true}) {
    final List<Product> sorted = List.from(products);
    sorted.sort((a, b) {
      if (ascending) {
        return a.name.compareTo(b.name);
      } else {
        return b.name.compareTo(a.name);
      }
    });
    return sorted;
  }

  // Obtenir les catégories uniques
  static List<String> getUniqueCategories(List<Product> products) {
    final categories = products
        .map((p) => p.category)
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return ['all', ...categories];
  }

  // Préparer les données pour l'export
  static Map<String, dynamic> prepareForExport(Product product) {
    return {
      'ID': product.id,
      'Nom': product.name,
      'Prix': '${product.price.toStringAsFixed(0)} FCFA',
      'Catégorie': product.category,
      'Description': product.description,
      'Image URL': product.imageUrl,
      'Boutique ID': product.boutiqueId,
    };
  }

  // Calculer les statistiques
  static Map<String, dynamic> calculateStats(List<Product> products) {
    if (products.isEmpty) {
      return {
        'total': 0,
        'averagePrice': 0,
        'minPrice': 0,
        'maxPrice': 0,
        'byCategory': {},
      };
    }

    final total = products.length;
    final totalPrice = products.fold(0.0, (sum, product) => sum + product.price);
    final averagePrice = totalPrice / total;
    final minPrice = products.fold(double.infinity, (min, product) => product.price < min ? product.price : min);
    final maxPrice = products.fold(0.0, (max, product) => product.price > max ? product.price : max);
    
    final byCategory = <String, int>{};
    for (final product in products) {
      if (product.category.isNotEmpty) {
        byCategory[product.category] = (byCategory[product.category] ?? 0) + 1;
      }
    }

    return {
      'total': total,
      'averagePrice': averagePrice,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'byCategory': byCategory,
    };
  }

  // Valider les données
  static Map<String, String> validateProductData({
    required String name,
    required String price,
    required String category,
    required String imageUrl,
    required String description,
  }) {
    final errors = <String, String>{};

    if (name.isEmpty) {
      errors['name'] = 'Le nom est obligatoire';
    }

    if (price.isEmpty) {
      errors['price'] = 'Le prix est obligatoire';
    } else {
      final priceValue = double.tryParse(price);
      if (priceValue == null) {
        errors['price'] = 'Le prix doit être un nombre valide';
      } else if (priceValue <= 0) {
        errors['price'] = 'Le prix doit être supérieur à 0';
      }
    }

    if (category.isEmpty) {
      errors['category'] = 'La catégorie est obligatoire';
    }

    if (imageUrl.isEmpty) {
      errors['imageUrl'] = 'L\'image est obligatoire';
    }

    return errors;
  }

  // Formater le prix
  static String formatPrice(double price) {
    return '${price.toStringAsFixed(0)} FCFA';
  }

  // Grouper par catégorie
  static Map<String, List<Product>> groupByCategory(List<Product> products) {
    final grouped = <String, List<Product>>{};
    
    for (final product in products) {
      final category = product.category.isEmpty ? 'Non catégorisé' : product.category;
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(product);
    }
    
    return grouped;
  }

  // Mettre à jour un produit
  static Map<String, dynamic> updateProductToMap(Product product) {
    return <String, dynamic>{
      'boutique_id': product.boutiqueId ?? '',
      'nom': product.name,
      'prix': product.price,
      'categorie': product.category,
      'image': product.imageUrl,
      'description': product.description,
    };
  }

  // Vérifier si une URL d'image est valide
  static bool isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    
    if (url.startsWith('firestore:')) return true;
    if (url.startsWith('data:image/')) return true;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasAbsolutePath;
    } catch (_) {
      return false;
    }
  }

  // Valider un produit entier
  static List<String> validateProduct(Product product) {
    final errors = <String>[];
    
    if (product.name.isEmpty) {
      errors.add('Le nom du produit est requis');
    }
    
    if (product.price <= 0) {
      errors.add('Le prix doit être supérieur à 0');
    }
    
    if (product.category.isEmpty) {
      errors.add('La catégorie est requise');
    }
    
    if (product.imageUrl.isEmpty) {
      errors.add('L\'URL de l\'image est requise');
    } else if (!isValidImageUrl(product.imageUrl)) {
      errors.add('URL d\'image invalide');
    }
    
    return errors;
  }

  // Décodeur d'image base64
  static Uint8List? decodeBase64Image(String dataUrl) {
    try {
      if (dataUrl.startsWith('data:image/')) {
        final base64Str = dataUrl.split(',').last;
        return base64.decode(base64Str);
      }
      return null;
    } catch (e) {
      print('❌ Erreur décodage base64: $e');
      return null;
    }
  }

  // Vérifier si c'est une image base64
  static bool isBase64Image(String imageUrl) {
    return imageUrl.startsWith('data:image/');
  }

  // Vérifier si c'est une image Firestore
  static bool isFirestoreImage(String imageUrl) {
    return imageUrl.startsWith('firestore:');
  }

  // Vérifier si c'est une URL normale
  static bool isNetworkImage(String imageUrl) {
    return imageUrl.startsWith('http');
  }
}