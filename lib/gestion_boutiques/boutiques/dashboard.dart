// lib/gestion_boutiques/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:typed_data';
import 'package:gestion_courses/firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart'; // Utilisez ce package UNIQUEMENT
import 'dart:convert';
import 'package:intl/intl.dart';

// Couleurs du design
const Color softIvory = Color(0xFFEFE9E0);
const Color tropicalTeal = Color(0xFF0F9E99);
const Color darkText = Color(0xFF2C3E50);
const Color mediumText = Color(0xFF5D6D7E);
const Color lightText = Color(0xFF95A5A6);
const Color accentColor = Color(0xFF6D5DFC); // Gardé pour certains éléments

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
        primaryColor: tropicalTeal,
        scaffoldBackgroundColor: softIvory,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: MaterialColor(
            tropicalTeal.value,
            const {
              50: Color(0xFFE0F2F1),
              100: Color(0xFFB2DFDB),
              200: Color(0xFF80CBC4),
              300: Color(0xFF4DB6AC),
              400: Color(0xFF26A69A),
              500: tropicalTeal,
              600: Color(0xFF00897B),
              700: Color(0xFF00796B),
              800: Color(0xFF00695C),
              900: Color(0xFF004D40),
            },
          ),
          backgroundColor: softIvory,
        ),
      ),
      home: const AdminDashboard(
        boutiqueId: 'test_boutique',
        boutiqueName: 'Ma Boutique',
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AdminDashboard extends StatefulWidget {
  final String boutiqueId;
  final String boutiqueName;

  const AdminDashboard({
    super.key,
    required this.boutiqueId,
    required this.boutiqueName,
  });

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
      'color': tropicalTeal,
    },
    {
      'value': 'shoes',
      'label': 'Chaussures',
      'color': Color(0xFF2ECC71),
    },
    {
      'value': 'accessories',
      'label': 'Accessoires',
      'color': Color(0xFFF39C12),
    },
    {
      'value': 'electronics',
      'label': 'Électronique',
      'color': Color(0xFF3498DB),
    },
    {
      'value': 'food',
      'label': 'Aliments',
      'color': Color(0xFF9B59B6),
    },
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
  void initState() {
    super.initState();
    _loadClientNames();
  }

  Future<void> _loadClientNames() async {
    try {
      // Charger les noms des clients qui ont commandé dans cette boutique
      final orders = await _firestore
          .collection('orders')
          .where('boutiqueId', isEqualTo: widget.boutiqueId)
          .get();

      final userIds = orders.docs
          .map((doc) => (doc.data()['userId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (userIds.isEmpty) return;

      final usersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Barre de navigation supérieure
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  // Bouton retour
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: tropicalTeal,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 15),
                  // Logo/Nom de la boutique
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tropicalTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.store,
                      color: tropicalTeal,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.boutiqueName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: darkText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Tableau de bord administrateur',
                          style: TextStyle(
                            fontSize: 12,
                            color: mediumText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Sidebar
                Container(
                  width: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(25),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: tropicalTeal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: tropicalTeal.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.store_mall_directory,
                                color: tropicalTeal,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              widget.boutiqueName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: darkText,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Boutique ID: ${widget.boutiqueId.substring(0, 8)}...',
                              style: TextStyle(
                                fontSize: 11,
                                color: lightText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: softIvory, height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(10),
                          children: [
                            _buildNavItem(
                              0,
                              Icons.dashboard_rounded,
                              'Tableau de bord',
                              isActive: _selectedIndex == 0,
                            ),
                            _buildNavItem(
                              1,
                              Icons.inventory_2_rounded,
                              'Produits',
                              isActive: _selectedIndex == 1,
                            ),
                            _buildNavItem(
                              2,
                              Icons.shopping_cart_checkout_rounded,
                              'Commandes',
                              isActive: _selectedIndex == 2,
                            ),
                            _buildNavItem(
                              3,
                              Icons.settings_rounded,
                              'Paramètres',
                              isActive: _selectedIndex == 3,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tropicalTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: tropicalTeal,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Admin Dashboard',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tropicalTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, color: softIvory),

                // Contenu principal
                Expanded(
                  child: Container(
                    color: softIvory,
                    padding: const EdgeInsets.all(25),
                    child: _buildSelectedTab(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String title, {
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? tropicalTeal : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.white : mediumText,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : darkText,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        trailing: isActive
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            : null,
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
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
        return _buildSettingsTab();
      default:
        return _buildDashboardTab();
    }
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
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: tropicalTeal,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Aperçu général de votre boutique',
              style: TextStyle(
                fontSize: 16,
                color: mediumText,
              ),
            ),
            const SizedBox(height: 30),

            // Cartes de statistiques
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('products')
                  .where('boutique_id', isEqualTo: widget.boutiqueId)
                  .snapshots(),
              builder: (context, snapshot) {
                final totalProducts =
                    snapshot.hasData ? snapshot.data!.docs.length : 0;

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('orders')
                      .where('boutiqueId', isEqualTo: widget.boutiqueId)
                      .snapshots(),
                  builder: (context, orderSnapshot) {
                    final totalOrders = orderSnapshot.hasData
                        ? orderSnapshot.data!.docs.length
                        : 0;
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

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 1000 ? 4 : 2,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 1.8,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            return _buildStatCard(
                              title: 'Produits',
                              value: totalProducts.toString(),
                              icon: Icons.inventory_2_rounded,
                              color: tropicalTeal,
                              subtitle: 'en stock',
                            );
                          case 1:
                            return _buildStatCard(
                              title: 'Commandes',
                              value: totalOrders.toString(),
                              icon: Icons.shopping_cart_checkout_rounded,
                              color: Color(0xFF2ECC71),
                              subtitle: 'au total',
                            );
                          case 2:
                            return _buildStatCard(
                              title: 'En attente',
                              value: pendingOrders.toString(),
                              icon: Icons.pending_actions_rounded,
                              color: Color(0xFF3498DB),
                              subtitle: 'commandes',
                            );
                          default:
                            return Container();
                        }
                      },
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
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2), width: 2),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 28),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: mediumText,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: lightText,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: color.withOpacity(0.5),
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
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
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
                    fontWeight: FontWeight.w700,
                    color: tropicalTeal,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: tropicalTeal,
                  ),
                  child: const Row(
                    children: [
                      Text('Voir tout'),
                      SizedBox(width: 5),
                      Icon(Icons.arrow_forward_ios, size: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('orders')
                    .where('boutiqueId', isEqualTo: widget.boutiqueId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: tropicalTeal),
                    );
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
                            style: TextStyle(color: lightText),
                          ),
                        ],
                      ),
                    );
                  }

                  // TRI LOCAL des commandes par date
                  final orders = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aDate = aData['createdAt'] as Timestamp?;
                      final bDate = bData['createdAt'] as Timestamp?;

                      final aTime = aDate?.millisecondsSinceEpoch ?? 0;
                      final bTime = bDate?.millisecondsSinceEpoch ?? 0;

                      return bTime.compareTo(aTime);
                    });

                  // Prendre seulement les 5 premières commandes
                  final recentOrders = orders.take(5).toList();

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: recentOrders.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: softIvory),
                    itemBuilder: (context, index) {
                      final doc = recentOrders[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final orderId = doc.id;
                      final amount = (data['total'] ?? 0).toDouble();
                      final status = data['status']?.toString() ?? 'pending';
                      final ts = data['createdAt'] as Timestamp?;
                      String formattedDate = '';
                      if (ts != null) {
                        try {
                          formattedDate =
                              DateFormat('dd/MM/yy HH:mm').format(ts.toDate());
                        } catch (e) {
                          formattedDate = ts.toDate().toString();
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                          leading: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _getStatusColor(status).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _getOrderStatusIcon(status),
                              color: _getStatusColor(status),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            _getProductNameFromOrder(data),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: darkText,
                            ),
                          ),
                          subtitle: Text(
                            formattedDate,
                            style: TextStyle(fontSize: 12, color: mediumText),
                          ),
                          trailing: SizedBox(
                            width: 120,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${amount.toStringAsFixed(0)} FCFA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: tropicalTeal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
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
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
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
                fontWeight: FontWeight.w700,
                color: tropicalTeal,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('products')
                    .where('boutique_id', isEqualTo: widget.boutiqueId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: tropicalTeal),
                    );
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
                            style: TextStyle(color: lightText, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  final products = snapshot.data!.docs;
                  final categoryCounts = <String, int>{};

                  for (var doc in products) {
                    final data = doc.data() as Map<String, dynamic>;
                    final category =
                        data['categorie']?.toString() ?? 'Non catégorisé';
                    categoryCounts[category] =
                        (categoryCounts[category] ?? 0) + 1;
                  }

                  final sortedCategories = categoryCounts.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: sortedCategories.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: softIvory),
                    itemBuilder: (context, index) {
                      final entry = sortedCategories[index];
                      final categoryName = _getCategoryName(entry.key);
                      final count = entry.value;
                      final totalProducts = products.length;
                      final percentage =
                          totalProducts > 0 ? (count / totalProducts * 100) : 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 5),
                          leading: Container(
                            width: 35,
                            height: 35,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(entry.key),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: _getCategoryColor(entry.key)
                                      .withOpacity(0.3),
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                categoryName.substring(0, 1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  categoryName.length > 15
                                      ? '${categoryName.substring(0, 15)}...'
                                      : categoryName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: darkText,
                                  ),
                                ),
                              ),
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: tropicalTeal,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: softIvory,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getCategoryColor(entry.key),
                                  ),
                                  minHeight: 4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: mediumText,
                                    ),
                                  ),
                                  Text(
                                    '${count} sur $totalProducts',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: lightText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  // ============================================
  // ONGLET PRODUITS
  // ============================================
  Widget _buildProductsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête - FIXE
        Text(
          'Gestion des Produits',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: tropicalTeal,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Gérez les produits de votre boutique',
          style: TextStyle(
            fontSize: 16,
            color: mediumText,
          ),
        ),
        const SizedBox(height: 30),

        // Barre de recherche et bouton d'ajout - FIXE
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: tropicalTeal,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un produit...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: lightText,
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
                        icon: Icon(Icons.clear, size: 18, color: lightText),
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
            ),
            const SizedBox(width: 15),
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: tropicalTeal.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _showAddProductDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tropicalTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Ajouter un produit'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),

        // Table des produits - EXPANDABLE
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
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
      stream: _firestore
          .collection('products')
          .where('boutique_id', isEqualTo: widget.boutiqueId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Color(0xFFE74C3C), size: 50),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Erreur: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: mediumText),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: tropicalTeal),
                const SizedBox(height: 15),
                Text('Chargement des produits...',
                    style: TextStyle(color: mediumText)),
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
                Icon(
                  Icons.inventory_2_outlined,
                  size: 60,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'Aucun produit disponible dans cette boutique'
                        : 'Aucun produit trouvé pour "$_searchQuery"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: mediumText,
                    ),
                  ),
                ),
                if (_searchQuery.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddProductDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tropicalTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Ajouter votre premier produit'),
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
              columnSpacing: 25,
              horizontalMargin: 25,
              headingRowHeight: 60,
              dataRowHeight: 70,
              headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) {
                  return softIvory;
                },
              ),
              columns: [
                DataColumn(
                  label: Text(
                    'Image',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Nom',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Prix',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Catégorie',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
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
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: softIvory,
                          border: Border.all(
                              color: tropicalTeal.withOpacity(0.2), width: 1),
                        ),
                        child: imageRef != null && imageRef.isNotEmpty
                            ? imageRef.startsWith('firestore:')
                                ? _buildFirestoreImage(imageRef)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageRef,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: tropicalTeal,
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Center(
                                          child: Icon(
                                            Icons.broken_image_rounded,
                                            color: tropicalTeal,
                                            size: 24,
                                          ),
                                        );
                                      },
                                    ),
                                  )
                            : Icon(
                                Icons.shopping_bag_rounded,
                                color: tropicalTeal,
                                size: 24,
                              ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Text(
                          data['nom']?.toString() ?? 'Sans nom',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: darkText,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${(data['prix'] ?? 0).toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tropicalTeal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(data['categorie'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getCategoryColor(data['categorie'])
                                .withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getCategoryName(data['categorie']),
                          style: TextStyle(
                            color: _getCategoryColor(data['categorie']),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Color(0xFF3498DB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: Color(0xFF3498DB),
                              ),
                              onPressed: () => _editProduct(doc.id, data),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Color(0xFFE74C3C).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.delete_rounded,
                                size: 18,
                                color: Color(0xFFE74C3C),
                              ),
                              onPressed: () => _deleteProduct(
                                doc.id,
                                data['nom']?.toString() ?? 'ce produit',
                              ),
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
        // En-tête
        Text(
          'Gestion des Commandes',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: tropicalTeal,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Suivez et gérez les commandes de votre boutique',
          style: TextStyle(
            fontSize: 16,
            color: mediumText,
          ),
        ),
        const SizedBox(height: 30),

        // Barre de recherche
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: tropicalTeal,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _orderSearchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une commande...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: lightText,
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
                  icon: Icon(Icons.clear, size: 18, color: lightText),
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
        const SizedBox(height: 25),

        // Table des commandes
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
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
      stream: _firestore
          .collection('orders')
          .where('boutiqueId', isEqualTo: widget.boutiqueId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Color(0xFFE74C3C), size: 50),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Erreur: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: mediumText),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: tropicalTeal),
                const SizedBox(height: 15),
                Text('Chargement des commandes...',
                    style: TextStyle(color: mediumText)),
              ],
            ),
          );
        }

        final orders = snapshot.data!.docs;

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
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 60,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _orderSearchQuery.isEmpty
                        ? 'Aucune commande pour cette boutique'
                        : 'Aucune commande trouvée pour "$_orderSearchQuery"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: mediumText,
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
              columnSpacing: 25,
              horizontalMargin: 25,
              headingRowHeight: 60,
              dataRowHeight: 70,
              headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) {
                  return softIvory;
                },
              ),
              columns: [
                DataColumn(
                  label: Text(
                    'Produit',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Montant',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Statut',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Client',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
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
                final userId = data['userId']?.toString() ?? 'N/A';
                final clientName = _getClientName(userId);

                // Formater la date
                String formattedDate = 'Date inconnue';

                try {
                  final dynamic dateData = data['createdAt'];

                  if (dateData != null) {
                    if (dateData is Timestamp) {
                      // Cas 1: C'est un Timestamp Firebase normal
                      formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss')
                          .format(dateData.toDate());
                    } else if (dateData is String &&
                        dateData.contains('Timestamp')) {
                      // Cas 2: C'est une string "Timestamp(seconds=..., nanoseconds=...)"
                      final secondsMatch =
                          RegExp(r'seconds=(\d+)').firstMatch(dateData);
                      if (secondsMatch != null) {
                        final seconds = int.parse(secondsMatch.group(1)!);
                        final date =
                            DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
                        formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss')
                            .format(date);
                      } else {
                        formattedDate = 'Format timestamp invalide';
                      }
                    } else if (dateData is String) {
                      // Cas 3: C'est déjà une string de date
                      try {
                        final parsedDate = DateTime.parse(dateData);
                        formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss')
                            .format(parsedDate);
                      } catch (e) {
                        formattedDate = dateData; // Afficher tel quel
                      }
                    } else {
                      // Cas 4: Autre format, on affiche la représentation string
                      formattedDate = dateData.toString();
                    }
                  }
                } catch (e) {
                  formattedDate = 'Erreur date';
                  print('Erreur conversion date: $e');
                }

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Tooltip(
                          message: _getProductNameFromOrder(data),
                          child: Text(
                            _getProductNameFromOrder(data),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: darkText,
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
                          style: TextStyle(fontSize: 12, color: mediumText),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${amount.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tropicalTeal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getStatusColor(status).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          data['status'] ?? 'En attente',
                          style: TextStyle(
                            color: _getStatusColor(data['status']),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Text(
                          clientName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: darkText,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          // Bouton Voir détails
                          Container(
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF3498DB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.visibility_rounded,
                                  size: 18, color: Color(0xFF3498DB)),
                              onPressed: () => _viewOrderDetails(
                                  doc.id, data, clientName),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Menu pour changer le statut
                          Container(
                            decoration: BoxDecoration(
                              color: tropicalTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: PopupMenuButton<String>(
                              onSelected: (value) =>
                                  _updateOrderStatus(orderId, value),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 'En préparation',
                                    child: Text('En préparation')),
                                const PopupMenuItem(
                                    value: 'Prêt', child: Text('Prêt')),
                                const PopupMenuItem(
                                    value: 'Livrée', child: Text('Livrée')),
                                const PopupMenuItem(
                                    value: 'Annulée', child: Text('Annulée')),
                              ],
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
  // ONGLET PARAMÈTRES
  // ============================================
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Text(
              'Paramètres de la boutique',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: tropicalTeal,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Gérez les paramètres de ${widget.boutiqueName}',
              style: TextStyle(
                fontSize: 16,
                color: mediumText,
              ),
            ),
            const SizedBox(height: 30),

            // Informations de la boutique
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informations de la boutique',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
                  ),
                  const SizedBox(height: 25),
                  StreamBuilder<DocumentSnapshot>(
                    stream: _firestore
                        .collection('boutiques')
                        .doc(widget.boutiqueId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                            child:
                                CircularProgressIndicator(color: tropicalTeal));
                      }

                      final data =
                          snapshot.data!.data() as Map<String, dynamic>? ?? {};

                      return Column(
                        children: [
                          _buildSettingItem(
                            'Nom de la boutique',
                            data['nom'] ?? widget.boutiqueName,
                            icon: Icons.store_rounded,
                          ),
                          const SizedBox(height: 20),
                          _buildSettingItem(
                            'Adresse',
                            data['adresse'] ?? 'Non définie',
                            icon: Icons.location_on_rounded,
                          ),
                          const SizedBox(height: 20),
                          _buildSettingItem(
                            'Catégorie',
                            data['categories'] ?? 'Général',
                            icon: Icons.category_rounded,
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton.icon(
                            onPressed: () => _editBoutiqueSettings(data),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tropicalTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Modifier les informations'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Actions administratives
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actions administratives',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: tropicalTeal,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Column(
                    children: [
                      _buildActionTile(
                        Icons.delete_outline_rounded,
                        'Supprimer la boutique',
                        'Cette action est irréversible',
                        Color(0xFFE74C3C),
                        () => _deleteBoutique(),
                      ),
                      const Divider(color: softIvory),
                      _buildActionTile(
                        Icons.notifications_active_rounded,
                        'Notifications',
                        'Gérer les notifications',
                        Color(0xFF3498DB),
                        () {},
                      ),
                      const Divider(color: softIvory),
                      _buildActionTile(
                        Icons.security_rounded,
                        'Sécurité',
                        'Paramètres de sécurité',
                        Color(0xFF2ECC71),
                        () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(String label, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null)
              Icon(
                icon,
                color: tropicalTeal,
                size: 18,
              ),
            if (icon != null) const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: mediumText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: softIvory,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tropicalTeal.withOpacity(0.2), width: 1),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: darkText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: mediumText,
          fontSize: 12,
        ),
      ),
      trailing: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: tropicalTeal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: tropicalTeal),
          onPressed: onTap,
          padding: EdgeInsets.zero,
        ),
      ),
      onTap: onTap,
    );
  }

  // ============================================
  // MÉTHODES D'AIDE
  // ============================================
  Color _getStatusColor(String status) {
    if (status == null) return const Color(0xFF7F8C8D);

    if (status.contains('attente') || status == 'En attente') {
      return const Color(0xFFF39C12);
    } else if (status.contains('préparation') || status == 'En préparation') {
      return const Color(0xFF9B59B6);
    } else if (status.contains('Prêt') || status == 'Prêt') {
      return const Color(0xFF2ECC71);
    } else if (status.contains('Livrée') || status == 'Livrée') {
      return const Color(0xFF27AE60);
    } else if (status.contains('Annulée') || status == 'Annulée') {
      return const Color(0xFFE74C3C);
    }
    return const Color(0xFF7F8C8D);
  }

  IconData _getOrderStatusIcon(String status) {
    if (status == null || status.isEmpty) return Icons.receipt;

    if (status.contains('En attente')) return Icons.pending;
    if (status.contains('En préparation')) return Icons.local_shipping;
    if (status.contains('Prêt')) return Icons.check_circle_outline;
    if (status.contains('Livrée')) return Icons.home;
    if (status.contains('Annulée')) return Icons.cancel;

    return Icons.receipt;
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

  String _getClientName(String userId) {
    return _clientNames[userId] ??
        'Client ${userId.length > 8 ? userId.substring(0, 8) + '...' : userId}';
  }

  // ============================================
  // GESTION DES IMAGES - VERSION CORRIGÉE
  // ============================================
  Future<void> _pickImage() async {
    // Utilisez uniquement image_picker qui fonctionne sur toutes les plateformes
    await _pickImageMobile();
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
    // Utilisez uniquement image_picker qui fonctionne aussi sur web
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
                                  label: const Text('Sélectionner'),
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
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
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
                          items: _categories.map<DropdownMenuItem<String>>(
                            (category) {
                              return DropdownMenuItem<String>(
                                value: category['value'] as String,
                                child: Text(category['label'] as String),
                              );
                            },
                          ).toList(),
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
                          'boutique_id': widget.boutiqueId,
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
                                  icon:
                                      const Icon(Icons.photo_library, size: 16),
                                  label: const Text('Changer image'),
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
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Nouvelle image enregistrée',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
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
                          items: _categories.map<DropdownMenuItem<String>>(
                            (category) {
                              return DropdownMenuItem<String>(
                                value: category['value'] as String,
                                child: Text(category['label'] as String),
                              );
                            },
                          ).toList(),
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
  Future<void> _viewOrderDetails(
      String orderId, Map<String, dynamic> data, String clientName) async {
    // Formater la date
    String formattedDate = 'Non spécifiée';
    try {
      final dynamic dateData = data['createdAt'];
      if (dateData != null) {
        if (dateData is Timestamp) {
          formattedDate =
              DateFormat('dd/MM/yyyy HH:mm:ss').format(dateData.toDate());
        } else if (dateData is String && dateData.contains('Timestamp')) {
          final secondsMatch = RegExp(r'seconds=(\d+)').firstMatch(dateData);
          if (secondsMatch != null) {
            final seconds = int.parse(secondsMatch.group(1)!);
            final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
            formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss').format(date);
          }
        }
      }
    } catch (e) {
      formattedDate = data['createdAt']?.toString() ?? 'Date invalide';
    }

    // Traduire deliveryType
    String deliveryMethod = 'Retrait en boutique';
    if (data['deliveryType'] == 'delivery') {
      deliveryMethod = 'Livraison à domicile';
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Détails de la commande'),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Informations client
                  _buildDetailCard(
                    Icons.person,
                    'Client',
                    clientName,
                  ),
                  const SizedBox(height: 15),

                  _buildDetailCard(
                    Icons.receipt,
                    'Commande',
                    _getProductNameFromOrder(data),
                  ),
                  const SizedBox(height: 15),

                  _buildDetailCard(
                    Icons.calendar_today,
                    'Date',
                    formattedDate,
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
                    deliveryMethod,
                  ),
                  const SizedBox(height: 15),

                  _buildDetailCard(
                    Icons.info,
                    'Statut',
                    data['status']?.toString() ?? 'En attente',
                    status: data['status']?.toString(),
                  ),

                  // Liste des produits commandés
                  const SizedBox(height: 20),
                  const Text(
                    'Produits commandés:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (data['items'] != null && (data['items'] as List).isNotEmpty)
                    ...(data['items'] as List).map<Widget>((item) {
                      final itemMap = item as Map<String, dynamic>;

                      final quantity = itemMap['quantity'] ?? 1;
                      final productName = itemMap['name']?.toString() ?? 'Produit';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: const Color(0xFFEFE9E0), width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F9E99).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.shopping_bag,
                                color: Color(0xFF0F9E99),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Quantité: $quantity',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF5D6D7E),
                                    ),
                                  ),
                                  // Description
                                  if (itemMap['description'] != null &&
                                      itemMap['description'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        itemMap['description'].toString(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF95A5A6),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList()
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Aucun produit dans cette commande',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),

                  // Notes du client
                  const SizedBox(height: 20),
                  if (data['customerNotes'] != null &&
                      data['customerNotes'].toString().isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Note du client:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFE9E0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            data['customerNotes'].toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF5D6D7E),
                            ),
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
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // Stocker DIRECTEMENT en français
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut mis à jour: $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('✅ Stocké en français: "$newStatus"');
    } catch (e) {
      print('❌ Erreur: $e');
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

  Widget _buildDetailCard(IconData icon, String label, String value,
      {bool isAmount = false, String? status}) {
    Color valueColor = const Color(0xFF2C3E50);

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
        border: Border.all(color: const Color(0xFFEFE9E0)),
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
          Icon(icon, size: 24, color: const Color(0xFF0F9E99)),
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

  // ============================================
  // GESTION DES PARAMÈTRES DE LA BOUTIQUE
  // ============================================
  Future<void> _editBoutiqueSettings(Map<String, dynamic> data) async {
    final TextEditingController nomController =
        TextEditingController(text: data['nom'] ?? widget.boutiqueName);
    final TextEditingController adresseController =
        TextEditingController(text: data['adresse'] ?? '');
    final TextEditingController categorieController =
        TextEditingController(text: data['categories'] ?? 'Général');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier les informations de la boutique'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la boutique',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: adresseController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: categorieController,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
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
                  await _firestore
                      .collection('boutiques')
                      .doc(widget.boutiqueId)
                      .update({
                    'nom': nomController.text.trim(),
                    'adresse': adresseController.text.trim(),
                    'categories': categorieController.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Boutique mise à jour avec succès !'),
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
  }

  Future<void> _deleteBoutique() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la boutique'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette boutique ?\nTous les produits et commandes associés seront également supprimés.\nCette action est irréversible.',
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
        // Supprimer la boutique
        await _firestore
            .collection('boutiques')
            .doc(widget.boutiqueId)
            .delete();

        // Supprimer les produits de cette boutique
        final products = await _firestore
            .collection('products')
            .where('boutique_id', isEqualTo: widget.boutiqueId)
            .get();

        for (var doc in products.docs) {
          await doc.reference.delete();
        }

        // Supprimer les commandes de cette boutique
        final orders = await _firestore
            .collection('orders')
            .where('boutiqueId', isEqualTo: widget.boutiqueId)
            .get();

        for (var doc in orders.docs) {
          await doc.reference.delete();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Boutique supprimée avec succès'),
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
  }

  // ============================================
  // MÉTHODES UTILITAIRES MANQUANTES
  // ============================================
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
        'boutique_id': widget.boutiqueId,
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

  String _getProductNameFromOrder(Map<String, dynamic> orderData) {
    try {
      if (orderData['items'] != null && (orderData['items'] as List).isNotEmpty) {
        final firstItem = (orderData['items'] as List)[0];
        final productName = firstItem['name']?.toString() ?? 'Produit';
        
        // Tronquer si trop long
        if (productName.length > 20) {
          return '${productName.substring(0, 20)}...';
        }
        return productName;
      }
    } catch (e) {
      print('Erreur nom produit: $e');
    }
    return 'Commande';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _orderSearchController.dispose();
    super.dispose();
  }
}