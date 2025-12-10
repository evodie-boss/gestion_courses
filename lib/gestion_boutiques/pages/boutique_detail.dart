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

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Tous', 'filter': 'all'},
    {'name': 'Vêtements', 'filter': 'clothing'},
    {'name': 'Chaussures', 'filter': 'shoes'},
    {'name': 'Accessoires', 'filter': 'accessories'},
    {'name': 'Électronique', 'filter': 'electronics'},
    {'name': 'Aliments', 'filter': 'food'},
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
      final snapshot = await _firestore
          .collection('products')
          .where('boutiqueId', isEqualTo: widget.boutiqueId)
          .get();
      
      final products = await FirestoreConverter.queryToProducts(snapshot);

      setState(() {
        _boutiqueProducts = products;
        _isLoading = false;
      });
      
      _debugProductsInfo(products);
    } catch (e) {
      print('❌ Erreur lors du chargement des produits: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _debugProductsInfo(List<Product> products) {
    print('📊 Nombre de produits chargés pour boutique ${widget.boutiqueId}: ${products.length}');
    for (var product in products) {
      print('  📦 Produit: ${product.name}');
      print('    Boutique ID: ${product.boutiqueId}');
      print('    Image URL: ${product.imageUrl.substring(0, min(product.imageUrl.length, 50))}...');
    }
  }

  String _getImageType(String url) {
    if (url.startsWith('firestore:')) return 'Firestore Reference';
    if (url.startsWith('data:image/')) return 'Base64 Image';
    if (url.startsWith('http')) return 'Network URL';
    return 'Empty/Unknown';
  }

  int min(int a, int b) => a < b ? a : b;

  List<Product> _getFilteredProducts() {
    List<Product> filteredProducts = _boutiqueProducts;

    if (_selectedCategory > 0) {
      final filter = _categories[_selectedCategory]['filter'];
      filteredProducts = filteredProducts
          .where((product) => product.category == filter)
          .toList();
    }

    filteredProducts.sort((a, b) => b.price.compareTo(a.price));
    return filteredProducts;
  }

  void _addToCart(Product product) {
    final existingIndex = _cartItems.indexWhere((item) => item.id == product.id);

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
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Type de livraison'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Prise sur place'),
              value: 'pickup',
              groupValue: _deliveryType,
              onChanged: (value) {
                Navigator.pop(context, value);
              },
            ),
            RadioListTile<String>(
              title: const Text('Livraison à domicile'),
              value: 'delivery',
              groupValue: _deliveryType,
              onChanged: (value) {
                Navigator.pop(context, value);
              },
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _deliveryType = result;
      });
      await _placeOrder();
    }
  }

  Future<void> _placeOrder() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre panier est vide')),
      );
      return;
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter pour passer la commande')),
      );
      return;
    }

    setState(() { _isPlacing = true; });

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
      final items = _cartItems.map((p) => {
        'productId': p.id,
        'name': p.name,
        'qty': 1,
        'unitPrice': p.price,
        'boutiqueId': widget.boutiqueId,
      }).toList();

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
      await _firestore.collection('orders').add(orderData);

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
            'Commande enregistrée avec succès!\n'
            'Total: ${total.toStringAsFixed(0)} FCFA\n'
            'Nouveau solde: ${(currentBalance - total).toStringAsFixed(0)} FCFA'
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('Erreur lors de la création de la commande: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() { _isPlacing = false; });
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
                          _boutiqueInfo!['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF0F9E99), Color(0xFF26C6DA)],
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
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          if (_boutiqueInfo?['categories'] != null)
                            Text(
                              _boutiqueInfo!['categories'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                shadows: [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 5,
                                  ),
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
                        icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
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

              // Bannière de bienvenue
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: _boutiqueInfo?['bannerUrl'] != null
                          ? NetworkImage(_boutiqueInfo!['bannerUrl'])
                          : const NetworkImage(
                              'https://images.unsplash.com/photo-1441986300917-64674bd600d8?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80',
                            ),
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
                                const Icon(Icons.location_on, color: Colors.white70, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _boutiqueInfo!['location'],
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
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${_boutiqueInfo!['rating']?.toStringAsFixed(1) ?? '5.0'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${_boutiqueInfo!['reviewCount'] ?? 0} avis)',
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

              // Filtres de catégories
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: FilterChip(
                          label: Text(
                            _categories[index]['name'],
                            style: TextStyle(
                              color: _selectedCategory == index
                                  ? Colors.white
                                  : const Color(0xFF0F9E99),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: _selectedCategory == index,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = index;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFF0F9E99),
                          side: BorderSide(
                            color: const Color(0xFF0F9E99).withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                        ),
                      );
                    },
                  ),
                ),
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

              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
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
                                icon: const Icon(Icons.close, color: Color(0xFF0F9E99)),
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
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Livraison:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          _deliveryType == 'delivery' ? '2 000 FCFA' : 'Gratuit',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  onPressed: _isPlacing || _cartItems.isEmpty ? null : () async {
                                    await _showDeliveryTypeDialog();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2ECC71),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 50),
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
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
            child: CircularProgressIndicator(
              color: Color(0xFF0F9E99),
            ),
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
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF666666),
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
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = filteredProducts[index];
          return _buildProductCard(product);
        },
        childCount: filteredProducts.length,
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final imageBytes = _getImageBytes(product);
    final isBase64Image = imageBytes != null;
    final isNetworkImage = product.imageUrl.startsWith('http');

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
                        imageBytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildImageFallback(product);
                        },
                      )
                    : isNetworkImage
                        ? Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImageFallback(product);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color: const Color(0xFF0F9E99).withOpacity(0.5),
                                ),
                              );
                            },
                          )
                        : _buildImageFallback(product),
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
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
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
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                    ),
                  )
                : isNetworkImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.shopping_bag,
                                color: Color(0xFF0F9E99),
                              ),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.shopping_bag,
                          color: Color(0xFF0F9E99),
                        ),
                      ),
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

  Widget _buildImageFallback(Product product) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_rounded,
            size: 40,
            color: const Color(0xFF0F9E99).withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              product.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF0F9E99).withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}