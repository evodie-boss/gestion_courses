import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_courses/constants/app_colors.dart';
import 'package:gestion_courses/screens/profile_screen.dart';
import 'package:gestion_courses/screens/login_screen.dart';
import 'package:gestion_courses/screens/register_screen.dart';
import 'package:gestion_courses/screens/map_screen.dart';
// Pages importées pour les onglets
import 'package:gestion_courses/pages/course_list_screen.dart';
import 'package:gestion_courses/gestion_portefeuille/screens/wallet_screen.dart';
import 'package:gestion_courses/gestion_boutiques/pages/boutiques.dart';
import 'package:gestion_courses/gestion_boutiques/pages/boutique_detail.dart';
import 'package:gestion_courses/services/auth_service.dart';
import 'package:gestion_courses/models/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _initializeQuickActions();
    _loadUserData();
    _loadRecentCourses();
    _loadNearbyShops();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  late List<Map<String, dynamic>> _quickActions = [];
  List<Map<String, dynamic>> _recentCourses = [];
  List<Map<String, dynamic>> _nearbyShops = [];
  double _userWalletBalance = 0.0;

  void _initializeQuickActions() {
    _quickActions = [
      {
        'icon': Icons.add_shopping_cart_rounded,
        'title': 'Nouvelle Liste de course',
        'color': AppColors.tropicalTeal,
        'subtitle': 'Créer une liste de course',
      },
      {
        'icon': Icons.attach_money_rounded,
        'title': 'Portefeuille',
        'color': Colors.amber.shade700,
        'subtitle': 'Solde: ${_userWalletBalance.toStringAsFixed(0)} FCFA',
      },
      {
        'icon': Icons.store_mall_directory_rounded,
        'title': 'Boutiques',
        'color': Colors.green.shade700,
        'subtitle': '${_nearbyShops.length} boutiques',
      },
      {
        'icon': Icons.map_rounded,
        'title': 'Carte',
        'color': const Color.fromARGB(255, 159, 169, 179),
        'subtitle': 'Voir la carte',
      },
    ];
  }

  Future<void> _loadUserData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('portefeuille')
            .doc(userId)
            .get();
        if (doc.exists) {
          setState(() {
            _userWalletBalance = (doc.data()?['balance'] ?? 0).toDouble();
            _initializeQuickActions();
          });
        }
      }
    } catch (e) {
      print('Erreur chargement solde: $e');
    }
  }

  Future<void> _loadRecentCourses() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('courses')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get();

        setState(() {
          _recentCourses = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Sans titre',
              'items': (data['items'] as List?)?.length ?? 0,
              'date': _formatDate(data['createdAt'] as Timestamp?),
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Erreur chargement courses récentes: $e');
    }
  }

  Future<void> _loadNearbyShops() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('boutiques')
          .limit(5)
          .get();

      setState(() {
        _nearbyShops = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['nom'] ?? 'Boutique',
            'categories': data['categories'] ?? 'Catégorie inconnue',
            'location': data['location'] ?? 'Localisation inconnue',
          };
        }).toList();
        _initializeQuickActions();
      });
    } catch (e) {
      print('Erreur chargement boutiques: $e');
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Récemment';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final courseDate = DateTime(date.year, date.month, date.day);

    if (courseDate.isAtSameMomentAs(today)) {
      return 'Aujourd\'hui';
    } else if (courseDate.isAtSameMomentAs(
      today.subtract(const Duration(days: 1)),
    )) {
      return 'Hier';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  void _navigateWithAnimation(int index) {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
      setState(() {
        _currentIndex = index;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Récupérer AuthService et l'utilisateur
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ShopTrack',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: AppColors.tropicalTeal,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 26),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Notifications'),
                    content: const Text('Aucune notification pour le moment'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
          // AVATAR AVEC MENU DYNAMIQUE
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user?.prenom.isNotEmpty == true && user?.nom.isNotEmpty == true
                    ? '${user!.prenom[0]}${user.nom[0]}'.toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: AppColors.tropicalTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onSelected: (value) {
              if (value == 'profile' && user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              } else if (value == 'login' && user == null) {
                _navigateToLoginScreen(context);
              } else if (value == 'logout' && user != null) {
                _showLogoutDialog(context, authService);
              }
            },
            itemBuilder: (context) {
              if (user != null) {
                return [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: const [
                        Icon(
                          Icons.person,
                          color: AppColors.tropicalTeal,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text('Mon Profil'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: const [
                        Icon(Icons.logout, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Déconnexion',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ];
              } else {
                return [
                  PopupMenuItem(
                    value: 'login',
                    child: Row(
                      children: const [
                        Icon(
                          Icons.login,
                          color: AppColors.tropicalTeal,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text('Connexion'),
                      ],
                    ),
                  ),
                ];
              }
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, authService),
      body: _buildBody(context, user),
      bottomNavigationBar: _buildBottomNavigationBar(),
      backgroundColor: AppColors.softIvory,
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Déconnexion'),
          content: const Text('Voulez-vous vraiment vous déconnecter ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await authService.logout();
              },
              child: const Text(
                'Déconnexion',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToLoginScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _navigateToRegisterScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  Widget _buildBody(BuildContext context, UserModel? user) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _getCurrentPage(context, user),
    );
  }

  Widget _getCurrentPage(BuildContext context, UserModel? user) {
    switch (_currentIndex) {
      case 0:
        return KeyedSubtree(
          key: const ValueKey('home'),
          child: _buildHomeContent(user),
        );
      case 1:
        return KeyedSubtree(
          key: const ValueKey('courses'),
          child: const CourseListScreen(),
        );
      case 2:
        return KeyedSubtree(
          key: const ValueKey('wallet'),
          child: user != null
              ? WalletScreen(userId: user.id)
              : _buildWalletContent(user),
        );
      case 3:
        return KeyedSubtree(
          key: const ValueKey('boutiques'),
          child: const ElegantBoutiquePage(),
        );
      case 4:
        return KeyedSubtree(
          key: const ValueKey('map'),
          child: const MapScreen(),
        );
      case 5:
        return KeyedSubtree(
          key: const ValueKey('orders'),
          child: _buildOrdersContent(),
        );
      default:
        return KeyedSubtree(
          key: const ValueKey('home'),
          child: _buildHomeContent(user),
        );
    }
  }

  Widget _buildHomeContent(UserModel? user) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bannière de bienvenue
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 50 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color.fromARGB(255, 201, 208, 214),
                    const Color.fromARGB(255, 82, 85, 88),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user != null ? 'Bonjour, ${user.prenom}!' : 'Bonjour !',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prêt pour vos courses aujourd\'hui?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Actions Rapides
                const Text(
                  'Actions Rapides',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.tropicalTeal,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _quickActions.length,
                  itemBuilder: (context, index) {
                    final action = _quickActions[index];
                    return _buildAnimatedActionCard(
                      icon: action['icon'],
                      title: action['title'],
                      color: action['color'],
                      subtitle: index == 1 && user != null
                          ? 'Solde: ${user.soldePortefeuille} FCFA'
                          : action['subtitle'],
                      onTap: () {
                        int targetIndex = index;
                        if (index == 0)
                          targetIndex = 1; // Courses
                        else if (index == 1)
                          targetIndex = 2; // Portefeuille
                        else if (index == 2)
                          targetIndex = 3; // Boutiques
                        else if (index == 3)
                          targetIndex = 4; // Carte
                        _navigateWithAnimation(targetIndex);
                      },
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Section Listes Récentes
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Courses Récentes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.tropicalTeal,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _navigateWithAnimation(1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.tropicalTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: const [
                                Text(
                                  'Voir tout',
                                  style: TextStyle(
                                    color: AppColors.tropicalTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: AppColors.tropicalTeal,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_recentCourses.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Aucune course récente',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      ..._recentCourses.asMap().entries.map(
                        (entry) =>
                            _buildAnimatedListCard(entry.key, entry.value),
                      ),
                  ],
                ),

                const SizedBox(height: 32),

                // Section Boutiques Proches (Dynamique)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Boutiques Proches',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.tropicalTeal,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _navigateWithAnimation(3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tropicalTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            Text(
                              'Voir tout',
                              style: TextStyle(
                                color: AppColors.tropicalTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: AppColors.tropicalTeal,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_nearbyShops.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Aucune boutique trouvée',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _nearbyShops
                          .map((shop) => _buildShopCard(shop))
                          .toList(),
                    ),
                  ),

                const SizedBox(height: 32),

                // Bouton Créer une Boutique
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreateShopDialog(context),
                    icon: const Icon(Icons.store),
                    label: const Text('Créer une Boutique'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tropicalTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateShopDialog(BuildContext context) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final categoriesController = TextEditingController();
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer une Boutique'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la boutique *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoriesController,
                decoration: const InputDecoration(
                  labelText: 'Catégories (séparées par des virgules)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                  hintText: 'Alimentation, Électronique, Vêtements',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Localisation/Adresse',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Text(
                'Coordonnées GPS (optionnel)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                        hintText: '48.8566',
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: longitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                        hintText: '2.3522',
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '* Champ obligatoire\nCoordonnées GPS: optionnel, par défaut Paris',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez entrer le nom de la boutique'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                double? latitude;
                double? longitude;

                if (latitudeController.text.isNotEmpty &&
                    longitudeController.text.isNotEmpty) {
                  latitude = double.tryParse(latitudeController.text);
                  longitude = double.tryParse(longitudeController.text);

                  if (latitude == null ||
                      longitude == null ||
                      latitude < -90 ||
                      latitude > 90 ||
                      longitude < -180 ||
                      longitude > 180) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Coordonnées GPS invalides\nLatitude: -90 à 90\nLongitude: -180 à 180',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }

                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId != null) {
                  final shopData = {
                    'nom': nameController.text,
                    'categories': categoriesController.text.isNotEmpty
                        ? categoriesController.text
                        : 'Général',
                    'location': locationController.text.isNotEmpty
                        ? locationController.text
                        : 'Localisation non spécifiée',
                    'ownerId': userId,
                    'rating': 5.0,
                    'reviewCount': 0,
                    'distance': 0.5,
                    'createdAt': FieldValue.serverTimestamp(),
                  };

                  // Ajouter les coordonnées si fournies
                  if (latitude != null && longitude != null) {
                    shopData['latitude'] = latitude;
                    shopData['longitude'] = longitude;
                  } else {
                    // Coordonnées par défaut (Paris)
                    shopData['latitude'] = 48.8566;
                    shopData['longitude'] = 2.3522;
                  }

                  await FirebaseFirestore.instance
                      .collection('boutiques')
                      .add(shopData);

                  if (!context.mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Boutique "${nameController.text}" créée avec succès ! 🎉',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  _loadNearbyShops();
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedListCard(int index, Map<String, dynamic> list) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateWithAnimation(1),
          borderRadius: BorderRadius.circular(15),
          splashColor: AppColors.tropicalTeal.withOpacity(0.1),
          highlightColor: AppColors.tropicalTeal.withOpacity(0.05),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tropicalTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.shopping_basket_rounded,
                color: AppColors.tropicalTeal,
              ),
            ),
            title: Text(
              list['name'],
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text(
              '${list['items']} articles • ${list['date']}',
              style: TextStyle(color: AppColors.textColor.withOpacity(0.6)),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.tropicalTeal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
    return MouseRegion(
      onEnter: (_) => _scaleController.forward(),
      onExit: (_) => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BoutiqueDetailScreen(
                  boutiqueId: shop['id'],
                  boutiqueName: shop['name'],
                ),
              ),
            );
          },
          child: Container(
            width: 200,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.softIvory,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 40,
                      color: AppColors.tropicalTeal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    shop['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    shop['categories'].toString(),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.tropicalTeal,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shop['location'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletContent(UserModel? user) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            size: 80,
            color: Colors.amber.shade700.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mon Portefeuille',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.amber.shade200, width: 2),
            ),
            child: Column(
              children: [
                const Text(
                  'Votre solde actuel',
                  style: TextStyle(fontSize: 16, color: Colors.amber),
                ),
                const SizedBox(height: 5),
                Text(
                  user != null ? '${user.soldePortefeuille} FCFA' : '0 FCFA',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Gérez votre solde et paiements',
            style: TextStyle(fontSize: 16, color: AppColors.textColor),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              // TODO: Implémenter l'ajout de fonds
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Ajouter des fonds',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersContent() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 80,
              color: Colors.purple.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connectez-vous',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'pour voir vos commandes',
              style: TextStyle(fontSize: 16, color: AppColors.textColor),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 50,
                ),
                const SizedBox(height: 16),
                Text('Erreur: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.tropicalTeal,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 80,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Aucune commande',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vous n\'avez pas encore passé de commande',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final orders = snapshot.data!.docs;

        return RefreshIndicator(
          onRefresh: () async {
            // Rafraîchir les données si nécessaire
            setState(() {});
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Mes Commandes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Suivi de vos commandes passées',
                style: TextStyle(fontSize: 14, color: AppColors.textColor),
              ),
              const SizedBox(height: 20),
              ...orders.map((doc) => _buildOrderCard(doc)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final total = (data['total'] ?? 0).toDouble();
    final status = data['status']?.toString() ?? 'pending';
    final deliveryType = data['deliveryType']?.toString() ?? 'pickup';
    final createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final items = data['items'] as List<dynamic>? ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commande #${doc.id.substring(0, 8)}...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length} article(s)',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  deliveryType == 'pickup'
                      ? 'Prise sur place'
                      : 'Livraison à domicile',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Montant total:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${total.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmée';
      case 'processing':
        return 'En traitement';
      case 'shipped':
        return 'Expédiée';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'En cours';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Drawer _buildDrawer(BuildContext context, AuthService authService) {
    final user = authService.currentUser;
    final isLoggedIn = user != null;

    return Drawer(
      backgroundColor: Colors.white,
      width: 280,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header du drawer
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.tropicalTeal,
                  AppColors.tropicalTeal.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      isLoggedIn &&
                              user.prenom.isNotEmpty &&
                              user.nom.isNotEmpty
                          ? '${user.prenom[0]}${user.nom[0]}'.toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.tropicalTeal,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isLoggedIn ? '${user.prenom} ${user.nom}' : 'Invité',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLoggedIn ? user.email : 'Non connecté',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                  if (isLoggedIn) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        'Solde: ${user.soldePortefeuille} FCFA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Items de navigation principaux (toujours visibles)
          _drawerItem(
            icon: Icons.home_rounded,
            title: 'Accueil',
            selected: _currentIndex == 0,
            onTap: () {
              _navigateWithAnimation(0);
              Navigator.pop(context);
            },
          ),
          _drawerItem(
            icon: Icons.shopping_cart_rounded,
            title: 'Courses',
            selected: _currentIndex == 1,
            onTap: () {
              _navigateWithAnimation(1);
              Navigator.pop(context);
            },
          ),
          _drawerItem(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Portefeuille',
            selected: _currentIndex == 2,
            onTap: () {
              _navigateWithAnimation(2);
              Navigator.pop(context);
            },
          ),
          _drawerItem(
            icon: Icons.store_mall_directory_rounded,
            title: 'Boutiques',
            selected: _currentIndex == 3,
            onTap: () {
              _navigateWithAnimation(3);
              Navigator.pop(context);
            },
          ),
          _drawerItem(
            icon: Icons.map_rounded,
            title: 'Carte',
            selected: _currentIndex == 4,
            onTap: () {
              _navigateWithAnimation(4);
              Navigator.pop(context);
            },
          ),
          _drawerItem(
            icon: Icons.list_alt_rounded,
            title: 'Commandes',
            selected: _currentIndex == 5,
            onTap: () {
              _navigateWithAnimation(5);
              Navigator.pop(context);
            },
          ),

          const Divider(height: 30),

          // Items conditionnels selon l'état de connexion
          if (isLoggedIn) ...[
            _drawerItem(
              icon: Icons.person_rounded,
              title: 'Profil',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
            _drawerItem(
              icon: Icons.settings_rounded,
              title: 'Paramètres',
              onTap: () {
                Navigator.pop(context);
                // TODO: Ajouter écran paramètres
              },
            ),
            const SizedBox(height: 10),
            _drawerItem(
              icon: Icons.logout_rounded,
              title: 'Déconnexion',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog(context, authService);
              },
            ),
          ] else ...[
            _drawerItem(
              icon: Icons.login_rounded,
              title: 'Connexion',
              color: AppColors.tropicalTeal,
              onTap: () {
                Navigator.pop(context);
                _navigateToLoginScreen(context);
              },
            ),
            _drawerItem(
              icon: Icons.person_add_rounded,
              title: 'Inscription',
              color: AppColors.tropicalTeal,
              onTap: () {
                Navigator.pop(context);
                _navigateToRegisterScreen(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    bool selected = false,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.tropicalTeal.withOpacity(0.1),
        highlightColor: AppColors.tropicalTeal.withOpacity(0.05),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.tropicalTeal.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            dense: true,
            leading: Icon(
              icon,
              size: 22,
              color:
                  color ??
                  (selected ? AppColors.tropicalTeal : Colors.grey.shade700),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
                color:
                    color ??
                    (selected ? AppColors.tropicalTeal : Colors.grey.shade800),
              ),
            ),
            trailing: selected
                ? Icon(Icons.circle, size: 6, color: AppColors.tropicalTeal)
                : null,
          ),
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        _navigateWithAnimation(index);
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.tropicalTeal,
      unselectedItemColor: Colors.grey.shade600,
      backgroundColor: Colors.white,
      elevation: 8,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          activeIcon: Icon(Icons.home_filled),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart_rounded),
          activeIcon: Icon(Icons.shopping_cart_checkout_rounded),
          label: 'Courses',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_rounded),
          activeIcon: Icon(Icons.account_balance_wallet),
          label: 'Portefeuille',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.store_mall_directory_rounded),
          activeIcon: Icon(Icons.store_rounded),
          label: 'Boutiques',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_rounded),
          activeIcon: Icon(Icons.map),
          label: 'Carte',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_rounded),
          activeIcon: Icon(Icons.list_alt),
          label: 'Commandes',
        ),
      ],
    );
  }
}