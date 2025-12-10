import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:gestion_courses/gestion_boutiques/models/products.dart';
import 'package:gestion_courses/gestion_boutiques/services/firestore_converter.dart';

class BoutiqueDetailScreen extends StatefulWidget {
  final String boutiqueId;
  final String boutiqueName;

  const BoutiqueDetailScreen({
    super.key,
    required this.boutiqueId,
    required this.boutiqueName,
  });

  @override
  State<BoutiqueDetailScreen> createState() => _BoutiqueDetailScreenState();
}

class _BoutiqueDetailScreenState extends State<BoutiqueDetailScreen> {
  int _selectedCategory = 0;
  int _cartItemCount = 0;
  bool _showCart = false;
  double _cartTotal = 0.0;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Images pour chaque catégorie de boutique
  final Map<String, String> _categoryImages = {
    'supermarche': 'https://images.unsplash.com/photo-1542838132-92c53300491e?q=80&w=1974',
    'marche': 'https://images.unsplash.com/photo-1624079269790-f8f7bc1ee7c3?q=80&w=2070',
    'boutique': 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?q=80&w=2070',
    'boulangerie': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?q=80&w=2072',
    'boucherie': 'https://images.unsplash.com/photo-1544025162-d76694265947?q=80&w=2069',
  };

  // Image par défaut
  final String _defaultImage = 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?q=80&w=2070';

  // Liste des filtres DYNAMIQUES (sera remplie avec les catégories réelles)
  List<Map<String, String>> _categories = [
    {'name': 'Tous', 'filter': 'all'},
  ];

  List<Product> _cartItems = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Product> _boutiqueProducts = [];
  bool _isLoading = true;
  bool _isPlacing = false;
  String _deliveryType = 'pickup';
  Map<String, dynamic>? _boutiqueInfo;

  @override
  void initState() {
    super.initState();
    _loadBoutiqueInfo();
    _loadBoutiqueProducts();
  }

  // Méthode pour obtenir l'URL de l'image selon la catégorie
  String _getCategoryImageUrl() {
    if (_boutiqueInfo?['categories'] != null) {
      final category = _boutiqueInfo!['categories'].toString().toLowerCase();
      
      // Chercher dans les catégories prédéfinies
      for (var key in _categoryImages.keys) {
        if (category.contains(key)) {
          return _categoryImages[key]!;
        }
      }
      
      // Vérifier les catégories spécifiques
      if (category.contains('supermarche') || category.contains('super marché')) {
        return _categoryImages['supermarche']!;
      } else if (category.contains('marché') || category.contains('marche')) {
        return _categoryImages['marche']!;
      } else if (category.contains('boutique')) {
        return _categoryImages['boutique']!;
      } else if (category.contains('boulangerie')) {
        return _categoryImages['boulangerie']!;
      } else if (category.contains('boucherie')) {
        return _categoryImages['boucherie']!;
      }
    }
    
    // Image par défaut si aucune catégorie ne correspond
    return _defaultImage;
  }

  // Méthode pour extraire les catégories UNIQUES des produits
  void _extractCategoriesFromProducts(List<Product> products) {
    final categorySet = <String>{};
    
    for (var product in products) {
      if (product.category.isNotEmpty) {
        categorySet.add(product.category);
      }
    }
    
    // Convertir les catégories en format pour les filtres
    final categoryList = categorySet.map((category) {
      // Formater le nom pour l'affichage
      String displayName = category;
      
      // Capitaliser la première lettre
      if (displayName.isNotEmpty) {
        displayName = displayName[0].toUpperCase() + displayName.substring(1);
      }
      
      return {
        'name': displayName,
        'filter': category,
      };
    }).toList();
    
    // Trier par nom
    categoryList.sort((a, b) => a['name']!.compareTo(b['name']!));
    
    // Mettre à jour la liste des catégories
    setState(() {
      _categories = [
        {'name': 'Tous', 'filter': 'all'},
        ...categoryList,
      ];
    });
  }

  Future<void> _loadBoutiqueInfo() async {
    try {
      final doc = await _firestore
          .collection('boutiques')
          .doc(widget.boutiqueId)
          .get();

      if (doc.exists) {
        setState(() {
          _boutiqueInfo = doc.data();
        });
      }
    } catch (e) {
      print('Erreur chargement info boutique: $e');
    }
  }

  Future<void> _loadBoutiqueProducts() async {
    try {
      print('🛒 Chargement produits pour boutique ID: ${widget.boutiqueId}');

      // CORRECTION : Rechercher les produits avec le bon champ "boutique_id"
      final snapshot = await _firestore
          .collection('products')
          .where('boutique_id', isEqualTo: widget.boutiqueId)
          .get();

      print('📊 Nombre de documents récupérés: ${snapshot.docs.length}');

      // Affiche les données brutes pour débogage
      for (var doc in snapshot.docs) {
        print('📄 Document ID: ${doc.id}');
        print('📄 Données: ${doc.data()}');
        print('📄 boutique_id: ${doc.data()['boutique_id']}');
        print('📄 Catégorie: ${doc.data()['categorie']}');
      }

      if (snapshot.docs.isEmpty) {
        // Essayer une autre recherche avec des variations de champ
        print('⚠️ Aucun produit trouvé avec boutique_id. Tentative alternative...');
        
        final alternativeSnapshot = await _firestore
            .collection('products')
            .where('boutiqueId', isEqualTo: widget.boutiqueId)
            .get();
            
        print('🔄 Résultat alternatif: ${alternativeSnapshot.docs.length} produits');
        
        if (alternativeSnapshot.docs.isNotEmpty) {
          for (var doc in alternativeSnapshot.docs) {
            print('📄 Alt - boutiqueId: ${doc.data()['boutiqueId']}');
          }
          final products = await FirestoreConverter.queryToProducts(alternativeSnapshot);
          setState(() {
            _boutiqueProducts = products;
            _isLoading = false;
          });
          
          // Extraire les catégories des produits
          _extractCategoriesFromProducts(products);
          return;
        }
      }

      final products = await FirestoreConverter.queryToProducts(snapshot);
      print('🔄 Nombre de produits convertis: ${products.length}');

      setState(() {
        _boutiqueProducts = products;
        _isLoading = false;
      });
      
      // Extraire les catégories des produits
      _extractCategoriesFromProducts(products);
      
      _debugProductsInfo(products);
    } catch (e) {
      print('❌ Erreur lors du chargement des produits: $e');
      print('Stack trace: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _debugProductsInfo(List<Product> products) {
    print(
      '📊 Nombre de produits chargés pour boutique ${widget.boutiqueId}: ${products.length}',
    );
    
    // Compter les produits par catégorie
    final categoryCount = <String, int>{};
    for (var product in products) {
      categoryCount[product.category] = (categoryCount[product.category] ?? 0) + 1;
    }
    
    print('📊 Catégories trouvées:');
    for (var entry in categoryCount.entries) {
      print('  - ${entry.key}: ${entry.value} produit(s)');
    }
  }

  String _getImageType(String url) {
    if (url.startsWith('firestore:')) return 'Firestore Reference';
    if (url.startsWith('data:image/')) return 'Base64 Image';
    if (url.startsWith('http')) return 'Network URL';
    if (url.isEmpty) return 'Empty';
    return 'Unknown';
  }

  int min(int a, int b) => a < b ? a : b;

  List<Product> _getFilteredProducts() {
    List<Product> filteredProducts = _boutiqueProducts;

    if (_selectedCategory > 0 && _categories.length > _selectedCategory) {
      final filter = _categories[_selectedCategory]['filter']!; // Ajout de ! car on sait que c'est non-null
      filteredProducts = filteredProducts
          .where((product) => product.category == filter)
          .toList();
    }

    filteredProducts.sort((a, b) => b.price.compareTo(a.price));
    return filteredProducts;
  }

  void _addToCart(Product product) {
    final existingIndex = _cartItems.indexWhere(
      (item) => item.id == product.id,
    );

    setState(() {
      if (existingIndex != -1) {
        _cartItemCount++;
        _cartTotal += product.price;
      } else {
        _cartItems.add(product);
        _cartItemCount++;
        _cartTotal += product.price;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} ajouté au panier'),
          backgroundColor: const Color(0xFF0F9E99),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    });
  }

  void _removeFromCart(String productId) {
    final index = _cartItems.indexWhere((item) => item.id == productId);
    if (index != -1) {
      setState(() {
        final product = _cartItems[index];
        _cartTotal -= product.price;
        _cartItemCount--;
        _cartItems.removeAt(index);
      });
    }
  }

  void _toggleCart() {
    setState(() {
      _showCart = !_showCart;
    });
  }

  Future<void> _showDeliveryTypeDialog() async {
    // Sauvegarder le type actuel pour restauration si annulation
    final previousType = _deliveryType;
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false, // Empêche de fermer en cliquant à l'extérieur
      builder: (BuildContext context) {
        String selectedType = _deliveryType;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Type de livraison'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Prise sur place'),
                    subtitle: const Text('Aucuns frais de livraison'),
                    value: 'pickup',
                    groupValue: selectedType,
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Livraison à domicile'),
                    subtitle: const Text('+ 2 000 FCFA de frais de livraison'),
                    value: 'delivery',
                    groupValue: selectedType,
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Annuler et restaurer l'ancien type
                    Navigator.pop(context, previousType);
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, selectedType);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F9E99),
                  ),
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result != previousType) {
      setState(() {
        _deliveryType = result;
      });
      
      // Petite pause pour que l'UI se mette à jour avant de passer la commande
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Passer la commande
      await _placeOrder();
    }
  }

  Future<void> _placeOrder() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Votre panier est vide')));
      return;
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter pour passer la commande'),
        ),
      );
      return;
    }

    setState(() {
      _isPlacing = true;
    });

    try {
      // Vérifier le solde du portefeuille
      final walletDoc = await _firestore
          .collection('portefeuille')
          .doc(_currentUser.uid)
          .get();

      final currentBalance = (walletDoc.data()?['balance'] ?? 0).toDouble();
      final deliveryFee = _deliveryType == 'delivery' ? 2000.0 : 0.0;
      final total = _cartTotal + deliveryFee;

      if (currentBalance < total) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Solde insuffisant!\nSolde actuel: ${currentBalance.toStringAsFixed(0)} FCFA\n'
              'Total commande: ${total.toStringAsFixed(0)} FCFA',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Construire la liste d'items
      final items = _cartItems
          .map(
            (p) => {
              'productId': p.id,
              'name': p.name,
              'qty': 1,
              'unitPrice': p.price,
              'boutiqueId': widget.boutiqueId,
            },
          )
          .toList();

      final orderData = {
        'userId': _currentUser.uid,
        'boutiqueId': widget.boutiqueId,
        'boutiqueName': widget.boutiqueName,
        'items': items,
        'subtotal': _cartTotal,
        'deliveryFee': deliveryFee,
        'total': total,
        'deliveryType': _deliveryType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Créer la commande
      final orderRef = await _firestore.collection('orders').add(orderData);

      // Débiter le portefeuille
      await _firestore.collection('portefeuille').doc(_currentUser.uid).update({
        'balance': FieldValue.increment(-total),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Vider le panier
      setState(() {
        _cartItems.clear();
        _cartItemCount = 0;
        _cartTotal = 0.0;
        _showCart = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Commande #${orderRef.id.substring(0, 8)} enregistrée!\n'
            'Total: ${total.toStringAsFixed(0)} FCFA',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('Erreur lors de la création de la commande: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isPlacing = false;
      });
    }
  }

  Uint8List? _getImageBytes(Product product) {
    if (product.imageUrl.startsWith('data:image/')) {
      try {
        final base64Str = product.imageUrl.split(',').last;
        return base64.decode(base64Str);
      } catch (e) {
        print('❌ Erreur décodage base64: $e');
        return null;
      }
    }
    return null;
  }

  // Méthode pour récupérer une image Firestore
  Widget _buildFirestoreImage(String firestoreId) {
    final imageId = firestoreId.replaceFirst('firestore:', '');
    
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('product_images').doc(imageId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF0F9E99).withOpacity(0.5),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return _buildImageFallback();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final base64Image = data['image_base64'] as String?;

        if (base64Image == null || base64Image.isEmpty) {
          return _buildImageFallback();
        }

        try {
          return ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.memory(
              base64Decode(base64Image),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          );
        } catch (e) {
          print('❌ Erreur affichage image base64: $e');
          return _buildImageFallback();
        }
      },
    );
  }

  Widget _buildImageFallback({String? name}) {
    return Container(
      color: const Color(0xFFEFE9E0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_rounded,
              size: 40,
              color: const Color(0xFF0F9E99).withOpacity(0.3),
            ),
            if (name != null && name.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF0F9E99).withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // AppBar avec image de la boutique
              SliverAppBar(
                expandedHeight: 200,
                floating: true,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 2,
                shadowColor: Colors.black12,
                flexibleSpace: FlexibleSpaceBar(
                  background: _boutiqueInfo?['imageUrl'] != null
                      ? Image.network(
                          _boutiqueInfo!['imageUrl'] as String, // Cast en String
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF0F9E99),
                                    Color(0xFF26C6DA),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF0F9E99), Color(0xFF26C6DA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                  title: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.storefront,
                          color: Color(0xFF0F9E99),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.boutiqueName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 10),
                              ],
                            ),
                          ),
                          if (_boutiqueInfo?['categories'] != null)
                            Text(
                              _boutiqueInfo!['categories'] as String, // Cast en String
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                shadows: [
                                  Shadow(color: Colors.black45, blurRadius: 5),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                ),
                actions: [
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                        ),
                        onPressed: _toggleCart,
                      ),
                      if (_cartItemCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$_cartItemCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                ],
              ),

              // Bannière de bienvenue AVEC IMAGE DE CATÉGORIE
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: NetworkImage(_getCategoryImageUrl()),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.black.withOpacity(0.6),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue chez ${widget.boutiqueName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Des produits de qualité à des prix imbattables.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                        if (_boutiqueInfo?['location'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _boutiqueInfo!['location'] as String, // Cast en String
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_boutiqueInfo?['rating'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (_boutiqueInfo!['rating'] as num).toStringAsFixed(1), // Cast en num
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${(_boutiqueInfo!['reviewCount'] as num? ?? 0).toString()} avis)', // Cast en num
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // FILTRES DYNAMIQUES basés sur les catégories réelles
              SliverToBoxAdapter(
                child: _categories.length > 1
                    ? SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final isSelected = _selectedCategory == index;
                            final categoryName = category['name']!;
                            final categoryFilter = category['filter']!;
                            
                            final productCount = index == 0
                                ? _boutiqueProducts.length
                                : _boutiqueProducts
                                    .where((p) => p.category == categoryFilter)
                                    .length;

                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: FilterChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(categoryName),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.3)
                                            : const Color(0xFF0F9E99)
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$productCount',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF0F9E99),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory = index;
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: const Color(0xFF0F9E99),
                                side: BorderSide(
                                  color:
                                      const Color(0xFF0F9E99).withOpacity(0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Titre des produits
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Produits disponibles',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey[800],
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 4,
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F9E99),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '(${_getFilteredProducts().length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F9E99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Grille des produits
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                sliver: _buildProductsGrid(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // Panier latéral
          if (_showCart)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    color: Colors.white,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Votre Panier',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Color(0xFF0F9E99),
                                ),
                                onPressed: _toggleCart,
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: _cartItems.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 60,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Votre panier est vide',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[400],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(20),
                                  itemCount: _cartItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _cartItems[index];
                                    return _buildCartItem(item);
                                  },
                                ),
                        ),

                        if (_cartItems.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Détails du total
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Sous-total:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '${_cartTotal.toStringAsFixed(0)} FCFA',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Livraison:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          _deliveryType == 'delivery'
                                              ? '2 000 FCFA'
                                              : 'Gratuit',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total:',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        Text(
                                          '${(_cartTotal + (_deliveryType == 'delivery' ? 2000 : 0)).toStringAsFixed(0)} FCFA',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F9E99),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _isPlacing || _cartItems.isEmpty
                                      ? null
                                      : () async {
                                          await _showDeliveryTypeDialog();
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2ECC71),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(
                                      double.infinity,
                                      50,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 3,
                                  ),
                                  child: _isPlacing
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          'Passer la commande',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: Color(0xFF0F9E99)),
          ),
        ),
      );
    }

    final filteredProducts = _getFilteredProducts();

    if (filteredProducts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: 60,
                color: Color(0xFFCCCCCC),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun produit disponible',
                style: TextStyle(fontSize: 18, color: Color(0xFF666666)),
              ),
              if (_selectedCategory > 0 && _categories.length > _selectedCategory)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Aucun produit dans la catégorie "${_categories[_selectedCategory]['name']!}"',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Boutique ID: ${widget.boutiqueId}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = 0;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9E99),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Voir tous les produits'),
              ),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final product = filteredProducts[index];
        return _buildProductCard(product);
      }, childCount: filteredProducts.length),
    );
  }

  Widget _buildProductCard(Product product) {
    final imageBytes = _getImageBytes(product);
    final isBase64Image = imageBytes != null;
    final isNetworkImage = product.imageUrl.startsWith('http');
    final isFirestoreImage = product.imageUrl.startsWith('firestore:');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              child: Container(
                width: double.infinity,
                color: const Color(0xFFEFE9E0),
                child: isBase64Image
                    ? Image.memory(
                        imageBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildImageFallback(name: product.name);
                        },
                      )
                    : isNetworkImage
                        ? Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImageFallback(name: product.name);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color:
                                      const Color(0xFF0F9E99).withOpacity(0.5),
                                ),
                              );
                            },
                          )
                        : isFirestoreImage
                            ? _buildFirestoreImage(product.imageUrl)
                            : _buildImageFallback(name: product.name),
              ),
            ),
          ),

          // Product info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${product.price.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F9E99),
                      ),
                    ),
                  ],
                ),

                if (product.category.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      product.category,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _addToCart(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Ajouter',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Product item) {
    final imageBytes = _getImageBytes(item);
    final isBase64Image = imageBytes != null;
    final isNetworkImage = item.imageUrl.startsWith('http');
    final isFirestoreImage = item.imageUrl.startsWith('firestore:');

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFEFE9E0),
            ),
            child: isBase64Image
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(imageBytes!, fit: BoxFit.cover),
                  )
                : isNetworkImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildCartImageFallback();
                          },
                        ),
                      )
                    : isFirestoreImage
                        ? _buildFirestoreImage(item.imageUrl)
                        : _buildCartImageFallback(),
          ),
          const SizedBox(width: 15),

          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  '${item.price.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F9E99),
                  ),
                ),
                if (item.category.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Remove button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE74C3C)),
            onPressed: () => _removeFromCart(item.id),
          ),
        ],
      ),
    );
  }

  Widget _buildCartImageFallback() {
    return Center(
      child: Icon(
        Icons.shopping_bag,
        color: const Color(0xFF0F9E99).withOpacity(0.5),
        size: 30,
      ),
    );
  }
}