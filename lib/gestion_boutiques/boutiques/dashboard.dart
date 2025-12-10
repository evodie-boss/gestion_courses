import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:typed_data';
import 'package:gestion_courses/firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

// Import conditionnel pour web
import 'package:image_picker_web/image_picker_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Produits',
      theme: ThemeData(
        fontFamily: 'Poppins',
        primaryColor: const Color(0xFF6D5DFC),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: const AdminDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0; // Tableau de bord par défaut
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _orderSearchController = TextEditingController();

  // Variables pour stocker l'image
  Uint8List? _selectedImageBytes;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  String _searchQuery = '';
  String _orderSearchQuery = '';
  double _uploadProgress = 0.0;

  // Map pour stocker les noms des clients
  Map<String, String> _clientNames = {};

  final List<Map<String, dynamic>> _categories = [
    {
      'value': 'clothing',
      'label': 'Vêtements',
      'color': const Color(0xFF6D5DFC),
    },
    {'value': 'shoes', 'label': 'Chaussures', 'color': const Color(0xFF2ECC71)},
    {
      'value': 'accessories',
      'label': 'Accessoires',
      'color': const Color(0xFFF39C12),
    },
    {
      'value': 'electronics',
      'label': 'Électronique',
      'color': const Color(0xFF3498DB),
    },
    {'value': 'food', 'label': 'Aliments', 'color': const Color(0xFF9B59B6)},
  ];

  // Statuts des commandes
  final List<String> _orderStatuses = [
    'En attente',
    'Confirmée',
    'En préparation',
    'Expédiée',
    'Livrée',
    'Annulée'
  ];

  // Méthodes de livraison
  final List<String> _deliveryMethods = [
    'Standard',
    'Express',
    'Point relais',
    'Retrait en magasin'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: const Color(0xFF2C3E50),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(25),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.store,
                        color: Color(0xFF6D5DFC),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Ma Boutique',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: ListView(
                    children: [
                      _buildNavItem(
                        0,
                        Icons.dashboard,
                        'Tableau de bord',
                        isActive: _selectedIndex == 0,
                      ),
                      _buildNavItem(
                        1,
                        Icons.inventory,
                        'Produits',
                        isActive: _selectedIndex == 1,
                      ),
                      _buildNavItem(
                        2,
                        Icons.shopping_cart,
                        'Commandes',
                        isActive: _selectedIndex == 2,
                      ),
                      _buildNavItem(
                        3,
                        Icons.settings,
                        'Paramètres',
                        isActive: _selectedIndex == 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contenu principal
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA),
              padding: const EdgeInsets.all(25),
              child: _buildSelectedTab(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildProductsTab();
      case 2:
        return _buildOrdersTab();
      case 3:
        return _buildComingSoonTab();
      default:
        return _buildDashboardTab();
    }
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String title, {
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? const Border(left: BorderSide(color: Color(0xFF6D5DFC), width: 4))
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFFB0B7C3),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFFB0B7C3),
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  // ============================================
  // TABLEAU DE BORD
  // ============================================
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Text(
              'Tableau de bord',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Aperçu général de votre boutique',
              style: TextStyle(
                fontSize: 16,
                color: const Color(0xFF7F8C8D),
              ),
            ),
            const SizedBox(height: 30),

            // Cartes de statistiques
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('products').snapshots(),
              builder: (context, snapshot) {
                final totalProducts = snapshot.hasData ? snapshot.data!.docs.length : 0;

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('orders').snapshots(),
                  builder: (context, orderSnapshot) {
                    final totalOrders = orderSnapshot.hasData ? orderSnapshot.data!.docs.length : 0;
                    double totalRevenue = 0;
                    int pendingOrders = 0;

                    if (orderSnapshot.hasData) {
                      for (var doc in orderSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        totalRevenue += (data['total'] ?? 0).toDouble();

                        final status = data['status']?.toString() ?? '';
                        if (status == 'En attente') {
                          pendingOrders++;
                        }
                      }
                    }

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: MediaQuery.of(context).size.width > 1000 ? 4 :
                                  MediaQuery.of(context).size.width > 600 ? 2 : 1,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: MediaQuery.of(context).size.width > 1000 ? 3.5 : 
                                     MediaQuery.of(context).size.width > 600 ? 2.8 : 2.2,
                      children: [
                        _buildStatCard(
                          title: 'Produits',
                          value: totalProducts.toString(),
                          icon: Icons.inventory,
                          color: const Color(0xFF6D5DFC),
                          subtitle: 'en stock',
                        ),
                        _buildStatCard(
                          title: 'Commandes',
                          value: totalOrders.toString(),
                          icon: Icons.shopping_cart,
                          color: const Color(0xFF2ECC71),
                          subtitle: 'au total',
                        ),
                        _buildStatCard(
                          title: 'Chiffre d\'affaires',
                          value: '${totalRevenue.toStringAsFixed(0)} FCFA',
                          icon: Icons.money,
                          color: const Color(0xFFF39C12),
                          subtitle: 'total',
                        ),
                        _buildStatCard(
                          title: 'En attente',
                          value: pendingOrders.toString(),
                          icon: Icons.pending,
                          color: const Color(0xFF3498DB),
                          subtitle: 'commandes',
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 40),

            // Deux colonnes pour les commandes récentes et produits populaires
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Commandes récentes
                  Expanded(
                    flex: 2,
                    child: _buildRecentOrders(),
                  ),
                  const SizedBox(width: 20),

                  // Statistiques par catégorie
                  Expanded(
                    flex: 1,
                    child: _buildCategoryStats(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFBDC3C7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commandes récentes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('orders')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 50,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Aucune commande',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  final orders = snapshot.data!.docs;

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: orders.length,
                    separatorBuilder: (context, index) => const Divider(height: 15),
                    itemBuilder: (context, index) {
                      final doc = orders[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final orderId = doc.id;
                      final amount = (data['total'] ?? 0).toDouble();
                      final status = data['status']?.toString() ?? 'pending';
                      final ts = data['createdAt'] as Timestamp?;
                      String formattedDate = '';
                      if (ts != null) {
                        try {
                          formattedDate = DateFormat('dd/MM/yy HH:mm').format(ts.toDate());
                        } catch (e) {
                          formattedDate = ts.toDate().toString();
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getOrderStatusIcon(status),
                              color: _getStatusColor(status),
                              size: 18,
                            ),
                          ),
                          title: Text(
                            'Commande #${orderId.length > 8 ? orderId.substring(0, 8) + '...' : orderId}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            formattedDate,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: SizedBox(
                            width: 100,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${amount.toStringAsFixed(0)} FCFA',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status.length > 10 ? '${status.substring(0, 10)}...' : status,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryStats() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Produits par catégorie',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('products').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 40,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Aucun produit',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  final products = snapshot.data!.docs;
                  final categoryCounts = <String, int>{};

                  for (var doc in products) {
                    final data = doc.data() as Map<String, dynamic>;
                    final category = data['categorie']?.toString() ?? 'Non catégorisé';
                    categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
                  }

                  final sortedCategories = categoryCounts.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: sortedCategories.length,
                    separatorBuilder: (context, index) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final entry = sortedCategories[index];
                      final categoryName = _getCategoryName(entry.key);
                      final count = entry.value;
                      final totalProducts = products.length;
                      final percentage = totalProducts > 0 ? (count / totalProducts * 100) : 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(entry.key),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  categoryName.substring(0, 1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          categoryName.length > 15 ? '${categoryName.substring(0, 15)}...' : categoryName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$count',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getCategoryColor(entry.key),
                                    ),
                                    minHeight: 3,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // ONGLET PRODUITS
  // ============================================
  Widget _buildProductsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Gestion des Produits',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C3E50),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 20),
            Container(
              constraints: BoxConstraints(
                maxWidth: 300,
                minWidth: 200,
              ),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: Color(0xFF7F8C8D),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un produit...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: Color(0xFF7F8C8D),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _showAddProductDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6D5DFC),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Ajouter un produit'),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildProductsTable(),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Erreur: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Chargement des produits...'),
              ],
            ),
          );
        }

        final products = snapshot.data!.docs;

        final filteredProducts = products.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nom = (data['nom'] ?? '').toString().toLowerCase();
          final categorie = (data['categorie'] ?? '').toString().toLowerCase();
          final search = _searchQuery.toLowerCase();

          return nom.contains(search) || categorie.contains(search);
        }).toList();

        if (filteredProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 50,
                  color: Color(0xFFCCCCCC),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'Aucun produit disponible'
                        : 'Aucun produit trouvé pour "$_searchQuery"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
                if (_searchQuery.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextButton(
                      onPressed: () => _showAddProductDialog(),
                      child: const Text('Ajouter votre premier produit'),
                    ),
                  ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 20,
              headingRowHeight: 50,
              dataRowHeight: 60,
              columns: const [
                DataColumn(
                  label: Text(
                    'Image',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Nom',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Prix',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Catégorie',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              rows: filteredProducts.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final imageRef = data['image'] as String?;

                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFFEFE9E0),
                        ),
                        child: imageRef != null && imageRef.isNotEmpty
                            ? imageRef.startsWith('firestore:')
                                ? _buildFirestoreImage(imageRef)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      imageRef,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    ),
                                  )
                            : const Icon(
                                Icons.shopping_bag,
                                color: Color(0xFF6D5DFC),
                                size: 24,
                              ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Text(
                          data['nom']?.toString() ?? 'Sans nom',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${(data['prix'] ?? 0).toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(data['categorie']),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getCategoryName(data['categorie']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Color(0xFF3498DB),
                            ),
                            onPressed: () => _editProduct(doc.id, data),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 18,
                              color: Color(0xFFE74C3C),
                            ),
                            onPressed: () => _deleteProduct(
                              doc.id,
                              data['nom']?.toString() ?? 'ce produit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ============================================
  // ONGLET COMMANDES
  // ============================================
  Widget _buildOrdersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Gestion des Commandes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C3E50),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 20),
            Container(
              constraints: BoxConstraints(
                maxWidth: 300,
                minWidth: 200,
              ),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: Color(0xFF7F8C8D),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _orderSearchController,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher une commande...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: Color(0xFF7F8C8D),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _orderSearchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                  if (_orderSearchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _orderSearchController.clear();
                        setState(() {
                          _orderSearchQuery = '';
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildOrdersTable(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Erreur: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Chargement des commandes...'),
              ],
            ),
          );
        }

        final orders = snapshot.data!.docs;

        // Charger les noms des clients
        final userIds = orders.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['userId']?.toString() ?? '';
        }).where((id) => id.isNotEmpty).toSet().toList();

        // Charger les noms en arrière-plan
        _loadClientNames(userIds);

        // Filtrer les commandes selon la recherche
        final filteredOrders = orders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final orderId = (data['id'] ?? '').toString().toLowerCase();
          final status = (data['status'] ?? '').toString().toLowerCase();
          final userId = (data['userId'] ?? '').toString().toLowerCase();
          final clientName = _getClientName(userId).toLowerCase();
          final search = _orderSearchQuery.toLowerCase();

          return orderId.contains(search) ||
              status.contains(search) ||
              userId.contains(search) ||
              clientName.contains(search);
        }).toList();

        if (filteredOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  size: 50,
                  color: Color(0xFFCCCCCC),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _orderSearchQuery.isEmpty
                        ? 'Aucune commande disponible'
                        : 'Aucune commande trouvée pour "$_orderSearchQuery"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 20,
              headingRowHeight: 50,
              dataRowHeight: 60,
              columns: const [
                DataColumn(
                  label: Text(
                    'ID Commande',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Montant',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Statut',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Livraison',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Client',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              rows: filteredOrders.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final orderId = doc.id;
                final date = data['createdAt'] != null
                    ? (data['createdAt'] as Timestamp).toDate().toString()
                    : 'N/A';
                final amount = (data['total'] ?? 0).toDouble();
                final status = data['status']?.toString() ?? 'pending';
                final deliveryMethod =
                    data['deliveryType']?.toString() ?? 'pickup';
                final userId = data['userId']?.toString() ?? 'N/A';

                // Obtenir le nom du client
                final clientName = _getClientName(userId);

                // Formater la date
                String formattedDate = date;
                try {
                  if (date != 'N/A') {
                    final parsedDate = DateTime.parse(date);
                    formattedDate =
                        DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
                  }
                } catch (e) {
                  formattedDate = date;
                }

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: Tooltip(
                          message: orderId,
                          child: Text(
                            orderId.length > 8
                                ? '#${orderId.substring(0, 8)}...'
                                : '#$orderId',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${amount.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3498DB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          deliveryMethod,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          clientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Color(0xFF3498DB),
                            ),
                            onPressed: () =>
                                _editOrderStatus(doc.id, data, clientName),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.visibility,
                              size: 18,
                              color: Color(0xFF2ECC71),
                            ),
                            onPressed: () => _viewOrderDetails(doc.id, data, clientName),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ============================================
  // ONGLET PARAMÈTRES
  // ============================================
  Widget _buildComingSoonTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.build,
            size: 80,
            color: Color(0xFF6D5DFC),
          ),
          const SizedBox(height: 20),
          const Text(
            'Paramètres',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Fonctionnalité en cours de développement',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // MÉTHODES D'AIDE
  // ============================================
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en attente':
        return const Color(0xFFF39C12);
      case 'confirmée':
        return const Color(0xFF3498DB);
      case 'en préparation':
        return const Color(0xFF9B59B6);
      case 'expédiée':
        return const Color(0xFF2ECC71);
      case 'livrée':
        return const Color(0xFF27AE60);
      case 'annulée':
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFF7F8C8D);
    }
  }

  IconData _getOrderStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'en attente':
        return Icons.pending;
      case 'confirmée':
        return Icons.check_circle;
      case 'en préparation':
        return Icons.local_shipping;
      case 'expédiée':
        return Icons.directions_car;
      case 'livrée':
        return Icons.home;
      case 'annulée':
        return Icons.cancel;
      default:
        return Icons.receipt;
    }
  }

  Color _getCategoryColor(String? category) {
    final cat = (category ?? '').toLowerCase();
    for (var catItem in _categories) {
      if (catItem['value'] == cat) {
        return catItem['color'] as Color;
      }
    }
    return const Color(0xFF7F8C8D);
  }

  String _getCategoryName(String? category) {
    final cat = (category ?? '').toLowerCase();
    for (var catItem in _categories) {
      if (catItem['value'] == cat) {
        return catItem['label'] as String;
      }
    }
    return cat.isNotEmpty ? cat : 'Non catégorisé';
  }

  // ============================================
  // GESTION DES IMAGES
  // ============================================
  Future<void> _pickImage() async {
    if (kIsWeb) {
      await _pickImageWeb();
    } else {
      await _pickImageMobile();
    }
  }

  Future<void> _pickImageMobile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
      });
    }
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) {
      await _pickImageWeb();
    } else {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    }
  }

  Future<void> _pickImageWeb() async {
    if (kIsWeb) {
      try {
        final pickedFile = await ImagePickerWeb.getImageAsBytes();

        if (pickedFile != null) {
          setState(() {
            _selectedImageBytes = pickedFile;
          });
        }
      } catch (e) {
        print('Erreur lors de la sélection d\'image web: $e');
      }
    }
  }

  Future<String?> _uploadImageToFirestore() async {
    if (_selectedImageBytes == null) return null;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final base64Image = base64Encode(_selectedImageBytes!);

      // Vérifier la taille
      if (base64Image.length > 900000) {
        throw Exception('Image trop grande (max 900KB en base64)');
      }

      setState(() => _uploadProgress = 0.3);
      await Future.delayed(const Duration(milliseconds: 200));

      final docRef = await _firestore.collection('product_images').add({
        'image_base64': base64Image,
        'created_at': FieldValue.serverTimestamp(),
        'size_bytes': _selectedImageBytes!.length,
        'type': 'image/jpeg',
      });

      setState(() => _uploadProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 200));

      final imageId = docRef.id;
      return 'firestore:$imageId';
    } catch (e) {
      print('❌ Erreur Firestore: $e');
      return null;
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Widget _buildFirestoreImage(String firestoreId) {
    final imageId = firestoreId.replaceFirst('firestore:', '');

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('product_images').doc(imageId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: const Color(0xFFEFE9E0),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: const Color(0xFFEFE9E0),
            ),
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final base64Image = data['image_base64'] as String?;

        if (base64Image == null || base64Image.isEmpty) {
          return Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: const Color(0xFFEFE9E0),
            ),
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
          );
        }

        try {
          return Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: const Color(0xFFEFE9E0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                base64Decode(base64Image),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, color: Colors.red, size: 24);
                },
              ),
            ),
          );
        } catch (e) {
          return Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: const Color(0xFFEFE9E0),
            ),
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
          );
        }
      },
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImageBytes != null) {
      return Container(
        width: 150,
        height: 150,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6D5DFC), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _selectedImageBytes!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Icon(Icons.error, color: Colors.red));
            },
          ),
        ),
      );
    } else if (_uploadedImageUrl != null) {
      if (_uploadedImageUrl!.startsWith('firestore:')) {
        return Container(
          width: 150,
          height: 150,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF6D5DFC), width: 2),
          ),
          child: _buildFirestoreImage(_uploadedImageUrl!),
        );
      }
      return Container(
        width: 150,
        height: 150,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6D5DFC), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            _uploadedImageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Icon(Icons.error, color: Colors.red));
            },
          ),
        ),
      );
    } else {
      return Container(
        width: 150,
        height: 150,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!, width: 2),
          color: Colors.grey[100],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 40, color: Colors.grey),
            SizedBox(height: 5),
            Text('Aucune image', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
  }

  Widget _buildUploadProgressIndicator() {
    if (!_isUploading) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: _uploadProgress,
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6D5DFC)),
        ),
        const SizedBox(height: 5),
        Text(
          'Enregistrement de l\'image... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
        ),
      ],
    );
  }

  // ============================================
  // DIALOGUES DE PRODUITS
  // ============================================
  Future<void> _showAddProductDialog() async {
    _selectedImageBytes = null;
    _uploadedImageUrl = null;
    _isUploading = false;
    _uploadProgress = 0.0;

    final formKey = GlobalKey<FormState>();
    final TextEditingController nomController = TextEditingController();
    final TextEditingController prixController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String selectedCategory = 'clothing';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Ajouter un produit'),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          children: [
                            _buildImagePreview(),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await _pickImage();
                                    setState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3498DB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 8,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.photo_library,
                                    size: 16,
                                  ),
                                  label: Text(
                                    kIsWeb ? 'Choisir fichier' : 'Galerie',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (!kIsWeb)
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await _takePhoto();
                                      setState(() {});
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2ECC71),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 15,
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                    ),
                                    label: const Text('Camera'),
                                  ),
                              ],
                            ),
                            if (_selectedImageBytes != null && !_isUploading)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final imageUrl =
                                        await _uploadImageToFirestore();
                                    if (imageUrl != null) {
                                      setState(() {
                                        _uploadedImageUrl = imageUrl;
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Erreur lors de l\'enregistrement de l\'image',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6D5DFC),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 8,
                                    ),
                                  ),
                                  icon: const Icon(Icons.upload, size: 16),
                                  label: const Text('Enregistrer l\'image'),
                                ),
                              ),
                            _buildUploadProgressIndicator(),
                            if (_uploadedImageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green[700],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Image enregistrée',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_selectedImageBytes != null && !_isUploading)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  'Taille: ${(_selectedImageBytes!.length / 1024).toStringAsFixed(1)} KB',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: nomController,
                          decoration: const InputDecoration(
                            labelText: 'Nom du produit *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.shopping_bag),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le nom est obligatoire';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: prixController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Prix (FCFA) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.money),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le prix est obligatoire';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Prix invalide';
                            }
                            if (double.parse(value) <= 0) {
                              return 'Le prix doit être positif';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Catégorie *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: _categories.map<DropdownMenuItem<String>>((
                            category,
                          ) {
                            return DropdownMenuItem<String>(
                              value: category['value'] as String,
                              child: Text(category['label'] as String),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            if (value != null) {
                              selectedCategory = value;
                              setState(() {});
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'La catégorie est obligatoire';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_uploadedImageUrl == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Veuillez sélectionner et enregistrer une image',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    if (formKey.currentState!.validate()) {
                      try {
                        final docRef = _firestore.collection('products').doc();
                        await _firestore.collection('products').add({
                          'id': docRef.id,
                          'nom': nomController.text.trim(),
                          'prix': double.parse(prixController.text.trim()),
                          'categorie': selectedCategory,
                          'image': _uploadedImageUrl!,
                          'image_type': 'firestore_base64',
                          'description': descriptionController.text.trim(),
                          'boutique_id': '',
                          'created_at': FieldValue.serverTimestamp(),
                        });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Produit ajouté avec succès !'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D5DFC),
                  ),
                  child: const Text('Ajouter le produit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editProduct(String productId, Map<String, dynamic> data) async {
    _selectedImageBytes = null;
    _uploadedImageUrl = data['image'] as String?;
    _isUploading = false;
    _uploadProgress = 0.0;

    final formKey = GlobalKey<FormState>();
    final TextEditingController nomController = TextEditingController(
      text: data['nom']?.toString() ?? '',
    );
    final TextEditingController prixController = TextEditingController(
      text: (data['prix'] ?? 0).toStringAsFixed(0),
    );
    final TextEditingController descriptionController = TextEditingController(
      text: data['description']?.toString() ?? '',
    );
    String selectedCategory = data['categorie']?.toString() ?? 'clothing';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifier le produit'),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          children: [
                            if (_selectedImageBytes != null)
                              Container(
                                width: 150,
                                height: 150,
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF6D5DFC),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _selectedImageBytes!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(Icons.error,
                                            color: Colors.red),
                                      );
                                    },
                                  ),
                                ),
                              )
                            else if (_uploadedImageUrl != null &&
                                _uploadedImageUrl!.startsWith('firestore:'))
                              Container(
                                width: 150,
                                height: 150,
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF6D5DFC),
                                    width: 2,
                                  ),
                                ),
                                child: _buildFirestoreImage(_uploadedImageUrl!),
                              )
                            else if (_uploadedImageUrl != null &&
                                _uploadedImageUrl!.isNotEmpty)
                              Container(
                                width: 150,
                                height: 150,
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF6D5DFC),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _uploadedImageUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(Icons.error,
                                            color: Colors.red),
                                      );
                                    },
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 150,
                                height: 150,
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 2,
                                  ),
                                  color: Colors.grey[100],
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image,
                                        size: 40, color: Colors.grey),
                                    SizedBox(height: 5),
                                    Text('Aucune image',
                                        style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await _pickImage();
                                    setState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3498DB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 8,
                                    ),
                                  ),
                                  icon: const Icon(Icons.photo_library,
                                      size: 16),
                                  label: Text(kIsWeb
                                      ? 'Changer image'
                                      : 'Galerie'),
                                ),
                                const SizedBox(width: 10),
                                if (!kIsWeb)
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await _takePhoto();
                                      setState(() {});
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2ECC71),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 15,
                                        vertical: 8,
                                      ),
                                    ),
                                    icon:
                                        const Icon(Icons.camera_alt, size: 16),
                                    label: const Text('Camera'),
                                  ),
                              ],
                            ),
                            if (_selectedImageBytes != null && !_isUploading)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final imageUrl =
                                        await _uploadImageToFirestore();
                                    if (imageUrl != null) {
                                      setState(() {
                                        _uploadedImageUrl = imageUrl;
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Nouvelle image enregistrée',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Erreur lors de l\'enregistrement de l\'image',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6D5DFC),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 8,
                                    ),
                                  ),
                                  icon: const Icon(Icons.upload, size: 16),
                                  label: const Text(
                                    'Enregistrer la nouvelle image',
                                  ),
                                ),
                              ),
                            _buildUploadProgressIndicator(),
                            if (_selectedImageBytes == null &&
                                _uploadedImageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.green[700], size: 16),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Image actuelle',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_selectedImageBytes != null &&
                                _uploadedImageUrl != null &&
                                _uploadedImageUrl!.startsWith('firestore:'))
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.green[700], size: 16),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Nouvelle image enregistrée',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: nomController,
                          decoration: const InputDecoration(
                            labelText: 'Nom du produit *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.shopping_bag),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le nom est obligatoire';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: prixController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Prix (FCFA) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.money),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le prix est obligatoire';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Prix invalide';
                            }
                            if (double.parse(value) <= 0) {
                              return 'Le prix doit être positif';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Catégorie *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: _categories.map<DropdownMenuItem<String>>((
                            category,
                          ) {
                            return DropdownMenuItem<String>(
                              value: category['value'] as String,
                              child: Text(category['label'] as String),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                selectedCategory = value;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'La catégorie est obligatoire';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_selectedImageBytes != null &&
                        _uploadedImageUrl == data['image']) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Veuillez enregistrer la nouvelle image avant de modifier le produit',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    if (formKey.currentState!.validate()) {
                      try {
                        await _firestore
                            .collection('products')
                            .doc(productId)
                            .update({
                          'nom': nomController.text.trim(),
                          'prix': double.parse(prixController.text.trim()),
                          'categorie': selectedCategory,
                          'image': _uploadedImageUrl ?? data['image'],
                          'image_type': 'firestore_base64',
                          'description': descriptionController.text.trim(),
                          'updated_at': FieldValue.serverTimestamp(),
                        });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Produit modifié avec succès !'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D5DFC),
                  ),
                  child: const Text('Enregistrer les modifications'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProduct(String productId, String productName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le produit'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "$productName" ?\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('products').doc(productId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$productName" supprimé avec succès'),
              backgroundColor: const Color(0xFF2ECC71),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: const Color(0xFFE74C3C),
            ),
          );
        }
      }
    }
  }

  // ============================================
  // GESTION DES COMMANDES
  // ============================================
  Future<void> _loadClientNames(List<String> userIds) async {
    if (userIds.isEmpty) return;

    final missingUserIds = userIds.where((id) => !_clientNames.containsKey(id)).toList();

    if (missingUserIds.isEmpty) return;

    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: missingUserIds)
          .get();

      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();
        final nom = userData['nom']?.toString() ?? 'Client inconnu';
        final prenom = userData['prenom']?.toString() ?? '';
        final fullName = prenom.isNotEmpty ? '$prenom $nom' : nom;

        _clientNames[doc.id] = fullName;
      }
    } catch (e) {
      print('Erreur lors du chargement des noms des clients: $e');
    }
  }

  String _getClientName(String userId) {
    return _clientNames[userId] ??
        'Client ${userId.length > 8 ? userId.substring(0, 8) + '...' : userId}';
  }

  Future<void> _editOrderStatus(
      String orderId, Map<String, dynamic> data, String clientName) async {
    String currentStatus = data['status']?.toString() ?? 'En attente';
    String currentDeliveryMethod =
        data['methodeLivraison']?.toString() ?? 'Standard';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifier la commande'),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt, size: 20, color: Color(0xFF6D5DFC)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Commande #${data['id']?.toString().substring(0, 8)}...',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Client: $clientName',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text('Statut de la commande:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 5),
                      DropdownButtonFormField<String>(
                        value: currentStatus,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _orderStatuses.map<DropdownMenuItem<String>>(
                          (status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          },
                        ).toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              currentStatus = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 15),
                      const Text('Méthode de livraison:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 5),
                      DropdownButtonFormField<String>(
                        value: currentDeliveryMethod,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _deliveryMethods.map<DropdownMenuItem<String>>(
                          (method) {
                            return DropdownMenuItem<String>(
                              value: method,
                              child: Text(method),
                            );
                          },
                        ).toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              currentDeliveryMethod = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 15),
                      const Divider(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Date: ${data['createdAt']?.toString() ?? 'Non spécifiée'}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.money, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Montant: ${(data['total'] ?? 0).toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _firestore.collection('orders').doc(orderId).update({
                        'status': currentStatus,
                        'deliveryType': currentDeliveryMethod,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Commande mise à jour avec succès !'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D5DFC),
                  ),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _viewOrderDetails(String orderId, Map<String, dynamic> data, String clientName) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Détails de la commande'),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailCard(
                    Icons.receipt,
                    'Commande',
                    '#${orderId.length > 12 ? orderId.substring(0, 12) + "..." : orderId}',
                  ),
                  const SizedBox(height: 15),
                  _buildDetailCard(
                    Icons.person,
                    'Client',
                    clientName,
                  ),
                  const SizedBox(height: 15),
                  _buildDetailCard(
                    Icons.calendar_today,
                    'Date',
                    data['createdAt']?.toString() ?? 'Non spécifiée',
                  ),
                  const SizedBox(height: 15),
                  _buildDetailCard(
                    Icons.money,
                    'Montant Total',
                    '${(data['total'] ?? 0).toStringAsFixed(0)} FCFA',
                    isAmount: true,
                  ),
                  const SizedBox(height: 15),
                  _buildDetailCard(
                    Icons.local_shipping,
                    'Méthode de livraison',
                    data['deliveryType']?.toString() ?? 'pickup',
                  ),
                  const SizedBox(height: 15),
                  _buildDetailCard(
                    Icons.info,
                    'Statut',
                    data['status']?.toString() ?? 'En attente',
                    status: data['status']?.toString(),
                  ),
                  const SizedBox(height: 20),
                  if (data['note'].toString().isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Note:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(data['note']?.toString() ?? ''),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailCard(IconData icon, String label, String value,
      {bool isAmount = false, String? status}) {
    Color valueColor = Colors.black;

    if (isAmount) {
      valueColor = const Color(0xFF2C3E50);
    } else if (status != null) {
      valueColor = _getStatusColor(status);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: const Color(0xFF6D5DFC)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor,
                    fontWeight: isAmount ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _orderSearchController.dispose();
    super.dispose();
  }
}
