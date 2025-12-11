// order_screen.dart (Code complet et corrigé)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Importation du modèle de l'utilisateur (Assurez-vous que ce chemin est correct)
import 'package:gestion_courses/models/course_model.dart';

class OrderScreen extends StatefulWidget {
  final List<Course> selectedCourses;

  const OrderScreen({Key? key, required this.selectedCourses})
      : super(key: key);

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Couleurs
  static const Color primaryColor = Color(0xFF0F9E99);
  static const Color highPriorityColor = Color(0xFFEF4444);
  static const Color mediumPriorityColor = Color(0xFFF59E0B);
  static const Color lowPriorityColor = Color(0xFF10B981);
  static const Color backgroundColor = Color(0xFFEFE9E0);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color infoColor = Color(0xFF3B82F6);

  double _userBalance = 0;
  bool _isLoadingBalance = true;
  List<Map<String, dynamic>> _availableBoutiques = [];
  bool _isLoadingBoutiques = true;
  String _searchStatus = 'Recherche des boutiques...';

  // Pour chaque boutique, on garde la sélection des produits ET leurs quantités
  Map<String, Map<String, int>> _quantitiesByBoutique = {};
  Map<String, Set<String>> _selectedProductsByBoutique = {};
  Map<String, String> _productToCourseMap =
      {}; // Pour mapper produit -> course ID

  // Méthode pour obtenir le code court de la priorité d'une course
  String _getCoursePriorityCode(Course course) {
    switch (course.priority) {
      case CoursePriority.high:
        return 'H';
      case CoursePriority.medium:
        return 'M';
      case CoursePriority.low:
        return 'B';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserBalance();
    _loadAvailableBoutiques();
  }

  Future<void> _loadUserBalance() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final doc =
            await _firestore.collection('portefeuille').doc(userId).get();
        if (doc.exists) {
          setState(() {
            _userBalance = (doc.data()?['balance'] ?? 0).toDouble();
          });
        }
      }
    } catch (e) {
      print('Erreur chargement solde: $e');
    } finally {
      setState(() => _isLoadingBalance = false);
    }
  }

  Future<void> _loadAvailableBoutiques() async {
    try {
      print('=== DÉBUT _loadAvailableBoutiques ===');

      final sortedCourses =
          BudgetOptimizer.sortByImportance(widget.selectedCourses);

      final budgetCheck =
          BudgetOptimizer.checkBudget(sortedCourses, _userBalance);

      // 3. Récupérer TOUS les produits
      setState(() {
        _searchStatus = 'Recherche de tous les produits...';
      });

      final productsSnapshot = await _firestore.collection('products').get();

      if (productsSnapshot.docs.isEmpty) {
        setState(() {
          _searchStatus = 'Aucun produit dans la base de données';
          _isLoadingBoutiques = false;
        });
        return;
      }

      // 4. Regrouper les produits correspondants par boutique
      final Map<String, Map<String, dynamic>> boutiquesMap = {};

      for (var course in sortedCourses) {
        final courseName = course.title.trim().toLowerCase();
        if (courseName.isEmpty) continue;

        for (var productDoc in productsSnapshot.docs) {
          final productData = productDoc.data();
          final productName =
              (productData['nom'] ?? '').toString().toLowerCase();
          final boutiqueId = productData['boutique_id']?.toString();

          if (productName.isEmpty || boutiqueId == null || boutiqueId.isEmpty) {
            continue;
          }

          if (_isProductMatchImproved(productName, courseName)) {
            if (!boutiquesMap.containsKey(boutiqueId)) {
              boutiquesMap[boutiqueId] = {
                'id': boutiqueId,
                'products': [],
                'matchCount': 0,
                'highPriorityCount': 0,
                'mediumPriorityCount': 0,
                'lowPriorityCount': 0,
                'essentialCount': 0,
                'matchedProductNames': {},
              };
              // Initialiser la sélection pour cette boutique
              _selectedProductsByBoutique[boutiqueId] = {};
              _quantitiesByBoutique[boutiqueId] = {};
            }

            final productKey = productName.toLowerCase();
            final matchedNames =
                boutiquesMap[boutiqueId]!['matchedProductNames'] as Map;

            if (!matchedNames.containsKey(productKey)) {
              final productId = productDoc.id;
              final coursePriorityCode = _getCoursePriorityCode(course);
              final isEssential = course.isEssential;

              if (coursePriorityCode == 'H') {
                boutiquesMap[boutiqueId]!['highPriorityCount']++;
              } else if (coursePriorityCode == 'M') {
                boutiquesMap[boutiqueId]!['mediumPriorityCount']++;
              } else {
                boutiquesMap[boutiqueId]!['lowPriorityCount']++;
              }

              if (isEssential) {
                boutiquesMap[boutiqueId]!['essentialCount']++;
              }

              boutiquesMap[boutiqueId]!['products'].add({
                'id': productId,
                'nom': productData['nom'] ?? 'Sans nom',
                'price': (productData['price'] ??
                        productData['prix'] ??
                        course.unitPrice)
                    .toDouble(),
                'coursePriority': coursePriorityCode,
                'requiredQuantity': course.quantity,
                'estimatedPrice': course.amount,
                'productPriority': productData['priority'] ?? 0,
                'description': productData['description'] ?? '',
                'quantity': productData['quantity'] ?? 1,
                'unite':
                    productData['unite'] ?? productData['unit'] ?? course.unit,
                'searchTerm': course.title.trim(),
                'isEssential': isEssential,
                'courseId': course.id,
                'originalCourse': course,
              });

              boutiquesMap[boutiqueId]!['matchCount']++;
              matchedNames[productKey] = true;

              _productToCourseMap[productId] = course.id;

              // Sélection intelligente
              _applySmartSelection(boutiqueId, productId, coursePriorityCode,
                  isEssential, course.quantity, budgetCheck);
            }
          }
        }
      }

      if (boutiquesMap.isEmpty) {
        setState(() {
          _searchStatus = 'Aucune boutique ne possède les produits demandés';
          _isLoadingBoutiques = false;
        });
        return;
      }

      // 5. Récupérer les informations des boutiques
      setState(() {
        _searchStatus = 'Récupération des informations boutiques...';
      });

      final List<Map<String, dynamic>> boutiquesList = [];

      for (var boutiqueId in boutiquesMap.keys) {
        try {
          final boutiqueDoc =
              await _firestore.collection('boutiques').doc(boutiqueId).get();

          if (boutiqueDoc.exists) {
            final boutiqueData = boutiqueDoc.data()!;

            // Trier les produits par importance
            final products = (boutiquesMap[boutiqueId]!['products'] as List)
                .cast<Map<String, dynamic>>();
            products.sort((a, b) {
              final essentialA = a['isEssential'] as bool? ?? false;
              final essentialB = b['isEssential'] as bool? ?? false;
              if (essentialA && !essentialB) return -1;
              if (!essentialA && essentialB) return 1;

              final priorityOrder = {'H': 3, 'M': 2, 'B': 1};
              final priorityA = priorityOrder[a['coursePriority']] ?? 0;
              final priorityB = priorityOrder[b['coursePriority']] ?? 0;

              if (priorityB != priorityA) {
                return priorityB.compareTo(priorityA);
              }

              return 0;
            });

            boutiquesList.add({
              'id': boutiqueId,
              'nom': boutiqueData['nom'] ?? 'Boutique sans nom',
              'adresse': boutiqueData['adresse'] ?? '',
              'telephone':
                  boutiqueData['telephone'] ?? boutiqueData['phone'] ?? '',
              'latitude': boutiqueData['latitude'] ?? 0.0,
              'longitude': boutiqueData['longitude'] ?? 0.0,
              'rating': (boutiqueData['rating'] ?? 0.0).toDouble(),
              'deliveryFee': (boutiqueData['deliveryFee'] ?? 0).toDouble(),
              'products': products,
              'matchCount': boutiquesMap[boutiqueId]!['matchCount'],
              'highPriorityCount':
                  boutiquesMap[boutiqueId]!['highPriorityCount'],
              'mediumPriorityCount':
                  boutiquesMap[boutiqueId]!['mediumPriorityCount'],
              'lowPriorityCount': boutiquesMap[boutiqueId]!['lowPriorityCount'],
              'essentialCount': boutiquesMap[boutiqueId]!['essentialCount'],
              'matchPercentage': ((boutiquesMap[boutiqueId]!['matchCount'] /
                          widget.selectedCourses.length) *
                      100)
                  .round(),
            });
          }
        } catch (e) {
          print('Erreur boutique $boutiqueId: $e');
        }
      }

      // 6. Trier les boutiques par pertinence (Essentiel > H > M > Match% > Rating)
      boutiquesList.sort((a, b) {
        if (b['essentialCount'] != a['essentialCount']) {
          return b['essentialCount'].compareTo(a['essentialCount']);
        }
        if (b['highPriorityCount'] != a['highPriorityCount']) {
          return b['highPriorityCount'].compareTo(a['highPriorityCount']);
        }
        if (b['mediumPriorityCount'] != a['mediumPriorityCount']) {
          return b['mediumPriorityCount'].compareTo(a['mediumPriorityCount']);
        }
        if (b['matchPercentage'] != a['matchPercentage']) {
          return b['matchPercentage'].compareTo(a['matchPercentage']);
        }
        if (b['rating'] != a['rating']) {
          return b['rating'].compareTo(a['rating']);
        }
        return 0;
      });

      // 7. Ajuster les sélections si budget serré
      if (!budgetCheck.hasEnoughForAll) {
        for (var boutique in boutiquesList) {
          _adjustForBudgetTight(boutique['id'], boutique, budgetCheck);
        }
      }

      setState(() {
        _availableBoutiques = boutiquesList;
        _isLoadingBoutiques = false;
        _searchStatus = '${boutiquesList.length} boutique(s) trouvée(s)';
      });
    } catch (e) {
      print('ERREUR dans _loadAvailableBoutiques: $e');
      setState(() {
        _isLoadingBoutiques = false;
        _searchStatus = 'Erreur lors de la recherche: $e';
      });
    }
  }

  bool _isProductMatchImproved(String productName, String courseName) {
    if (productName.isEmpty || courseName.isEmpty) return false;

    final productClean = _cleanText(productName);
    final courseClean = _cleanText(courseName);

    if (productClean == courseClean) {
      return true;
    }

    final similarity = _calculateSimilarity(productClean, courseClean);
    if (similarity >= 0.7) {
      return true;
    }

    final productWords = productClean.split(RegExp(r'\s+'));
    final courseWords = courseClean.split(RegExp(r'\s+'));

    for (var courseWord in courseWords) {
      if (courseWord.length > 3) {
        for (var productWord in productWords) {
          if (productWord.contains(courseWord) ||
              courseWord.contains(productWord)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  String _cleanText(String text) {
    final articles = [
      'le ',
      'la ',
      'les ',
      'l\'',
      'l’',
      'un ',
      'une ',
      'des ',
      'du ',
      'de la ',
      'de l\'',
      'au ',
      'aux ',
      'à la ',
      'à l\''
    ];
    String cleaned = text.toLowerCase();

    for (var article in articles) {
      if (cleaned.startsWith(article)) {
        cleaned = cleaned.substring(article.length);
        break;
      }
    }

    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }

  double _calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final set1 = s1.split('');
    final set2 = s2.split('');

    final intersection = set1.where((char) => set2.contains(char)).length;
    final union = set1.length + set2.length - intersection;

    return union > 0 ? intersection / union : 0.0;
  }

  // SÉLECTION INTELLIGENTE BASÉE SUR LE BUDGET
  void _applySmartSelection(
      String boutiqueId,
      String productId,
      String priorityCode, // 'H', 'M', 'B'
      bool isEssential,
      int requiredQuantity,
      BudgetCheckResult budgetCheck) {
    if (!_selectedProductsByBoutique.containsKey(boutiqueId)) {
      _selectedProductsByBoutique[boutiqueId] = {};
    }
    if (!_quantitiesByBoutique.containsKey(boutiqueId)) {
      _quantitiesByBoutique[boutiqueId] = {};
    }

    if (isEssential || budgetCheck.hasEnoughForAll || priorityCode == 'H') {
      _selectedProductsByBoutique[boutiqueId]!.add(productId);
      _quantitiesByBoutique[boutiqueId]![productId] = requiredQuantity;
      return;
    }

    if (priorityCode == 'M' && budgetCheck.hasEnoughForEssentials) {
      _selectedProductsByBoutique[boutiqueId]!.add(productId);
      _quantitiesByBoutique[boutiqueId]![productId] = requiredQuantity;
      return;
    }
  }

  // AJUSTEMENT POUR BUDGET SERRÉ
  void _adjustForBudgetTight(String boutiqueId, Map<String, dynamic> boutique,
      BudgetCheckResult budgetCheck) {
    final products = boutique['products'] as List;
    final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
    double currentTotal = _calculateSelectedTotal(boutiqueId, boutique);

    if (currentTotal <= _userBalance) return;

    final selectedProductsList =
        products.where((p) => selectedProducts.contains(p['id'])).toList();
    selectedProductsList.sort((a, b) {
      final priorityOrder = {'H': 3, 'M': 2, 'B': 1};
      final priorityA = priorityOrder[a['coursePriority']] ?? 0;
      final priorityB = priorityOrder[b['coursePriority']] ?? 0;

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      final essentialA = a['isEssential'] as bool? ?? false;
      final essentialB = b['isEssential'] as bool? ?? false;
      if (essentialA && !essentialB) return 1;
      if (!essentialA && essentialB) return -1;

      return 0;
    });

    double newTotal = currentTotal;
    for (var product in selectedProductsList) {
      if (newTotal <= _userBalance) break;

      final productId = product['id'];
      final isEssential = product['isEssential'] as bool? ?? false;

      if (isEssential) continue;

      final productPrice = (product['price'] as num).toDouble();
      final quantity = _quantitiesByBoutique[boutiqueId]?[productId] ?? 1;
      final productTotal = productPrice * quantity;

      _selectedProductsByBoutique[boutiqueId]!.remove(productId);
      _quantitiesByBoutique[boutiqueId]!.remove(productId);
      newTotal -= productTotal;
    }
  }

  // ===============================================
  // NOUVELLES FONCTIONS GLOBALES (pour le bouton unique)
  // ===============================================

  double _calculateGlobalTotal() {
    double globalTotal = 0;
    for (var boutique in _availableBoutiques) {
      globalTotal += _calculateSelectedTotal(boutique['id'], boutique);
    }
    return globalTotal;
  }

  int _calculateGlobalSelectedCount() {
    int globalCount = 0;
    for (var boutiqueId in _selectedProductsByBoutique.keys) {
      globalCount += _selectedProductsByBoutique[boutiqueId]?.length ?? 0;
    }
    return globalCount;
  }

  void _placeGlobalOrder() {
    final globalTotal = _calculateGlobalTotal();
    final globalCount = _calculateGlobalSelectedCount();

    if (globalCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Veuillez sélectionner au moins un produit dans une boutique.'),
          backgroundColor: warningColor,
        ),
      );
      return;
    }

    if (globalTotal > _userBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Action bloquée: Solde insuffisant pour la commande globale.'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    // 1. Collecter les données de toutes les commandes sélectionnées
    List<String> globalAlerts = [];
    Map<String, double> globalTotalsByPriority = {
      'H': 0.0,
      'M': 0.0,
      'B': 0.0,
      'E': 0.0
    }; // 'E' pour Essentiel
    double globalDeliveryFee = 0.0;

    for (var boutique in _availableBoutiques) {
      final boutiqueId = boutique['id'];
      final total = _calculateSelectedTotal(boutiqueId, boutique);
      final selectedCount =
          _selectedProductsByBoutique[boutiqueId]?.length ?? 0;

      if (selectedCount > 0) {
        final totalsByPriority =
            _calculateTotalByPriority(boutiqueId, boutique);

        // Accumuler les totaux globaux
        globalTotalsByPriority['H'] =
            globalTotalsByPriority['H']! + totalsByPriority['H']!;
        globalTotalsByPriority['M'] =
            globalTotalsByPriority['M']! + totalsByPriority['M']!;
        globalTotalsByPriority['B'] =
            globalTotalsByPriority['B']! + totalsByPriority['B']!;
        globalTotalsByPriority['E'] =
            globalTotalsByPriority['E']! + totalsByPriority['E']!;
        globalDeliveryFee += (boutique['deliveryFee'] ?? 0).toDouble();

        // Collecter les alertes locales
        if (_userBalance - total < 5000 && _userBalance - total >= 0) {
          globalAlerts.add(
              'Solde faible après commande à ${boutique['nom']} (moins de 5000 FCFA restants)');
        }

        if (_isBudgetTight(total)) {
          int selectedLow = 0;
          int selectedMedium = 0;
          final selectedProducts =
              _selectedProductsByBoutique[boutiqueId] ?? {};
          for (var product in (boutique['products'] as List)) {
            if (selectedProducts.contains(product['id'])) {
              if (product['coursePriority'] == 'B') selectedLow++;
              if (product['coursePriority'] == 'M') selectedMedium++;
            }
          }
          final recommendations = _getBudgetRecommendations(
              totalsByPriority, total, selectedLow, selectedMedium);
          for (var rec in recommendations) {
            if (!rec.contains('Solde insuffisant')) {
              globalAlerts.add('(${boutique['nom']}) $rec');
            }
          }
        }
      }
    }

    globalAlerts = globalAlerts.toSet().toList(); // Supprimer les doublons

    // 2. Afficher la boîte de dialogue de confirmation globale
    _showGlobalAlertDialog(context, globalAlerts, globalTotal, globalCount,
        globalTotalsByPriority, globalDeliveryFee);
  }

  void _showGlobalAlertDialog(
    BuildContext context,
    List<String> alerts,
    double globalTotal,
    int globalCount,
    Map<String, double> totalsByPriority,
    double globalDeliveryFee,
  ) {
    final bool exceedsBalance = globalTotal > _userBalance;
    final bool isTight = _isBudgetTight(globalTotal);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(isTight ? Icons.warning_amber : Icons.shopping_cart_checkout,
                color: isTight ? warningColor : primaryColor),
            const SizedBox(width: 8),
            const Text('Confirmation de la Commande Globale'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (alerts.isNotEmpty) ...[
                const Text(
                  'Alertes et Recommandations:',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: errorColor),
                ),
                const SizedBox(height: 8),
                ...alerts.map(
                  (alert) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          alert.contains('Solde faible')
                              ? Icons.warning
                              : Icons.lightbulb_outline,
                          size: 14,
                          color: warningColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alert,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
              ],

              // Détails par priorité
              const Text(
                'Répartition du coût par priorité:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (totalsByPriority['E']! > 0)
                _buildPriorityDetailRow(
                    'Essentiels (⭐)', totalsByPriority['E']!, Colors.red),
              if (totalsByPriority['H']! > 0)
                _buildPriorityDetailRow('Haute Priorité',
                    totalsByPriority['H']!, highPriorityColor),
              if (totalsByPriority['M']! > 0)
                _buildPriorityDetailRow('Moyenne Priorité',
                    totalsByPriority['M']!, mediumPriorityColor),
              if (totalsByPriority['B']! > 0)
                _buildPriorityDetailRow(
                    'Basse Priorité', totalsByPriority['B']!, lowPriorityColor),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Totaux
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      'Frais de livraison (${_availableBoutiques.where((b) => (_selectedProductsByBoutique[b['id']]?.length ?? 0) > 0).length} boutique(s)):',
                      style: const TextStyle(fontSize: 14)),
                  Text('${globalDeliveryFee.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ✅ Retirer le mot-clé 'const' du widget Text
                  Text('TOTAL GLOBAL ( $globalCount produits ):',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize:
                              16) // 💡 On peut garder 'const' sur le TextStyle, car il ne dépend pas de globalCount
                      ),
                  Text('${globalTotal.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: exceedsBalance ? errorColor : primaryColor,
                      )),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Solde restant (estimé):',
                      style: TextStyle(fontSize: 14)),
                  Text(
                    '${(_userBalance - globalTotal).toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontSize: 14,
                      color: (_userBalance - globalTotal) < 0
                          ? errorColor
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ajuster ma sélection'),
          ),
          ElevatedButton(
            onPressed: exceedsBalance
                ? null // Désactiver si le solde est insuffisant
                : () {
                    Navigator.pop(context);
                    _processConfirmedGlobalOrder(
                        globalTotal, globalCount, globalDeliveryFee);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: exceedsBalance ? errorColor : primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              exceedsBalance
                  ? 'Solde insuffisant - Bloqué'
                  : 'Confirmer la Commande Globale',
            ),
          ),
        ],
      ),
    );
  }

  // NOUVELLE LOGIQUE: Traiter toutes les commandes sélectionnées
  Future<void> _processConfirmedGlobalOrder(
    double globalTotal,
    int globalCount,
    double globalDeliveryFee,
  ) async {
    // Double vérification
    if (globalTotal > _userBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action bloquée: Solde insuffisant.'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Veuillez vous connecter'),
                backgroundColor: errorColor),
          );
        }
        return;
      }

      // 1. Traiter chaque commande de boutique séquentiellement
      int ordersPlaced = 0;
      List<String> orderRefs = [];
      double totalDebited = 0;

      for (var boutique in _availableBoutiques) {
        final boutiqueId = boutique['id'];
        final selectedCount =
            _selectedProductsByBoutique[boutiqueId]?.length ?? 0;

        if (selectedCount > 0) {
          final orderResult =
              await _confirmAndPlaceSingleOrder(boutique, totalDebited);
          if (orderResult != null) {
            ordersPlaced++;
            orderRefs.add(orderResult['orderRefId'] as String);
            totalDebited = orderResult['newBalance'] as double;
          }
        }
      }

      if (!mounted) return;

      // 2. Afficher confirmation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: successColor),
              const SizedBox(width: 12),
              Text(
                  'Commande${ordersPlaced > 1 ? 's' : ''} Confirmée${ordersPlaced > 1 ? 's' : ''} !'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Vous avez passé $ordersPlaced commande${ordersPlaced > 1 ? 's' : ''} (Total: ${globalCount} produits)'),
              Text('Total débité: ${globalTotal.toStringAsFixed(0)} FCFA'),
              const SizedBox(height: 8),
              Text(
                  'Solde restant: ${(_userBalance - globalTotal).toStringAsFixed(0)} FCFA'),
              const SizedBox(height: 12),
              const Text(
                'Vos commandes seront traitées et prêtes dans les meilleurs délais.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Retour à l'écran précédent
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Mettre à jour l'état après la commande réussie
      setState(() {
        _userBalance = _userBalance - globalTotal;
        _selectedProductsByBoutique = {};
        _quantitiesByBoutique = {};
        // Note: Vous pourriez vouloir recharger les données pour rafraîchir l'écran parent
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la commande globale: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  // Fonction réutilisée pour passer une SEULE commande (maintenant appelée par la fonction globale)
  Future<Map<String, dynamic>?> _confirmAndPlaceSingleOrder(
    Map<String, dynamic> boutique,
    double currentBalance,
  ) async {
    final boutiqueId = boutique['id'];
    final total = _calculateSelectedTotal(boutiqueId, boutique);
    final selectedCount = _selectedProductsByBoutique[boutiqueId]?.length ?? 0;

    // Si la commande locale est vide ou dépasse le solde, ne rien faire
    if (selectedCount == 0 || total > currentBalance) {
      return null;
    }

    try {
      final userId = _auth.currentUser?.uid;

      final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
      final quantities = _quantitiesByBoutique[boutiqueId] ?? {};

      final List<Map<String, dynamic>> orderItems = [];
      double subtotal = 0;

      for (var product in boutique['products'] as List) {
        if (selectedProducts.contains(product['id'])) {
          final itemPrice = (product['price'] as num).toDouble();
          final quantity = quantities[product['id']] ?? 1;

          double adjustedPrice = itemPrice;
          int productPriority = product['productPriority'] as int? ?? 0;
          if (productPriority == 1) {
            adjustedPrice *= 0.9;
          } else if (productPriority == 2) {
            adjustedPrice *= 0.95;
          }

          final itemTotal = adjustedPrice * quantity;
          subtotal += itemTotal;

          orderItems.add({
            'productId': product['id'],
            'productName': product['nom'],
            'quantity': quantity,
            'unitPrice': itemPrice,
            'finalPrice': adjustedPrice,
            'total': itemTotal,
            'courseId': product['courseId'],
            'coursePriority': product['coursePriority'],
            'isEssential': product['isEssential'],
          });
        }
      }

      final deliveryFee = (boutique['deliveryFee'] ?? 0).toDouble();

      final orderData = {
        'userId': userId,
        'boutiqueId': boutiqueId,
        'boutiqueName': boutique['nom'],
        'items': orderItems,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'total': total,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'selectedCount': selectedCount,
        'userBalanceBefore': currentBalance,
        'userBalanceAfter': currentBalance - total,
      };

      final orderRef = await _firestore.collection('orders').add(orderData);
      final newBalance = currentBalance - total;

      // Débiter le solde (débit immédiat pour cette sous-commande)
      await _firestore.collection('portefeuille').doc(userId).update({
        'balance': FieldValue.increment(-total),
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastOrder': orderRef.id,
        'lastOrderAmount': total,
      });

      // Ajouter l'historique de transaction
      await _firestore.collection('transactions').add({
        'userId': userId,
        'orderId': orderRef.id,
        'amount': -total,
        'type': 'order_payment',
        'description':
            'Commande #${orderRef.id.substring(0, 8)} - ${boutique['nom']} ($selectedCount produit(s))',
        'balanceAfter': newBalance,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {'orderRefId': orderRef.id, 'newBalance': newBalance};
    } catch (e) {
      print('Erreur lors de la commande unique pour ${boutique['nom']}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erreur lors de la commande chez ${boutique['nom']}: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
      return null;
    }
  }

  // ===============================================
  // MODIFICATIONS DE SÉLECTION (Priorisation Stricte)
  // ===============================================

  // Toggle la sélection d'un produit
  void _toggleProductSelection(String boutiqueId, String productId) {
    final boutique =
        _availableBoutiques.firstWhere((b) => b['id'] == boutiqueId);
    final products =
        (boutique['products'] as List).cast<Map<String, dynamic>>();
    final productToToggle = products.firstWhere((p) => p['id'] == productId);
    final isEssential = productToToggle['isEssential'] as bool? ?? false;

    // Logique de blocage (empêcher la sélection si plus prioritaire est non sélectionné)
    if (!_selectedProductsByBoutique[boutiqueId]!.contains(productId)) {
      if (!isEssential) {
        final currentPriorityCode = productToToggle['coursePriority'] as String;
        String missingPriority = '';

        // VÉRIFICATION HAUTE PRIORITÉ manquant
        if (currentPriorityCode == 'B' || currentPriorityCode == 'M') {
          final hasUnselectedHigh = products.any((p) =>
              p['coursePriority'] == 'H' &&
              !(p['isEssential'] as bool? ?? false) &&
              !_selectedProductsByBoutique[boutiqueId]!.contains(p['id']));
          if (hasUnselectedHigh) missingPriority = 'Haute';
        }

        // VÉRIFICATION MOYENNE PRIORITÉ manquant (seulement si la sélection est Basse)
        if (currentPriorityCode == 'B' && missingPriority.isEmpty) {
          final hasUnselectedMedium = products.any((p) =>
              p['coursePriority'] == 'M' &&
              !(p['isEssential'] as bool? ?? false) &&
              !_selectedProductsByBoutique[boutiqueId]!.contains(p['id']));
          if (hasUnselectedMedium) missingPriority = 'Moyenne';
        }

        if (missingPriority.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Veuillez sélectionner tous les produits de priorité $missingPriority avant de sélectionner celui de priorité ${currentPriorityCode == 'B' ? 'Basse' : 'Moyenne'} (sauf les essentiels).'),
              backgroundColor: errorColor,
            ),
          );
          return; // BLOCAGE de la sélection
        }
      }
    }

    // Si la logique de blocage passe ou si c'est une désélection, continuer
    setState(() {
      if (!_selectedProductsByBoutique.containsKey(boutiqueId)) {
        _selectedProductsByBoutique[boutiqueId] = {};
      }
      if (!_quantitiesByBoutique.containsKey(boutiqueId)) {
        _quantitiesByBoutique[boutiqueId] = {};
      }

      if (_selectedProductsByBoutique[boutiqueId]!.contains(productId)) {
        _selectedProductsByBoutique[boutiqueId]!.remove(productId);
        _quantitiesByBoutique[boutiqueId]!.remove(productId);
      } else {
        _selectedProductsByBoutique[boutiqueId]!.add(productId);

        final product = (boutique['products'] as List).firstWhere(
          (p) => p['id'] == productId,
          orElse: () => {'requiredQuantity': 1},
        );

        _quantitiesByBoutique[boutiqueId]![productId] =
            product['requiredQuantity'] ?? 1;
      }
    });
  }

  // Modifier la quantité d'un produit
  void _updateQuantity(String boutiqueId, String productId, int newQuantity) {
    setState(() {
      if (!_quantitiesByBoutique.containsKey(boutiqueId)) {
        _quantitiesByBoutique[boutiqueId] = {};
      }
      if (newQuantity > 0) {
        _quantitiesByBoutique[boutiqueId]![productId] = newQuantity;
      } else {
        _selectedProductsByBoutique[boutiqueId]!.remove(productId);
        _quantitiesByBoutique[boutiqueId]!.remove(productId);
      }
    });
  }

  // Sélectionner/déselectionner les produits par priorité (maintenant avec blocage)
  void _toggleProductsByPriority(
      String boutiqueId, List<dynamic> products, String priorityCode) {
    // Logique de blocage pour les sélections de groupe
    final allSelected = products
        .where((p) => p['coursePriority'] == priorityCode)
        .every((p) =>
            _selectedProductsByBoutique[boutiqueId]?.contains(p['id']) ??
            false);

    if (!allSelected && priorityCode == 'B') {
      // VÉRIFICATION STRICTE: Interdire la sélection de Basse Priorité si H ou M non sélectionné
      final hasUnselectedHighOrMedium = products.any((p) =>
          (p['coursePriority'] == 'H' || p['coursePriority'] == 'M') &&
          !(p['isEssential'] as bool? ?? false) &&
          !(_selectedProductsByBoutique[boutiqueId]?.contains(p['id']) ??
              false));

      if (hasUnselectedHighOrMedium) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Veuillez sélectionner tous les produits de priorité Haute et Moyenne avant de sélectionner la Basse Priorité (sauf les essentiels).'),
            backgroundColor: errorColor,
          ),
        );
        return;
      }
    }

    if (!allSelected && priorityCode == 'M') {
      // VÉRIFICATION STRICTE: Interdire la sélection de Moyenne Priorité si H non sélectionné
      final hasUnselectedHigh = products.any((p) =>
          p['coursePriority'] == 'H' &&
          !(p['isEssential'] as bool? ?? false) &&
          !(_selectedProductsByBoutique[boutiqueId]?.contains(p['id']) ??
              false));

      if (hasUnselectedHigh) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Veuillez sélectionner tous les produits de priorité Haute avant de sélectionner la Moyenne Priorité (sauf les essentiels).'),
            backgroundColor: errorColor,
          ),
        );
        return;
      }
    }

    // Continuer la sélection/désélection normale
    setState(() {
      if (!_selectedProductsByBoutique.containsKey(boutiqueId)) {
        _selectedProductsByBoutique[boutiqueId] = {};
      }
      if (!_quantitiesByBoutique.containsKey(boutiqueId)) {
        _quantitiesByBoutique[boutiqueId] = {};
      }

      if (allSelected) {
        // Désélectionner
        for (var product in products) {
          if (product['coursePriority'] == priorityCode) {
            final isEssential = product['isEssential'] as bool? ?? false;
            if (!isEssential) {
              _selectedProductsByBoutique[boutiqueId]!.remove(product['id']);
              _quantitiesByBoutique[boutiqueId]!.remove(product['id']);
            }
          }
        }
      } else {
        // Sélectionner
        for (var product in products) {
          if (product['coursePriority'] == priorityCode) {
            _selectedProductsByBoutique[boutiqueId]!.add(product['id']);
            _quantitiesByBoutique[boutiqueId]![product['id']] =
                product['requiredQuantity'] ?? 1;
          }
        }
      }
    });
  }

  // Toggle la sélection de tous les produits d'une catégorie (essential ou priority H, M, B)
  void _toggleProductsByCategory(
      String boutiqueId, List<dynamic> products, String category) {
    setState(() {
      if (!_selectedProductsByBoutique.containsKey(boutiqueId)) {
        _selectedProductsByBoutique[boutiqueId] = {};
      }
      if (!_quantitiesByBoutique.containsKey(boutiqueId)) {
        _quantitiesByBoutique[boutiqueId] = {};
      }

      final categoryProducts = products.where((product) {
        if (category == 'essential') {
          return product['isEssential'] as bool? ?? false;
        } else {
          return product['coursePriority'] == category;
        }
      }).toList();

      bool allSelected = true;
      for (var product in categoryProducts) {
        if (!_selectedProductsByBoutique[boutiqueId]!.contains(product['id'])) {
          allSelected = false;
          break;
        }
      }

      if (allSelected) {
        // Désélectionner
        for (var product in categoryProducts) {
          if (category == 'essential') {
            _selectedProductsByBoutique[boutiqueId]!.remove(product['id']);
            _quantitiesByBoutique[boutiqueId]!.remove(product['id']);
          }
        }
      } else {
        // Sélectionner
        for (var product in categoryProducts) {
          // Logique de blocage pour les sélections de groupe (re-check pour les non-essentiels)
          if (category != 'essential') {
            final priorityCode = product['coursePriority'] as String;
            final isEssential = product['isEssential'] as bool? ?? false;

            if (!isEssential) {
              bool isBlocked = false;
              if (priorityCode == 'M') {
                isBlocked = products.any((p) =>
                    p['coursePriority'] == 'H' &&
                    !(p['isEssential'] as bool? ?? false) &&
                    !(_selectedProductsByBoutique[boutiqueId]
                            ?.contains(p['id']) ??
                        false));
              } else if (priorityCode == 'B') {
                isBlocked = products.any((p) =>
                    (p['coursePriority'] == 'H' ||
                        p['coursePriority'] == 'M') &&
                    !(p['isEssential'] as bool? ?? false) &&
                    !(_selectedProductsByBoutique[boutiqueId]
                            ?.contains(p['id']) ??
                        false));
              }

              if (isBlocked) {
                // Ignorer la sélection du produit bloqué dans la boucle de groupe
                continue;
              }
            }
          }

          _selectedProductsByBoutique[boutiqueId]!.add(product['id']);
          _quantitiesByBoutique[boutiqueId]![product['id']] =
              product['requiredQuantity'] ?? 1;
        }
      }
    });
  }

  // Calculer le total pour les produits SÉLECTIONNÉS d'une boutique
  double _calculateSelectedTotal(
      String boutiqueId, Map<String, dynamic> boutique) {
    double total = 0;
    final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
    final quantities = _quantitiesByBoutique[boutiqueId] ?? {};

    for (var product in boutique['products'] as List) {
      if (selectedProducts.contains(product['id'])) {
        double price = (product['price'] as num).toDouble();
        int quantity = quantities[product['id']] ?? 1;

        int productPriority = product['productPriority'] as int? ?? 0;
        if (productPriority == 1) {
          price *= 0.9;
        } else if (productPriority == 2) {
          price *= 0.95;
        }

        total += price * quantity;
      }
    }

    if (selectedProducts.isNotEmpty) {
      total += (boutique['deliveryFee'] ?? 0).toDouble();
    }

    return total;
  }

  double _calculateCategoryTotal(
      String boutiqueId, Map<String, dynamic> boutique, String categoryCode) {
    double total = 0;
    final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
    final quantities = _quantitiesByBoutique[boutiqueId] ?? {};

    for (var product in boutique['products'] as List) {
      if (selectedProducts.contains(product['id'])) {
        final isCategoryMatch = categoryCode == 'essential'
            ? (product['isEssential'] as bool? ?? false)
            : product['coursePriority'] == categoryCode;

        if (isCategoryMatch) {
          double price = (product['price'] as num).toDouble();
          int quantity = quantities[product['id']] ?? 1;

          int productPriority = product['productPriority'] as int? ?? 0;
          if (productPriority == 1) {
            price *= 0.9;
          } else if (productPriority == 2) {
            price *= 0.95;
          }

          total += price * quantity;
        }
      }
    }
    return total;
  }

  Map<String, double> _calculateTotalByPriority(
      String boutiqueId, Map<String, dynamic> boutique) {
    final Map<String, double> totals = {'H': 0.0, 'M': 0.0, 'B': 0.0, 'E': 0.0};
    final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
    final quantities = _quantitiesByBoutique[boutiqueId] ?? {};

    for (var product in boutique['products'] as List) {
      if (selectedProducts.contains(product['id'])) {
        double price = (product['price'] as num).toDouble();
        int quantity = quantities[product['id']] ?? 1;
        String priorityCode = product['coursePriority'] as String;
        bool isEssential = product['isEssential'] as bool? ?? false;

        int productPriority = product['productPriority'] as int? ?? 0;
        if (productPriority == 1) {
          price *= 0.9;
        } else if (productPriority == 2) {
          price *= 0.95;
        }

        if (isEssential) {
          totals['E'] = (totals['E'] ?? 0.0) + (price * quantity);
        } else {
          totals[priorityCode] =
              (totals[priorityCode] ?? 0.0) + (price * quantity);
        }
      }
    }

    return totals;
  }

  Color _getPriorityColor(String priorityCode) {
    switch (priorityCode) {
      case 'H':
        return highPriorityColor;
      case 'M':
        return mediumPriorityColor;
      case 'B':
        return lowPriorityColor;
      default:
        return Colors.grey;
    }
  }

  bool _isBudgetTight(double total) {
    if (total > _userBalance) return true;
    return _userBalance - total < 5000 || total > _userBalance * 0.8;
  }

  String _getBudgetTightMessage(
      int selectedLow, int selectedMedium, double total) {
    if (total > _userBalance) {
      return '⚠️ Solde insuffisant ! Réduisez votre sélection ou rechargez votre compte (déficit de ${(total - _userBalance).toStringAsFixed(0)} FCFA).';
    } else if (selectedLow > 0) {
      return 'Budget serré. Considérez de réduire/supprimer les $selectedLow produit(s) basse priorité.';
    } else if (selectedMedium > 0) {
      return 'Budget serré. Attention aux $selectedMedium produits moyenne priorité.';
    }
    return 'Le total de la commande est élevé. Vérifiez vos quantités.';
  }

  List<String> _getBudgetRecommendations(Map<String, double> totalsByPriority,
      double total, int selectedLow, int selectedMedium) {
    final recommendations = <String>[];

    if (_isBudgetTight(total)) {
      if (selectedLow > 0) {
        recommendations.add(
            'Considérez réduire/supprimer les $selectedLow produit(s) basse priorité');
      }
      if (selectedMedium > 0 && total > _userBalance * 0.9) {
        recommendations.add(
            'Réduisez les quantités des $selectedMedium produit(s) moyenne priorité');
      }
      if (total > _userBalance) {
        recommendations.add(
            '⚠️ Solde insuffisant! Rechargez votre compte avant de commander.');
      }
    }

    return recommendations;
  }

  Widget _buildPriorityDetailRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
          Text(
            '${amount.toStringAsFixed(0)} FCFA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================
  // WIDGETS D'AFFICHAGE
  // ===============================================

  Widget _buildMatchIndicator(
    int matchCount,
    int totalCourses,
    int percentage,
    int highPriorityCount,
    int mediumPriorityCount,
    int lowPriorityCount,
    int essentialCount,
  ) {
    final matchColor = _getMatchColor(percentage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: matchColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getMatchIcon(percentage),
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$matchCount/$totalCourses (${percentage}%)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (essentialCount > 0)
                    Text(
                      '⭐$essentialCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                    ),
                  if (highPriorityCount > 0)
                    Text(
                      ' H$highPriorityCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                    ),
                  if (mediumPriorityCount > 0)
                    Text(
                      ' M$mediumPriorityCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                    ),
                  if (lowPriorityCount > 0)
                    Text(
                      ' B$lowPriorityCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getMatchColor(int percentage) {
    if (percentage >= 80) return successColor;
    if (percentage >= 50) return infoColor;
    if (percentage >= 30) return warningColor;
    return errorColor;
  }

  IconData _getMatchIcon(int percentage) {
    if (percentage >= 80) return Icons.star;
    if (percentage >= 50) return Icons.check_circle;
    if (percentage >= 30) return Icons.warning;
    return Icons.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélectionner une boutique'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoadingBoutiques)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: _isLoadingBoutiques
          ? _buildLoadingState()
          : _availableBoutiques.isEmpty
              ? _buildEmptyState()
              : _buildMainContent(),

      // NOUVEAU: Bouton de commande global en bas de la page
      bottomNavigationBar: _isLoadingBoutiques || _availableBoutiques.isEmpty
          ? null
          : _buildGlobalOrderButton(),
    );
  }

  Widget _buildGlobalOrderButton() {
    final globalTotal = _calculateGlobalTotal();
    final globalCount = _calculateGlobalSelectedCount();
    final exceedsBalance = globalTotal > _userBalance;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Global de la Commande:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                '${globalTotal.toStringAsFixed(0)} FCFA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: exceedsBalance ? errorColor : primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Solde restant estimé:',
                  style: TextStyle(fontSize: 12)),
              Text(
                '${(_userBalance - globalTotal).toStringAsFixed(0)} FCFA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: exceedsBalance ? errorColor : Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: globalCount == 0 || exceedsBalance
                ? null
                : () => _placeGlobalOrder(),
            icon: Icon(
              globalCount == 0
                  ? Icons.shopping_cart_outlined
                  : exceedsBalance
                      ? Icons.block
                      : Icons.shopping_cart,
              size: 20,
            ),
            label: Text(
              globalCount == 0
                  ? 'Sélectionnez des produits'
                  : exceedsBalance
                      ? 'Solde insuffisant - Bloqué'
                      : 'Commander ($globalCount produits)',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: globalCount == 0 || exceedsBalance
                  ? Colors.grey
                  : primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _searchStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.selectedCourses.length} produit(s) recherché(s)',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune boutique disponible',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _searchStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Solde Utilisateur
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: primaryColor.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mon Solde:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: primaryColor,
                ),
              ),
              _isLoadingBalance
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryColor,
                      ),
                    )
                  : Text(
                      '${_userBalance.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _userBalance < 5000 ? errorColor : primaryColor,
                      ),
                    ),
            ],
          ),
        ),

        _buildBudgetWarning(),

        // Indicateur de tri
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                highPriorityColor.withOpacity(0.1),
                mediumPriorityColor.withOpacity(0.1),
                lowPriorityColor.withOpacity(0.1),
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.priority_high, color: highPriorityColor, size: 20),
              const SizedBox(width: 4),
              Icon(Icons.circle, color: mediumPriorityColor, size: 16),
              const SizedBox(width: 4),
              Icon(Icons.circle_outlined, color: lowPriorityColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Les produits sont triés par importance (Essentiels > Haute > Moyenne > Basse)',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${_availableBoutiques.length} boutique(s)',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Liste des boutiques
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _availableBoutiques.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final boutique = _availableBoutiques[index];
              return _buildBoutiqueCard(boutique);
            },
          ),
        ),
        // L'espace est maintenant pris par le bottomNavigationBar
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildBudgetWarning() {
    if (_userBalance >= 10000) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: warningColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _userBalance < 5000 ? Icons.warning : Icons.info,
            color: warningColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _userBalance < 5000
                  ? '⚠️ Solde très faible ! Seuls les produits ESSENTIELS sont sélectionnés automatiquement.'
                  : 'ℹ️ Solde modéré. Les produits basse priorité ne seront pas sélectionnés automatiquement.',
              style: TextStyle(
                color: warningColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoutiqueCard(Map<String, dynamic> boutique) {
    final boutiqueId = boutique['id'] as String;
    final products =
        (boutique['products'] as List).cast<Map<String, dynamic>>();
    final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
    final total = _calculateSelectedTotal(boutiqueId, boutique);
    final selectedCount = selectedProducts.length;
    final totalsByPriority = _calculateTotalByPriority(boutiqueId, boutique);
    final exceedsBalance = total > _userBalance;
    final isBudgetTight = _isBudgetTight(total);
    final matchPercentage = boutique['matchPercentage'] as int;

    int selectedEssential = 0;
    int selectedHigh = 0;
    int selectedMedium = 0;
    int selectedLow = 0;

    for (var product in products) {
      if (selectedProducts.contains(product['id'])) {
        if (product['isEssential'] as bool? ?? false) {
          selectedEssential++;
        }
        final priority = product['coursePriority'] as String;
        if (priority == 'H') {
          selectedHigh++;
        } else if (priority == 'M') {
          selectedMedium++;
        } else if (priority == 'B') {
          selectedLow++;
        }
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: exceedsBalance ? errorColor : primaryColor.withOpacity(0.1),
          width: exceedsBalance ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBoutiqueHeader(boutique, matchPercentage),
            const SizedBox(height: 16),

            _buildPriorityControls(boutiqueId, products, selectedEssential,
                selectedHigh, selectedMedium, selectedLow, boutique),
            const SizedBox(height: 12),

            ...products
                .map((product) => _buildProductItem(
                    boutiqueId, product, selectedProducts, isBudgetTight))
                .toList(),
            const SizedBox(height: 16),

            // Résumé local
            _buildOrderSummary(
                boutiqueId,
                boutique,
                selectedCount,
                total,
                totalsByPriority,
                exceedsBalance,
                matchPercentage,
                isBudgetTight,
                selectedEssential,
                selectedHigh,
                selectedMedium,
                selectedLow),
          ],
        ),
      ),
    );
  }

  Widget _buildBoutiqueHeader(
      Map<String, dynamic> boutique, int matchPercentage) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.store,
            color: primaryColor,
            size: 30,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      boutique['nom'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildMatchIndicator(
                    boutique['matchCount'],
                    widget.selectedCourses.length,
                    matchPercentage,
                    boutique['highPriorityCount'],
                    boutique['mediumPriorityCount'],
                    boutique['lowPriorityCount'],
                    boutique['essentialCount'],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (boutique['adresse'] != null && boutique['adresse'].isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        boutique['adresse'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (boutique['telephone'] != null &&
                  boutique['telephone'].isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.phone,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      boutique['telephone'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              if (boutique['rating'] > 0)
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${boutique['rating'].toStringAsFixed(1)}/5.0',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityControls(
    String boutiqueId,
    List<dynamic> products,
    int selectedEssential,
    int selectedHigh,
    int selectedMedium,
    int selectedLow,
    Map<String, dynamic> boutique,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sélection rapide:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCategoryToggleButton(
              boutiqueId,
              products,
              'essential',
              'Essentiels',
              Colors.red,
              selectedEssential,
              boutique['essentialCount'] as int? ?? 0,
              Icons.star,
            ),
            const SizedBox(width: 8),
            _buildPriorityToggleButton(
              boutiqueId,
              products,
              'H',
              'Haute',
              highPriorityColor,
              selectedHigh,
              boutique['highPriorityCount'] as int? ?? 0,
            ),
            const SizedBox(width: 8),
            _buildPriorityToggleButton(
              boutiqueId,
              products,
              'M',
              'Moyenne',
              mediumPriorityColor,
              selectedMedium,
              boutique['mediumPriorityCount'] as int? ?? 0,
            ),
            const SizedBox(width: 8),
            _buildPriorityToggleButton(
              boutiqueId,
              products,
              'B',
              'Basse',
              lowPriorityColor,
              selectedLow,
              boutique['lowPriorityCount'] as int? ?? 0,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Sélectionnés: ${selectedEssential > 0 ? '⭐$selectedEssential ' : ''}H:$selectedHigh M:$selectedMedium B:$selectedLow',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryToggleButton(
    String boutiqueId,
    List<dynamic> products,
    String category,
    String label,
    Color color,
    int selectedCount,
    int totalCount,
    IconData icon,
  ) {
    final allSelected = selectedCount == totalCount && totalCount > 0;
    final anySelected = selectedCount > 0;

    return Expanded(
      child: GestureDetector(
        onTap: totalCount == 0
            ? null
            : () => _toggleProductsByCategory(boutiqueId, products, category),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: anySelected ? color.withOpacity(0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: totalCount == 0
                  ? Colors.grey[300]!
                  : anySelected
                      ? color
                      : Colors.grey[300]!,
              width: anySelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: allSelected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: color,
                    width: 1.5,
                  ),
                ),
                child: allSelected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : Icon(icon, size: 14, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: totalCount == 0
                      ? Colors.grey
                      : anySelected
                          ? color
                          : Colors.grey[600],
                ),
              ),
              Text(
                '$selectedCount/$totalCount',
                style: TextStyle(
                  fontSize: 10,
                  color: totalCount == 0
                      ? Colors.grey
                      : anySelected
                          ? color
                          : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityToggleButton(
    String boutiqueId,
    List<dynamic> products,
    String priorityCode, // 'H', 'M', 'B'
    String label,
    Color color,
    int selectedCount,
    int totalCount,
  ) {
    final allSelected = selectedCount == totalCount && totalCount > 0;
    final anySelected = selectedCount > 0;

    return Expanded(
      child: GestureDetector(
        onTap: totalCount == 0
            ? null
            : () =>
                _toggleProductsByPriority(boutiqueId, products, priorityCode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: anySelected ? color.withOpacity(0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: totalCount == 0
                  ? Colors.grey[300]!
                  : anySelected
                      ? color
                      : Colors.grey[300]!,
              width: anySelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: allSelected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: color,
                    width: 1.5,
                  ),
                ),
                child: allSelected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: totalCount == 0
                      ? Colors.grey
                      : anySelected
                          ? color
                          : Colors.grey[600],
                ),
              ),
              Text(
                '$selectedCount/$totalCount',
                style: TextStyle(
                  fontSize: 10,
                  color: totalCount == 0
                      ? Colors.grey
                      : anySelected
                          ? color
                          : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductItem(
    String boutiqueId,
    Map<String, dynamic> product,
    Set<String> selectedProducts,
    bool isBudgetTight,
  ) {
    final productId = product['id'] as String;
    final isSelected = selectedProducts.contains(productId);
    final quantity = _quantitiesByBoutique[boutiqueId]?[productId] ?? 1;
    final price = (product['price'] as num).toDouble();
    final productPriority = product['productPriority'] as int? ?? 0;
    final priorityCode = product['coursePriority'] as String; // 'H', 'M', 'B'
    final isEssential = product['isEssential'] as bool? ?? false;

    double adjustedPrice = price;
    if (productPriority == 1) {
      adjustedPrice *= 0.9;
    } else if (productPriority == 2) {
      adjustedPrice *= 0.95;
    }

    final isLowPriorityAndTight =
        isBudgetTight && priorityCode == 'B' && !isEssential;
    // Vérification de la règle de priorité pour désactiver le tap si non sélectionnable
    bool isBlockedByPriority = false;
    if (!isSelected && !isEssential) {
      final boutique =
          _availableBoutiques.firstWhere((b) => b['id'] == boutiqueId);
      final products =
          (boutique['products'] as List).cast<Map<String, dynamic>>();

      if (priorityCode == 'M') {
        isBlockedByPriority = products.any((p) =>
            p['coursePriority'] == 'H' &&
            !(p['isEssential'] as bool? ?? false) &&
            !_selectedProductsByBoutique[boutiqueId]!.contains(p['id']));
      } else if (priorityCode == 'B') {
        isBlockedByPriority = products.any((p) =>
            (p['coursePriority'] == 'H' || p['coursePriority'] == 'M') &&
            !(p['isEssential'] as bool? ?? false) &&
            !_selectedProductsByBoutique[boutiqueId]!.contains(p['id']));
      }
    }

    final isDisabled = isLowPriorityAndTight || isBlockedByPriority;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox de sélection
              GestureDetector(
                onTap: isDisabled && !isSelected
                    ? null
                    : () => _toggleProductSelection(boutiqueId, productId),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? _getPriorityColor(priorityCode)
                        : isDisabled
                            ? Colors.grey[200]
                            : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? _getPriorityColor(priorityCode)
                          : isDisabled
                              ? Colors.grey[400]!
                              : Colors.grey[400]!,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Détails du produit
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pastille de priorité
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isEssential
                                ? Colors.red
                                : _getPriorityColor(priorityCode),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isEssential ? '⭐' : priorityCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isEssential)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: const Text(
                              'ESSENTIEL',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product['nom'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? _getPriorityColor(priorityCode)
                                  : Colors.black,
                              decoration: isDisabled && !isSelected
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (product['description'] != null &&
                        (product['description'] as String).isNotEmpty)
                      Text(
                        product['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? _getPriorityColor(priorityCode).withOpacity(0.7)
                              : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (product['requiredQuantity'] != null)
                      Text(
                        'Quantité requise: ${product['requiredQuantity']} ${product['unite']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Quantité et prix
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(adjustedPrice * quantity).toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? _getPriorityColor(priorityCode)
                          : Colors.grey[800],
                    ),
                  ),
                  if (productPriority > 0 && adjustedPrice != price)
                    Row(
                      children: [
                        Text(
                          '${(price * quantity).toStringAsFixed(0)} FCFA',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '-${(100 - (adjustedPrice / price * 100)).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: successColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),

                  // Contrôle de quantité
                  if (isSelected)
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: _getPriorityColor(priorityCode)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove,
                                size: 16,
                                color: _getPriorityColor(priorityCode)),
                            onPressed: () => _updateQuantity(
                                boutiqueId, productId, quantity - 1),
                            padding: const EdgeInsets.all(4),
                          ),
                          Text(
                            quantity.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _getPriorityColor(priorityCode),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add,
                                size: 16,
                                color: _getPriorityColor(priorityCode)),
                            onPressed: () => _updateQuantity(
                                boutiqueId, productId, quantity + 1),
                            padding: const EdgeInsets.all(4),
                          ),
                        ],
                      ),
                    ),

                  // Message si produit non sélectionnable
                  if (isDisabled && !isSelected)
                    Text(
                      isBlockedByPriority
                          ? 'Priorité non respectée'
                          : 'Budget serré',
                      style: TextStyle(
                        fontSize: 10,
                        color: errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Ligne d'action pour basse priorité si budget serré
          if (isBudgetTight &&
              priorityCode == 'B' &&
              !isEssential &&
              isSelected)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => _toggleProductSelection(boutiqueId, productId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: const Text(
                        'Supprimer (Basse Priorité)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                        ),
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

  Widget _buildOrderSummary(
    String boutiqueId,
    Map<String, dynamic> boutique,
    int selectedCount,
    double total,
    Map<String, double> totalsByPriority,
    bool exceedsBalance,
    int matchPercentage,
    bool isBudgetTight,
    int selectedEssential,
    int selectedHigh,
    int selectedMedium,
    int selectedLow,
  ) {
    // Si aucun produit sélectionné, on n'affiche que le total de la boutique (0)
    if (selectedCount == 0 && total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selectedCount == 0
            ? Colors.grey[50]
            : isBudgetTight
                ? Colors.orange[50]
                : primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedCount == 0
              ? Colors.grey[200]!
              : exceedsBalance
                  ? errorColor
                  : isBudgetTight
                      ? Colors.orange[200]!
                      : primaryColor.withOpacity(0.2),
          width: exceedsBalance ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Résumé de la sélection dans cette boutique:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              if (selectedEssential > 0)
                _buildPriorityTotalRow(
                  '⭐ Essentiels',
                  totalsByPriority['E']!,
                  selectedEssential,
                  Colors.red,
                ),
              if (totalsByPriority['H']! > 0)
                _buildPriorityTotalRow(
                  'Haute Priorité',
                  totalsByPriority['H']!,
                  selectedHigh,
                  highPriorityColor,
                ),
              if (totalsByPriority['M']! > 0)
                _buildPriorityTotalRow(
                  'Moyenne Priorité',
                  totalsByPriority['M']!,
                  selectedMedium,
                  mediumPriorityColor,
                ),
              if (totalsByPriority['B']! > 0)
                _buildPriorityTotalRow(
                  'Basse Priorité',
                  totalsByPriority['B']!,
                  selectedLow,
                  lowPriorityColor,
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sous-total ($selectedCount produits) + Frais de livraison',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${total.toStringAsFixed(0)} FCFA',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: exceedsBalance ? errorColor : primaryColor,
                ),
              ),
            ],
          ),
          if (isBudgetTight && selectedCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      exceedsBalance ? Icons.error : Icons.lightbulb_outline,
                      color: exceedsBalance ? errorColor : warningColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getBudgetTightMessage(
                            selectedLow, selectedMedium, total),
                        style: TextStyle(
                          fontSize: 12,
                          color: exceedsBalance ? errorColor : warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriorityTotalRow(
    String label,
    double amount,
    int count,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$label ($count):',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Text(
            '${amount.toStringAsFixed(0)} FCFA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPriorityIcon(String priorityCode, bool isEssential) {
    if (isEssential) return Icons.star;
    switch (priorityCode) {
      case 'H':
        return Icons.priority_high;
      case 'M':
        return Icons.circle;
      case 'B':
        return Icons.circle_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}
