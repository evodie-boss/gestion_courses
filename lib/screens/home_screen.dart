// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gestion_courses/constants/app_colors.dart';
import 'package:gestion_courses/screens/profile_screen.dart';
import 'package:gestion_courses/screens/login_screen.dart'; // IMPORT AJOUTÉ
import 'package:gestion_courses/screens/register_screen.dart'; // IMPORT AJOUTÉ
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
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _quickActions = [
    {
      'icon': Icons.add_shopping_cart_rounded,
      'title': 'Nouvelle Liste',
      'color': AppColors.tropicalTeal,
      'subtitle': 'Créer une liste',
    },
    {
      'icon': Icons.attach_money_rounded,
      'title': 'Portefeuille',
      'color': Colors.amber.shade700,
      'subtitle': 'Solde: ',
    },
    {
      'icon': Icons.store_mall_directory_rounded,
      'title': 'Boutiques',
      'color': Colors.green.shade700,
      'subtitle': '8 boutiques proches',
    },
    {
      'icon': Icons.map_rounded,
      'title': 'Carte',
      'color': Colors.blue.shade700,
      'subtitle': 'Voir la carte',
    },
  ];

  final List<Map<String, dynamic>> _recentLists = [
    {'name': 'Courses Semaine', 'items': 12, 'date': 'Aujourd\'hui'},
    {'name': 'Fruits & Légumes', 'items': 8, 'date': 'Hier'},
    {'name': 'Produits Ménagers', 'items': 5, 'date': '12 déc'},
  ];

  final List<Map<String, dynamic>> _nearbyShops = [
    {'name': 'Supermarché Proxi', 'distance': '0.5 km', 'rating': 4.5},
    {'name': 'Marché Central', 'distance': '1.2 km', 'rating': 4.2},
    {'name': 'Boulangerie Delice', 'distance': '0.8 km', 'rating': 4.7},
  ];

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
          'ShopEasy',
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
          // AVATAR AVEC MENU DYNAMIQUE - VERSION CORRIGÉE
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
              // Menu dynamique selon l'état de connexion
              if (user != null) {
                // Menu pour utilisateur connecté
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
                // Menu pour utilisateur non connecté
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
          child: _buildCoursesContent(),
        );
      case 2:
        return KeyedSubtree(
          key: const ValueKey('wallet'),
          child: _buildWalletContent(user),
        );
      case 3:
        return KeyedSubtree(
          key: const ValueKey('map'),
          child: _buildMapContent(),
        );
      case 4:
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
          // Bannière de bienvenue avec animation
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
                    AppColors.tropicalTeal,
                    AppColors.tropicalTeal.withOpacity(0.9),
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
                  MouseRegion(
                    onEnter: (_) => _scaleController.forward(),
                    onExit: (_) => _scaleController.reverse(),
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: GestureDetector(
                        onTap: () => _navigateWithAnimation(2),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: AppColors.tropicalTeal,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Solde disponible',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                    Text(
                                      user != null
                                          ? '${user.soldePortefeuille} FCFA'
                                          : '0 FCFA',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 20,
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
                    childAspectRatio: 1.4,
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
                        _navigateWithAnimation(index == 3 ? 3 : index + 1);
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
                          'Listes Récentes',
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
                    ..._recentLists.asMap().entries.map(
                      (entry) => _buildAnimatedListCard(entry.key, entry.value),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Section Boutiques Proches
                const Text(
                  'Boutiques Proches',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.tropicalTeal,
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _nearbyShops
                        .map((shop) => _buildShopCard(shop))
                        .toList(),
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateWithAnimation(3),
              borderRadius: BorderRadius.circular(20),
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
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppColors.tropicalTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          shop['distance'],
                          style: TextStyle(
                            color: AppColors.textColor.withOpacity(0.7),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          shop['rating'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoursesContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_rounded,
            size: 80,
            color: AppColors.tropicalTeal.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mes Courses',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.tropicalTeal,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Gérez vos listes de courses',
            style: TextStyle(fontSize: 16, color: AppColors.textColor),
          ),
        ],
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

  Widget _buildMapContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: AppColors.tropicalTeal,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {},
              ),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher une boutique...',
                    hintStyle: const TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                    fillColor: Colors.white.withOpacity(0.2),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.filter_list_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {},
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_rounded,
                        size: 80,
                        color: AppColors.tropicalTeal,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Carte Interactive',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Visualisez les boutiques autour de vous',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textColor.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tropicalTeal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Activer la localisation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
      ],
    );
  }

  Widget _buildOrdersContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.list_alt_rounded,
            size: 80,
            color: Colors.purple.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mes Commandes',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Suivez vos commandes en cours',
            style: TextStyle(fontSize: 16, color: AppColors.textColor),
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context, AuthService authService) {
    final user = authService.currentUser;
    final isLoggedIn = user != null;

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header du drawer
          Container(
            height: 200,
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
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Text(
                      isLoggedIn &&
                              user.prenom.isNotEmpty &&
                              user.nom.isNotEmpty
                          ? '${user.prenom[0]}${user.nom[0]}'.toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.tropicalTeal,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    isLoggedIn ? '${user.prenom} ${user.nom}' : 'Invité',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isLoggedIn ? user.email : 'Non connecté',
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                  if (isLoggedIn) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Solde: ${user.soldePortefeuille} FCFA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
            icon: Icons.map_rounded,
            title: 'Carte',
            selected: _currentIndex == 3,
            onTap: () {
              _navigateWithAnimation(3);
              Navigator.pop(context);
            },
          ),
          _drawerItem(
            icon: Icons.list_alt_rounded,
            title: 'Commandes',
            selected: _currentIndex == 4,
            onTap: () {
              _navigateWithAnimation(4);
              Navigator.pop(context);
            },
          ),

          const Divider(height: 40),

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
        child: ListTile(
          leading: Icon(
            icon,
            color:
                color ??
                (selected ? AppColors.tropicalTeal : Colors.grey.shade700),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color:
                  color ??
                  (selected ? AppColors.tropicalTeal : Colors.grey.shade800),
            ),
          ),
          trailing: selected
              ? Icon(Icons.circle, size: 8, color: AppColors.tropicalTeal)
              : null,
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
