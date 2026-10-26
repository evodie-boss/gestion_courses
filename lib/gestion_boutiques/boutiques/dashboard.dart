// lib/gestion_boutiques/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:typed_data';
import 'package:gestion_courses/firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

// Couleurs du design
const Color softIvory = Color(0xFFEFE9E0);
const Color tropicalTeal = Color(0xFF0F9E99);
const Color darkText = Color(0xFF2C3E50);
const Color mediumText = Color(0xFF5D6D7E);
const Color lightText = Color(0xFF95A5A6);
const Color accentColor = Color(0xFF6D5DFC);

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

// ============================================================
// HELPER: Breakpoints
// ============================================================
class _Screen {
  static bool isMobile(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width < 600;
  static bool isTablet(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 600 &&
      MediaQuery.of(ctx).size.width < 1024;
  static bool isDesktop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 1024;
  static double width(BuildContext ctx) => MediaQuery.of(ctx).size.width;
  static double height(BuildContext ctx) => MediaQuery.of(ctx).size.height;
}

// ============================================================
// MAIN WIDGET
// ============================================================
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
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _orderSearchController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  String _searchQuery = '';
  String _orderSearchQuery = '';
  double _uploadProgress = 0.0;

  Map<String, String> _clientNames = {};

  final List<Map<String, dynamic>> _categories = [
    {'value': 'clothing', 'label': 'Vêtements', 'color': tropicalTeal},
    {'value': 'shoes', 'label': 'Chaussures', 'color': Color(0xFF2ECC71)},
    {'value': 'accessories', 'label': 'Accessoires', 'color': Color(0xFFF39C12)},
    {'value': 'electronics', 'label': 'Électronique', 'color': Color(0xFF3498DB)},
    {'value': 'food', 'label': 'Aliments', 'color': Color(0xFF9B59B6)},
  ];

  final List<String> _orderStatuses = [
    'En attente', 'Confirmée', 'En préparation', 'Expédiée', 'Livrée', 'Annulée'
  ];

  @override
  void initState() {
    super.initState();
    _loadClientNames();
  }

  Future<void> _loadClientNames() async {
    try {
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
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Erreur chargement clients: $e');
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isMobile = _Screen.isMobile(context);

    if (isMobile) {
      return _buildMobileScaffold();
    } else {
      return _buildDesktopScaffold();
    }
  }

  // ---- MOBILE ----
  Widget _buildMobileScaffold() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: softIvory,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: tropicalTeal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.boutiqueName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: darkText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Tableau de bord',
              style: TextStyle(fontSize: 11, color: mediumText),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: tropicalTeal),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildSelectedTab(),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              color: tropicalTeal.withOpacity(0.05),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tropicalTeal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store, color: tropicalTeal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.boutiqueName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  _buildNavItem(0, Icons.dashboard_rounded, 'Tableau de bord', isActive: _selectedIndex == 0, isDrawer: true),
                  _buildNavItem(1, Icons.inventory_2_rounded, 'Produits', isActive: _selectedIndex == 1, isDrawer: true),
                  _buildNavItem(2, Icons.shopping_cart_checkout_rounded, 'Commandes', isActive: _selectedIndex == 2, isDrawer: true),
                  _buildNavItem(3, Icons.settings_rounded, 'Paramètres', isActive: _selectedIndex == 3, isDrawer: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- DESKTOP / TABLET ----
  Widget _buildDesktopScaffold() {
    return Scaffold(
      body: Column(
        children: [
          // Top bar
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: tropicalTeal),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tropicalTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.store, color: tropicalTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.boutiqueName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: darkText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Tableau de bord administrateur',
                          style: TextStyle(fontSize: 11, color: mediumText),
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
                  width: _Screen.isTablet(context) ? 200 : 240,
                  color: Colors.white,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: tropicalTeal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: tropicalTeal.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.store_mall_directory,
                                color: tropicalTeal,
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.boutiqueName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: darkText,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${widget.boutiqueId.length > 8 ? widget.boutiqueId.substring(0, 8) : widget.boutiqueId}...',
                              style: const TextStyle(fontSize: 11, color: lightText),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: softIvory, height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(8),
                          children: [
                            _buildNavItem(0, Icons.dashboard_rounded, 'Tableau de bord', isActive: _selectedIndex == 0),
                            _buildNavItem(1, Icons.inventory_2_rounded, 'Produits', isActive: _selectedIndex == 1),
                            _buildNavItem(2, Icons.shopping_cart_checkout_rounded, 'Commandes', isActive: _selectedIndex == 2),
                            _buildNavItem(3, Icons.settings_rounded, 'Paramètres', isActive: _selectedIndex == 3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const VerticalDivider(width: 1, color: softIvory),

                Expanded(
                  child: Container(
                    color: softIvory,
                    padding: EdgeInsets.all(_Screen.isTablet(context) ? 16 : 24),
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
    bool isDrawer = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? tropicalTeal : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: isActive ? Colors.white : mediumText, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : darkText,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: () {
          setState(() => _selectedIndex = index);
          if (isDrawer) Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardTab();
      case 1: return _buildProductsTab();
      case 2: return _buildOrdersTab();
      case 3: return _buildSettingsTab();
      default: return _buildDashboardTab();
    }
  }

  // ============================================================
  // DASHBOARD TAB
  // ============================================================
  Widget _buildDashboardTab() {
    final isMobile = _Screen.isMobile(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tableau de bord',
              style: TextStyle(
                fontSize: isMobile ? 22 : 26,
                fontWeight: FontWeight.w700,
                color: tropicalTeal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aperçu général de votre boutique',
              style: TextStyle(fontSize: isMobile ? 13 : 15, color: mediumText),
            ),
            const SizedBox(height: 24),

            // Stats cards
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('products')
                  .where('boutique_id', isEqualTo: widget.boutiqueId)
                  .snapshots(),
              builder: (context, productSnap) {
                final totalProducts = productSnap.hasData ? productSnap.data!.docs.length : 0;

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('orders')
                      .where('boutiqueId', isEqualTo: widget.boutiqueId)
                      .snapshots(),
                  builder: (context, orderSnap) {
                    int totalOrders = 0;
                    double totalRevenue = 0;
                    int pendingOrders = 0;

                    if (orderSnap.hasData) {
                      totalOrders = orderSnap.data!.docs.length;
                      for (var doc in orderSnap.data!.docs) {
                        final d = doc.data() as Map<String, dynamic>;
                        totalRevenue += (d['total'] ?? 0).toDouble();
                        if ((d['status']?.toString() ?? '') == 'En attente') pendingOrders++;
                      }
                    }

                    // Adaptive grid
                    final crossCount = isMobile ? 2 : (_Screen.isTablet(context) ? 3 : 4);

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isMobile ? 1.4 : 1.8,
                      children: [
                        _buildStatCard(
                          title: 'Produits',
                          value: totalProducts.toString(),
                          icon: Icons.inventory_2_rounded,
                          color: tropicalTeal,
                          subtitle: 'en stock',
                        ),
                        _buildStatCard(
                          title: 'Commandes',
                          value: totalOrders.toString(),
                          icon: Icons.shopping_cart_checkout_rounded,
                          color: const Color(0xFF2ECC71),
                          subtitle: 'au total',
                        ),
                        _buildStatCard(
                          title: 'En attente',
                          value: pendingOrders.toString(),
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFF3498DB),
                          subtitle: 'commandes',
                        ),
                        _buildStatCard(
                          title: 'Revenus',
                          value: '${totalRevenue.toStringAsFixed(0)}',
                          icon: Icons.attach_money_rounded,
                          color: const Color(0xFFF39C12),
                          subtitle: 'FCFA',
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 28),

            // Bottom section: responsive layout
            isMobile
                ? Column(
                    children: [
                      _buildRecentOrders(),
                      const SizedBox(height: 16),
                      _buildCategoryStats(),
                    ],
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildRecentOrders()),
                        const SizedBox(width: 16),
                        Expanded(flex: 1, child: _buildCategoryStats()),
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
    final isMobile = _Screen.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Row(
        children: [
          Container(
            width: isMobile ? 44 : 52,
            height: isMobile ? 44 : 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: isMobile ? 22 : 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 22,
                      fontWeight: FontWeight.w800,
                      color: darkText,
                    ),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: mediumText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: isMobile ? 10 : 11, color: lightText),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Commandes récentes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tropicalTeal),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 2),
                style: TextButton.styleFrom(foregroundColor: tropicalTeal, padding: EdgeInsets.zero),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Voir tout', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('orders')
                .where('boutiqueId', isEqualTo: widget.boutiqueId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: tropicalTeal));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('Aucune commande', style: TextStyle(color: lightText, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }

              final orders = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aDate = (a.data() as Map)['createdAt'] as Timestamp?;
                  final bDate = (b.data() as Map)['createdAt'] as Timestamp?;
                  return (bDate?.millisecondsSinceEpoch ?? 0)
                      .compareTo(aDate?.millisecondsSinceEpoch ?? 0);
                });

              final recent = orders.take(5).toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recent.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: softIvory),
                itemBuilder: (context, index) {
                  final data = recent[index].data() as Map<String, dynamic>;
                  final status = data['status']?.toString() ?? '';
                  final amount = (data['total'] ?? 0).toDouble();
                  final ts = data['createdAt'] as Timestamp?;
                  final dateStr = ts != null
                      ? DateFormat('dd/MM/yy HH:mm').format(ts.toDate())
                      : '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_getOrderStatusIcon(status), color: _getStatusColor(status), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getProductNameFromOrder(data),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: darkText),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(dateStr, style: const TextStyle(fontSize: 11, color: mediumText)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${amount.toStringAsFixed(0)} F',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tropicalTeal),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status.length > 12 ? '${status.substring(0, 12)}...' : status,
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStats() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Produits par catégorie',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tropicalTeal),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('products')
                .where('boutique_id', isEqualTo: widget.boutiqueId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: tropicalTeal));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.category_outlined, size: 36, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('Aucun produit', style: TextStyle(color: lightText, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              final products = snapshot.data!.docs;
              final Map<String, int> counts = {};
              for (var doc in products) {
                final cat = (doc.data() as Map)['categorie']?.toString() ?? 'Autre';
                counts[cat] = (counts[cat] ?? 0) + 1;
              }

              final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sorted.length,
                itemBuilder: (context, i) {
                  final entry = sorted[i];
                  final pct = products.isNotEmpty ? entry.value / products.length : 0.0;
                  final color = _getCategoryColor(entry.key);
                  final label = _getCategoryName(entry.key);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                              child: Center(
                                child: Text(
                                  label.substring(0, 1),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: darkText),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: softIvory,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PRODUCTS TAB
  // ============================================================
  Widget _buildProductsTab() {
    final isMobile = _Screen.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestion des Produits',
          style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w700, color: tropicalTeal),
        ),
        const SizedBox(height: 4),
        Text('Gérez les produits de votre boutique',
            style: TextStyle(fontSize: isMobile ? 12 : 14, color: mediumText)),
        const SizedBox(height: 20),

        // Search + Add
        isMobile
            ? Column(
                children: [
                  _buildSearchBar(_searchController, 'Rechercher un produit...', (v) {
                    setState(() => _searchQuery = v.toLowerCase());
                  }, () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  }, _searchQuery.isNotEmpty),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: _buildAddButton(),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _buildSearchBar(_searchController, 'Rechercher un produit...', (v) {
                      setState(() => _searchQuery = v.toLowerCase());
                    }, () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    }, _searchQuery.isNotEmpty),
                  ),
                  const SizedBox(width: 14),
                  _buildAddButton(),
                ],
              ),

        const SizedBox(height: 20),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: _buildProductsContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      onPressed: () => _showAddProductDialog(),
      style: ElevatedButton.styleFrom(
        backgroundColor: tropicalTeal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Ajouter un produit', style: TextStyle(fontSize: 13)),
    );
  }

  Widget _buildSearchBar(
    TextEditingController controller,
    String hint,
    Function(String) onChanged,
    VoidCallback onClear,
    bool showClear,
  ) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: tropicalTeal, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                hintStyle: TextStyle(color: lightText, fontSize: 13),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: onChanged,
            ),
          ),
          if (showClear)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.clear, size: 16, color: lightText),
            ),
        ],
      ),
    );
  }

  Widget _buildProductsContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('products')
          .where('boutique_id', isEqualTo: widget.boutiqueId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Chargement des produits...');
        }

        final products = snapshot.data!.docs;
        final filtered = products.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final nom = (d['nom'] ?? '').toString().toLowerCase();
          final cat = (d['categorie'] ?? '').toString().toLowerCase();
          return nom.contains(_searchQuery) || cat.contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            Icons.inventory_2_outlined,
            _searchQuery.isEmpty
                ? 'Aucun produit disponible'
                : 'Aucun résultat pour "$_searchQuery"',
            showAdd: _searchQuery.isEmpty,
          );
        }

        return _Screen.isMobile(context)
            ? _buildProductsListMobile(filtered)
            : _buildProductsTable(filtered);
      },
    );
  }

  // Mobile: card list
  Widget _buildProductsListMobile(List<QueryDocumentSnapshot> products) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final doc = products[index];
        final data = doc.data() as Map<String, dynamic>;
        final imageRef = data['image'] as String?;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: softIvory,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _buildProductImage(imageRef, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['nom']?.toString() ?? 'Sans nom',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: darkText),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(data['categorie']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getCategoryName(data['categorie']),
                              style: TextStyle(
                                color: _getCategoryColor(data['categorie']),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(data['prix'] ?? 0).toStringAsFixed(0)} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: tropicalTeal, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconBtn(Icons.edit_rounded, const Color(0xFF3498DB), () => _editProduct(doc.id, data)),
                  const SizedBox(width: 6),
                  _iconBtn(Icons.delete_rounded, const Color(0xFFE74C3C),
                      () => _deleteProduct(doc.id, data['nom']?.toString() ?? 'ce produit')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Desktop: data table
  Widget _buildProductsTable(List<QueryDocumentSnapshot> products) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columnSpacing: 20,
          horizontalMargin: 20,
          headingRowHeight: 50,
          dataRowHeight: 65,
          headingRowColor: MaterialStateProperty.all(softIvory),
          columns: _tableColumns(['Image', 'Nom', 'Prix', 'Catégorie', 'Actions']),
          rows: products.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DataRow(cells: [
              DataCell(_buildProductImage(data['image'] as String?, size: 45)),
              DataCell(SizedBox(
                width: 140,
                child: Text(data['nom']?.toString() ?? 'Sans nom',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: darkText),
                    overflow: TextOverflow.ellipsis, maxLines: 2),
              )),
              DataCell(Text('${(data['prix'] ?? 0).toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: tropicalTeal, fontSize: 13))),
              DataCell(_categoryBadge(data['categorie'])),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconBtn(Icons.edit_rounded, const Color(0xFF3498DB), () => _editProduct(doc.id, data)),
                  const SizedBox(width: 6),
                  _iconBtn(Icons.delete_rounded, const Color(0xFFE74C3C),
                      () => _deleteProduct(doc.id, data['nom']?.toString() ?? 'ce produit')),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ============================================================
  // ORDERS TAB
  // ============================================================
  Widget _buildOrdersTab() {
    final isMobile = _Screen.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gestion des Commandes',
            style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w700, color: tropicalTeal)),
        const SizedBox(height: 4),
        Text('Suivez et gérez les commandes',
            style: TextStyle(fontSize: isMobile ? 12 : 14, color: mediumText)),
        const SizedBox(height: 20),

        _buildSearchBar(_orderSearchController, 'Rechercher une commande...', (v) {
          setState(() => _orderSearchQuery = v.toLowerCase());
        }, () {
          _orderSearchController.clear();
          setState(() => _orderSearchQuery = '');
        }, _orderSearchQuery.isNotEmpty),

        const SizedBox(height: 20),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: _buildOrdersContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .where('boutiqueId', isEqualTo: widget.boutiqueId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorState('${snapshot.error}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Chargement des commandes...');
        }

        final orders = snapshot.data!.docs;
        final filtered = orders.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final status = (d['status'] ?? '').toString().toLowerCase();
          final userId = (d['userId'] ?? '').toString().toLowerCase();
          final clientName = _getClientName(userId).toLowerCase();
          return status.contains(_orderSearchQuery) ||
              userId.contains(_orderSearchQuery) ||
              clientName.contains(_orderSearchQuery);
        }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            Icons.shopping_cart_outlined,
            _orderSearchQuery.isEmpty
                ? 'Aucune commande pour cette boutique'
                : 'Aucun résultat pour "$_orderSearchQuery"',
          );
        }

        return _Screen.isMobile(context)
            ? _buildOrdersListMobile(filtered)
            : _buildOrdersTable(filtered);
      },
    );
  }

  Widget _buildOrdersListMobile(List<QueryDocumentSnapshot> orders) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final doc = orders[index];
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString() ?? '';
        final amount = (data['total'] ?? 0).toDouble();
        final ts = data['createdAt'] as Timestamp?;
        final dateStr = ts != null ? DateFormat('dd/MM/yy HH:mm').format(ts.toDate()) : '';
        final userId = data['userId']?.toString() ?? '';
        final clientName = _getClientName(userId);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: softIvory,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _getProductNameFromOrder(data),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: darkText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${amount.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: tropicalTeal, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 12, color: mediumText),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(clientName,
                        style: const TextStyle(fontSize: 11, color: mediumText), overflow: TextOverflow.ellipsis),
                  ),
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: lightText)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statusBadge(status),
                  Row(
                    children: [
                      _iconBtn(Icons.visibility_rounded, const Color(0xFF3498DB),
                          () => _viewOrderDetails(doc.id, data, clientName)),
                      const SizedBox(width: 6),
                      _buildStatusPopup(doc.id),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdersTable(List<QueryDocumentSnapshot> orders) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columnSpacing: 18,
          horizontalMargin: 20,
          headingRowHeight: 50,
          dataRowHeight: 65,
          headingRowColor: MaterialStateProperty.all(softIvory),
          columns: _tableColumns(['Produit', 'Date', 'Montant', 'Statut', 'Client', 'Actions']),
          rows: orders.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString() ?? '';
            final amount = (data['total'] ?? 0).toDouble();
            final userId = data['userId']?.toString() ?? '';
            final clientName = _getClientName(userId);

            String formattedDate = '';
            try {
              final dateData = data['createdAt'];
              if (dateData is Timestamp) {
                formattedDate = DateFormat('dd/MM/yy HH:mm').format(dateData.toDate());
              }
            } catch (_) {}

            return DataRow(cells: [
              DataCell(SizedBox(
                width: 110,
                child: Text(_getProductNameFromOrder(data),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: darkText),
                    overflow: TextOverflow.ellipsis),
              )),
              DataCell(SizedBox(
                width: 100,
                child: Text(formattedDate,
                    style: const TextStyle(fontSize: 11, color: mediumText)),
              )),
              DataCell(Text('${amount.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: tropicalTeal, fontSize: 12))),
              DataCell(_statusBadge(status)),
              DataCell(SizedBox(
                width: 110,
                child: Text(clientName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: darkText),
                    overflow: TextOverflow.ellipsis),
              )),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconBtn(Icons.visibility_rounded, const Color(0xFF3498DB),
                      () => _viewOrderDetails(doc.id, data, clientName)),
                  const SizedBox(width: 6),
                  _buildStatusPopup(doc.id),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ============================================================
  // SETTINGS TAB
  // ============================================================
  Widget _buildSettingsTab() {
    final isMobile = _Screen.isMobile(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paramètres de la boutique',
                style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w700, color: tropicalTeal)),
            const SizedBox(height: 4),
            Text('Gérez les paramètres de ${widget.boutiqueName}',
                style: TextStyle(fontSize: isMobile ? 12 : 14, color: mediumText)),
            const SizedBox(height: 24),

            // Infos boutique
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informations de la boutique',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tropicalTeal)),
                  const SizedBox(height: 20),
                  StreamBuilder<DocumentSnapshot>(
                    stream: _firestore.collection('boutiques').doc(widget.boutiqueId).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: tropicalTeal));
                      }
                      final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                      return Column(
                        children: [
                          _buildSettingItem('Nom de la boutique', data['nom'] ?? widget.boutiqueName, icon: Icons.store_rounded),
                          const SizedBox(height: 16),
                          _buildSettingItem('Adresse', data['adresse'] ?? 'Non définie', icon: Icons.location_on_rounded),
                          const SizedBox(height: 16),
                          _buildSettingItem('Catégorie', data['categories'] ?? 'Général', icon: Icons.category_rounded),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _editBoutiqueSettings(data),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tropicalTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('Modifier les informations'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Actions administratives',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tropicalTeal)),
                  const SizedBox(height: 20),
                  _buildActionTile(Icons.delete_outline_rounded, 'Supprimer la boutique',
                      'Cette action est irréversible', const Color(0xFFE74C3C), () => _deleteBoutique()),
                  const Divider(color: softIvory),
                  _buildActionTile(Icons.notifications_active_rounded, 'Notifications',
                      'Gérer les notifications', const Color(0xFF3498DB), () {}),
                  const Divider(color: softIvory),
                  _buildActionTile(Icons.security_rounded, 'Sécurité',
                      'Paramètres de sécurité', const Color(0xFF2ECC71), () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildSettingItem(String label, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) Icon(icon, color: tropicalTeal, size: 16),
            if (icon != null) const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: mediumText, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: softIvory,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tropicalTeal.withOpacity(0.2)),
          ),
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkText)),
        ),
      ],
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: darkText, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: mediumText, fontSize: 12)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: mediumText),
      onTap: onTap,
    );
  }

  // ============================================================
  // SHARED UI HELPERS
  // ============================================================
  List<DataColumn> _tableColumns(List<String> titles) {
    return titles.map((t) => DataColumn(
      label: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: tropicalTeal, fontSize: 13)),
    )).toList();
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
      ),
      child: Text(
        status.isEmpty ? 'En attente' : status,
        style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _categoryBadge(String? category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _getCategoryColor(category).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getCategoryColor(category).withOpacity(0.3)),
      ),
      child: Text(
        _getCategoryName(category),
        style: TextStyle(color: _getCategoryColor(category), fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatusPopup(String orderId) {
    return PopupMenuButton<String>(
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: tropicalTeal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.more_vert_rounded, size: 16, color: tropicalTeal),
      ),
      onSelected: (value) => _updateOrderStatus(orderId, value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'En préparation', child: Text('En préparation')),
        PopupMenuItem(value: 'Prêt', child: Text('Prêt')),
        PopupMenuItem(value: 'Livrée', child: Text('Livrée')),
        PopupMenuItem(value: 'Annulée', child: Text('Annulée')),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFE74C3C), size: 48),
            const SizedBox(height: 12),
            Text('Erreur: $error', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: mediumText)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: tropicalTeal),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: mediumText, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message, {bool showAdd = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: mediumText)),
          if (showAdd) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAddProductDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: tropicalTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Ajouter votre premier produit'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductImage(String? imageRef, {double size = 45}) {
    final container = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: softIvory,
      border: Border.all(color: tropicalTeal.withOpacity(0.2)),
    );

    if (imageRef == null || imageRef.isEmpty) {
      return Container(
        width: size, height: size,
        decoration: container,
        child: Icon(Icons.shopping_bag_rounded, color: tropicalTeal, size: size * 0.5),
      );
    }

    if (imageRef.startsWith('firestore:')) {
      return SizedBox(width: size, height: size, child: _buildFirestoreImage(imageRef));
    }

    return Container(
      width: size, height: size,
      decoration: container,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageRef,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) =>
              progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: tropicalTeal)),
          errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, color: tropicalTeal, size: size * 0.5),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE METHODS
  // ============================================================
  Widget _buildFirestoreImage(String firestoreId) {
    final imageId = firestoreId.replaceFirst('firestore:', '');
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('product_images').doc(imageId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: softIvory),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: tropicalTeal)),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: softIvory),
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
          );
        }
        final base64Image = (snapshot.data!.data() as Map<String, dynamic>)['image_base64'] as String?;
        if (base64Image == null || base64Image.isEmpty) {
          return Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: softIvory),
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
          );
        }
        try {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(base64Decode(base64Image), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.red, size: 20)),
          );
        } catch (_) {
          return const Icon(Icons.broken_image, color: Colors.grey, size: 24);
        }
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _selectedImageBytes = bytes);
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _selectedImageBytes = bytes);
    }
  }

  Future<String?> _uploadImageToFirestore() async {
    if (_selectedImageBytes == null) return null;
    setState(() { _isUploading = true; _uploadProgress = 0.0; });
    try {
      final base64Image = base64Encode(_selectedImageBytes!);
      if (base64Image.length > 900000) throw Exception('Image trop grande (max ~900KB)');

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
      return 'firestore:${docRef.id}';
    } catch (e) {
      debugPrint('Erreur upload: $e');
      return null;
    } finally {
      setState(() { _isUploading = false; _uploadProgress = 0.0; });
    }
  }

  Widget _buildImagePreview() {
    if (_selectedImageBytes != null) {
      return _imageBox(child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover));
    } else if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) {
      if (_uploadedImageUrl!.startsWith('firestore:')) {
        return _imageBox(child: _buildFirestoreImage(_uploadedImageUrl!));
      }
      return _imageBox(
        child: Image.network(_uploadedImageUrl!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.red)),
      );
    }
    return _imageBox(
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.image, size: 36, color: Colors.grey),
        SizedBox(height: 4),
        Text('Aucune image', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    );
  }

  Widget _imageBox({required Widget child}) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor, width: 2),
        color: Colors.grey[100],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
    );
  }

  // ============================================================
  // PRODUCT DIALOGS
  // ============================================================
  Future<void> _showAddProductDialog() async {
    _selectedImageBytes = null;
    _uploadedImageUrl = null;
    _isUploading = false;
    _uploadProgress = 0.0;

    final formKey = GlobalKey<FormState>();
    final nomCtrl = TextEditingController();
    final prixCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCat = 'clothing';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajouter un produit'),
          content: SizedBox(
            width: _Screen.isMobile(context) ? double.maxFinite : 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildImagePreview(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async { await _pickImage(); setDialogState(() {}); },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3498DB), foregroundColor: Colors.white),
                          icon: const Icon(Icons.photo_library, size: 14),
                          label: const Text('Galerie', style: TextStyle(fontSize: 12)),
                        ),
                        if (!kIsWeb)
                          ElevatedButton.icon(
                            onPressed: () async { await _takePhoto(); setDialogState(() {}); },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71), foregroundColor: Colors.white),
                            icon: const Icon(Icons.camera_alt, size: 14),
                            label: const Text('Caméra', style: TextStyle(fontSize: 12)),
                          ),
                        if (_selectedImageBytes != null && !_isUploading)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final url = await _uploadImageToFirestore();
                              setDialogState(() { if (url != null) _uploadedImageUrl = url; });
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
                            icon: const Icon(Icons.upload, size: 14),
                            label: const Text('Enregistrer', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    if (_isUploading) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _uploadProgress, color: accentColor),
                    ],
                    if (_uploadedImageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.check_circle, color: Colors.green[700], size: 14),
                          const SizedBox(width: 4),
                          Text('Image enregistrée', style: TextStyle(color: Colors.green[700], fontSize: 12)),
                        ]),
                      ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nomCtrl,
                      decoration: const InputDecoration(labelText: 'Nom du produit *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.shopping_bag)),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatoire' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: prixCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prix (FCFA) *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.money)),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Obligatoire';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Prix invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCat,
                      decoration: const InputDecoration(labelText: 'Catégorie *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                      items: _categories.map<DropdownMenuItem<String>>((c) =>
                        DropdownMenuItem(value: c['value'] as String, child: Text(c['label'] as String))).toList(),
                      onChanged: (v) { if (v != null) setDialogState(() => selectedCat = v); },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (_uploadedImageUrl == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez enregistrer une image'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                if (formKey.currentState!.validate()) {
                  try {
                    await _firestore.collection('products').add({
                      'nom': nomCtrl.text.trim(),
                      'prix': double.parse(prixCtrl.text.trim()),
                      'categorie': selectedCat,
                      'image': _uploadedImageUrl!,
                      'image_type': 'firestore_base64',
                      'description': descCtrl.text.trim(),
                      'boutique_id': widget.boutiqueId,
                      'created_at': FieldValue.serverTimestamp(),
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Produit ajouté !'), backgroundColor: Colors.green),
                      );
                      Navigator.of(ctx).pop();
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: accentColor),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProduct(String productId, Map<String, dynamic> data) async {
    _selectedImageBytes = null;
    _uploadedImageUrl = data['image'] as String?;
    _isUploading = false;
    _uploadProgress = 0.0;

    final formKey = GlobalKey<FormState>();
    final nomCtrl = TextEditingController(text: data['nom']?.toString() ?? '');
    final prixCtrl = TextEditingController(text: (data['prix'] ?? 0).toStringAsFixed(0));
    final descCtrl = TextEditingController(text: data['description']?.toString() ?? '');
    String selectedCat = data['categorie']?.toString() ?? 'clothing';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Modifier le produit'),
          content: SizedBox(
            width: _Screen.isMobile(context) ? double.maxFinite : 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildImagePreview(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async { await _pickImage(); setDialogState(() {}); },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3498DB), foregroundColor: Colors.white),
                          icon: const Icon(Icons.photo_library, size: 14),
                          label: const Text('Changer image', style: TextStyle(fontSize: 12)),
                        ),
                        if (_selectedImageBytes != null && !_isUploading)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final url = await _uploadImageToFirestore();
                              setDialogState(() { if (url != null) _uploadedImageUrl = url; });
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
                            icon: const Icon(Icons.upload, size: 14),
                            label: const Text('Enregistrer', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    if (_isUploading) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _uploadProgress, color: accentColor),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nomCtrl,
                      decoration: const InputDecoration(labelText: 'Nom du produit *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.shopping_bag)),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatoire' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: prixCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prix (FCFA) *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.money)),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Obligatoire';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Prix invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCat,
                      decoration: const InputDecoration(labelText: 'Catégorie *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                      items: _categories.map<DropdownMenuItem<String>>((c) =>
                        DropdownMenuItem(value: c['value'] as String, child: Text(c['label'] as String))).toList(),
                      onChanged: (v) { if (v != null) setDialogState(() => selectedCat = v); },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _firestore.collection('products').doc(productId).update({
                      'nom': nomCtrl.text.trim(),
                      'prix': double.parse(prixCtrl.text.trim()),
                      'categorie': selectedCat,
                      'image': _uploadedImageUrl ?? data['image'],
                      'image_type': 'firestore_base64',
                      'description': descCtrl.text.trim(),
                      'updated_at': FieldValue.serverTimestamp(),
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Produit modifié !'), backgroundColor: Colors.green),
                      );
                      Navigator.of(ctx).pop();
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: accentColor),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(String productId, String productName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le produit'),
        content: Text('Supprimer "$productName" ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE74C3C)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _firestore.collection('products').doc(productId).delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$productName" supprimé'), backgroundColor: const Color(0xFF2ECC71)),
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: const Color(0xFFE74C3C)),
        );
      }
    }
  }

  // ============================================================
  // ORDER METHODS
  // ============================================================
  Future<void> _viewOrderDetails(String orderId, Map<String, dynamic> data, String clientName) async {
    String formattedDate = 'Non spécifiée';
    try {
      final dateData = data['createdAt'];
      if (dateData is Timestamp) {
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateData.toDate());
      }
    } catch (_) {}

    final deliveryMethod = data['deliveryType'] == 'delivery' ? 'Livraison à domicile' : 'Retrait en boutique';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Détails de la commande'),
        content: SizedBox(
          width: _Screen.isMobile(context) ? double.maxFinite : 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailCard(Icons.person, 'Client', clientName),
                const SizedBox(height: 12),
                _buildDetailCard(Icons.receipt, 'Commande', _getProductNameFromOrder(data)),
                const SizedBox(height: 12),
                _buildDetailCard(Icons.calendar_today, 'Date', formattedDate),
                const SizedBox(height: 12),
                _buildDetailCard(Icons.money, 'Montant Total',
                    '${(data['total'] ?? 0).toStringAsFixed(0)} FCFA', isAmount: true),
                const SizedBox(height: 12),
                _buildDetailCard(Icons.local_shipping, 'Livraison', deliveryMethod),
                const SizedBox(height: 12),
                _buildDetailCard(Icons.info, 'Statut', data['status']?.toString() ?? 'En attente',
                    status: data['status']?.toString()),
                const SizedBox(height: 16),
                const Text('Produits commandés:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkText)),
                const SizedBox(height: 8),
                if (data['items'] != null && (data['items'] as List).isNotEmpty)
                  ...(data['items'] as List).map<Widget>((item) {
                    final itemMap = item as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: softIvory),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: tropicalTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.shopping_bag, color: tropicalTeal, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_getItemProductName(itemMap),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: darkText),
                                    overflow: TextOverflow.ellipsis),
                                Text('Quantité: ${itemMap['quantity'] ?? 1}',
                                    style: const TextStyle(fontSize: 11, color: mediumText)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList()
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: const Center(child: Text('Aucun produit', style: TextStyle(color: Colors.grey))),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statut: $newStatus'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildDetailCard(IconData icon, String label, String value, {bool isAmount = false, String? status}) {
    Color valueColor = darkText;
    if (status != null) valueColor = _getStatusColor(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: softIvory),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tropicalTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(fontSize: 14, color: valueColor,
                        fontWeight: isAmount ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SETTINGS METHODS
  // ============================================================
  Future<void> _editBoutiqueSettings(Map<String, dynamic> data) async {
    final nomCtrl = TextEditingController(text: data['nom'] ?? widget.boutiqueName);
    final adresseCtrl = TextEditingController(text: data['adresse'] ?? '');
    final catCtrl = TextEditingController(text: data['categories'] ?? 'Général');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier la boutique'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextFormField(controller: adresseCtrl,
                  decoration: const InputDecoration(labelText: 'Adresse', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextFormField(controller: catCtrl,
                  decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('boutiques').doc(widget.boutiqueId).update({
                  'nom': nomCtrl.text.trim(),
                  'adresse': adresseCtrl.text.trim(),
                  'categories': catCtrl.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Boutique mise à jour !'), backgroundColor: Colors.green),
                  );
                  Navigator.of(ctx).pop();
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBoutique() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la boutique'),
        content: const Text('Êtes-vous sûr ? Tous les produits et commandes seront supprimés. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE74C3C)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('boutiques').doc(widget.boutiqueId).delete();

        final products = await _firestore.collection('products')
            .where('boutique_id', isEqualTo: widget.boutiqueId).get();
        for (var doc in products.docs) await doc.reference.delete();

        final orders = await _firestore.collection('orders')
            .where('boutiqueId', isEqualTo: widget.boutiqueId).get();
        for (var doc in orders.docs) await doc.reference.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Boutique supprimée'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================
  Color _getStatusColor(String? status) {
    final s = status ?? '';
    if (s.contains('attente')) return const Color(0xFFF39C12);
    if (s.contains('préparation')) return const Color(0xFF9B59B6);
    if (s == 'Prêt') return const Color(0xFF2ECC71);
    if (s == 'Livrée') return const Color(0xFF27AE60);
    if (s == 'Annulée') return const Color(0xFFE74C3C);
    return const Color(0xFF7F8C8D);
  }

  IconData _getOrderStatusIcon(String? status) {
    final s = status ?? '';
    if (s.contains('attente')) return Icons.pending;
    if (s.contains('préparation')) return Icons.local_shipping;
    if (s == 'Prêt') return Icons.check_circle_outline;
    if (s == 'Livrée') return Icons.home;
    if (s == 'Annulée') return Icons.cancel;
    return Icons.receipt;
  }

  Color _getCategoryColor(String? category) {
    final cat = (category ?? '').toLowerCase();
    for (var c in _categories) {
      if (c['value'] == cat) return c['color'] as Color;
    }
    return const Color(0xFF7F8C8D);
  }

  String _getCategoryName(String? category) {
    final cat = (category ?? '').toLowerCase();
    for (var c in _categories) {
      if (c['value'] == cat) return c['label'] as String;
    }
    return cat.isNotEmpty ? cat : 'Non catégorisé';
  }

  String _getClientName(String userId) {
    return _clientNames[userId] ??
        'Client ${userId.length > 8 ? '${userId.substring(0, 8)}...' : userId}';
  }

  String _getProductNameFromOrder(Map<String, dynamic> orderData) {
    try {
      if (orderData['items'] != null && (orderData['items'] as List).isNotEmpty) {
        final firstItem = ((orderData['items'] as List).first as Map).cast<String, dynamic>();
        final name = _getItemProductName(firstItem);
        return name.length > 22 ? '${name.substring(0, 22)}...' : name;
      }
    } catch (_) {}
    return 'Commande';
  }

  String _getItemProductName(Map<String, dynamic> itemData) {
    final name = itemData['productName']?.toString();
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }

    final fallback = itemData['name']?.toString();
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }

    return 'Produit';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _orderSearchController.dispose();
    super.dispose();
  }
}
