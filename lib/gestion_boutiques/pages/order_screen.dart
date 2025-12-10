import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  Map<String, String> _productToCourseMap = {}; // Pour mapper produit -> course ID

  // Méthode pour convertir l'enum CoursePriority en String
  String _priorityToString(CoursePriority priority) {
    switch (priority) {
      case CoursePriority.high:
        return 'H';
      case CoursePriority.medium:
        return 'M';
      case CoursePriority.low:
        return 'B';
      default:
        return 'B';
    }
  }

  // Méthode pour obtenir la priorité d'une course
  String _getCoursePriority(Course course) {
    return _priorityToString(course.priority);
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
        final doc = await _firestore
            .collection('portefeuille')
            .doc(userId)
            .get();
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
      print('Nombre de courses sélectionnées: ${widget.selectedCourses.length}');

      // 1. Trier les courses par importance (essentielles > haute priorité > moyenne > basse)
      final sortedCourses = BudgetOptimizer.sortByImportance(widget.selectedCourses);
      
      // Afficher l'ordre pour debug
      print('\n=== COURSES TRIÉES PAR IMPORTANCE ===');
      for (var course in sortedCourses) {
        print('${course.title} - Priorité: ${_getCoursePriority(course)} - Essentiel: ${course.isEssential} - Qté: ${course.quantity} - Prix: ${course.amount} FCFA');
      }

      // 2. Vérifier le budget dès le départ
      final budgetCheck = BudgetOptimizer.checkBudget(sortedCourses, _userBalance);
      print('\n=== VÉRIFICATION BUDGET ===');
      print('Budget disponible: $_userBalance FCFA');
      print('Budget requis: ${budgetCheck.requiredBudget} FCFA');
      print('Déficit: ${budgetCheck.deficit} FCFA');
      print('Statut: ${budgetCheck.statusMessage}');

      // 3. Récupérer TOUS les produits
      setState(() {
        _searchStatus = 'Recherche de tous les produits...';
      });

      final productsSnapshot = await _firestore.collection('products').get();
      print('Total produits dans Firestore: ${productsSnapshot.docs.length}');

      if (productsSnapshot.docs.isEmpty) {
        setState(() {
          _searchStatus = 'Aucun produit dans la base de données';
          _isLoadingBoutiques = false;
        });
        return;
      }

      // 4. Regrouper les produits correspondants par boutique
      final Map<String, Map<String, dynamic>> boutiquesMap = {};

      // Pour chaque course, chercher les produits correspondants
      for (var course in sortedCourses) {
        final courseName = course.title.trim().toLowerCase();
        if (courseName.isEmpty) continue;

        for (var productDoc in productsSnapshot.docs) {
          final productData = productDoc.data();
          final productName = (productData['nom'] ?? '').toString().toLowerCase();
          final boutiqueId = productData['boutique_id']?.toString();

          if (productName.isEmpty || boutiqueId == null || boutiqueId.isEmpty) {
            continue;
          }

          // CORRECTION AMÉLIORÉE : Utiliser une correspondance précise
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
            final matchedNames = boutiquesMap[boutiqueId]!['matchedProductNames'] as Map;
            
            // Éviter les doublons de produits
            if (!matchedNames.containsKey(productKey)) {
              final productId = productDoc.id;
              final coursePriority = _getCoursePriority(course);
              final isEssential = course.isEssential;
              
              // Compter par priorité et essentiel
              if (coursePriority == 'H') {
                boutiquesMap[boutiqueId]!['highPriorityCount']++;
              } else if (coursePriority == 'M') {
                boutiquesMap[boutiqueId]!['mediumPriorityCount']++;
              } else {
                boutiquesMap[boutiqueId]!['lowPriorityCount']++;
              }
              
              if (isEssential) {
                boutiquesMap[boutiqueId]!['essentialCount']++;
              }

              // Ajouter le produit
              boutiquesMap[boutiqueId]!['products'].add({
                'id': productId,
                'nom': productData['nom'] ?? 'Sans nom',
                'price': (productData['price'] ?? productData['prix'] ?? course.unitPrice).toDouble(),
                'coursePriority': coursePriority,
                'requiredQuantity': course.quantity,
                'estimatedPrice': course.amount,
                'productPriority': productData['priority'] ?? 0,
                'description': productData['description'] ?? '',
                'quantity': productData['quantity'] ?? 1,
                'unite': productData['unite'] ?? productData['unit'] ?? course.unit,
                'searchTerm': course.title.trim(),
                'isEssential': isEssential,
                'courseId': course.id,
                'originalCourse': course, // Stocker la course originale
              });

              boutiquesMap[boutiqueId]!['matchCount']++;
              matchedNames[productKey] = true;
              
              // Mapper le produit à la course
              _productToCourseMap[productId] = course.id;

              // NOUVELLE LOGIQUE : Sélection intelligente basée sur le budget et les priorités
              _applySmartSelection(
                boutiqueId, 
                productId, 
                coursePriority, 
                isEssential, 
                course.quantity,
                budgetCheck
              );
            }
          }
        }
      }

      print('\nBoutiques avec produits correspondants: ${boutiquesMap.length}');

      if (boutiquesMap.isEmpty) {
        setState(() {
          _searchStatus = 'Aucune boutique ne possède les produits demandés';
          _isLoadingBoutiques = false;
        });
        
        // Afficher des suggestions pour debug
        print('\n=== SUGGESTIONS ===');
        print('1. Vérifiez que les produits dans Firestore ont des noms similaires aux courses');
        print('2. Vérifiez que les produits ont un champ "boutique_id" valide');
        print('3. Exemples de produits disponibles:');
        final sampleProducts = productsSnapshot.docs.take(3);
        for (var doc in sampleProducts) {
          final data = doc.data();
          print('   - ${data['nom']} (boutique: ${data['boutique_id']})');
        }
        return;
      }

      // 5. Récupérer les informations des boutiques
      setState(() {
        _searchStatus = 'Récupération des informations boutiques...';
      });

      final List<Map<String, dynamic>> boutiquesList = [];

      for (var boutiqueId in boutiquesMap.keys) {
        try {
          final boutiqueDoc = await _firestore
              .collection('boutiques')
              .doc(boutiqueId)
              .get();

          if (boutiqueDoc.exists) {
            final boutiqueData = boutiqueDoc.data()!;

            // Trier les produits par importance
            final products = (boutiquesMap[boutiqueId]!['products'] as List)
                .cast<Map<String, dynamic>>();
            products.sort((a, b) {
              // Essentiels d'abord
              final essentialA = a['isEssential'] as bool? ?? false;
              final essentialB = b['isEssential'] as bool? ?? false;
              if (essentialA && !essentialB) return -1;
              if (!essentialA && essentialB) return 1;
              
              // Puis par priorité
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
              'highPriorityCount': boutiquesMap[boutiqueId]!['highPriorityCount'],
              'mediumPriorityCount': boutiquesMap[boutiqueId]!['mediumPriorityCount'],
              'lowPriorityCount': boutiquesMap[boutiqueId]!['lowPriorityCount'],
              'essentialCount': boutiquesMap[boutiqueId]!['essentialCount'],
              'matchPercentage':
                  ((boutiquesMap[boutiqueId]!['matchCount'] /
                              widget.selectedCourses.length) *
                          100)
                      .round(),
            });
          }
        } catch (e) {
          print('Erreur boutique $boutiqueId: $e');
        }
      }

      // 6. Trier les boutiques par pertinence
      boutiquesList.sort((a, b) {
        // D'abord par nombre de produits essentiels
        if (b['essentialCount'] != a['essentialCount']) {
          return b['essentialCount'].compareTo(a['essentialCount']);
        }
        // Puis par nombre de produits haute priorité
        if (b['highPriorityCount'] != a['highPriorityCount']) {
          return b['highPriorityCount'].compareTo(a['highPriorityCount']);
        }
        // Puis par nombre de produits moyenne priorité
        if (b['mediumPriorityCount'] != a['mediumPriorityCount']) {
          return b['mediumPriorityCount'].compareTo(a['mediumPriorityCount']);
        }
        // Puis par pourcentage de match
        if (b['matchPercentage'] != a['matchPercentage']) {
          return b['matchPercentage'].compareTo(a['matchPercentage']);
        }
        // Enfin par rating
        if (b['rating'] != a['rating']) {
          return b['rating'].compareTo(a['rating']);
        }
        return 0;
      });

      print('\n=== RÉSULTAT FINAL ===');
      for (var boutique in boutiquesList) {
        print('${boutique['nom']} - Match: ${boutique['matchCount']}/${widget.selectedCourses.length}');
        print('  Priorités: H:${boutique['highPriorityCount']} M:${boutique['mediumPriorityCount']} B:${boutique['lowPriorityCount']}');
        print('  Essentiels: ${boutique['essentialCount']}');
      }

      // 7. Ajuster les sélections si budget serré
      if (!budgetCheck.hasEnoughForAll) {
        print('\n=== AJUSTEMENT POUR BUDGET SERRÉ ===');
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

  // CORRESPONDANCE AMÉLIORÉE
  bool _isProductMatchImproved(String productName, String courseName) {
    if (productName.isEmpty || courseName.isEmpty) return false;
    
    // 1. Nettoyer les noms (enlever articles, ponctuation, espaces multiples)
    final productClean = _cleanText(productName);
    final courseClean = _cleanText(courseName);
    
    // 2. Correspondance exacte après nettoyage
    if (productClean == courseClean) {
      return true;
    }
    
    // 3. Correspondance partielle (au moins 70% de similarité)
    final similarity = _calculateSimilarity(productClean, courseClean);
    if (similarity >= 0.7) {
      return true;
    }
    
    // 4. Vérifier si un mot clé significatif est présent
    final productWords = productClean.split(RegExp(r'\s+'));
    final courseWords = courseClean.split(RegExp(r'\s+'));
    
    for (var courseWord in courseWords) {
      if (courseWord.length > 3) { // Mots de plus de 3 lettres seulement
        for (var productWord in productWords) {
          if (productWord.contains(courseWord) || courseWord.contains(productWord)) {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  String _cleanText(String text) {
    // Enlever les articles
    final articles = ['le ', 'la ', 'les ', 'l\'', 'l’', 'un ', 'une ', 'des ', 'du ', 'de la ', 'de l\'', 'au ', 'aux ', 'à la ', 'à l\''];
    String cleaned = text.toLowerCase();
    
    for (var article in articles) {
      if (cleaned.startsWith(article)) {
        cleaned = cleaned.substring(article.length);
        break;
      }
    }
    
    // Enlever la ponctuation et les espaces multiples
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
    String priority, 
    bool isEssential, 
    int requiredQuantity,
    BudgetCheckResult budgetCheck
  ) {
    if (!_selectedProductsByBoutique.containsKey(boutiqueId)) {
      _selectedProductsByBoutique[boutiqueId] = {};
    }
    if (!_quantitiesByBoutique.containsKey(boutiqueId)) {
      _quantitiesByBoutique[boutiqueId] = {};
    }

    // RÈGLES DE SÉLECTION INTELLIGENTE :
    
    // 1. TOUJOURS sélectionner les produits ESSENTIELS (quels que soient la priorité et le budget)
    if (isEssential) {
      _selectedProductsByBoutique[boutiqueId]!.add(productId);
      _quantitiesByBoutique[boutiqueId]![productId] = requiredQuantity;
      print('  -> Sélectionné (ESSENTIEL): $productId');
      return;
    }
    
    // 2. Budget suffisant pour tout : tout sélectionner
    if (budgetCheck.hasEnoughForAll) {
      _selectedProductsByBoutique[boutiqueId]!.add(productId);
      _quantitiesByBoutique[boutiqueId]![productId] = requiredQuantity;
      print('  -> Sélectionné (BUDGET SUFFISANT): $productId');
      return;
    }
    
    // 3. Budget insuffisant : prioriser par importance
    if (priority == 'H') {
      // Haute priorité : sélectionner si budget permet au moins les essentiels + haute priorité
      _selectedProductsByBoutique[boutiqueId]!.add(productId);
      _quantitiesByBoutique[boutiqueId]![productId] = requiredQuantity;
      print('  -> Sélectionné (HAUTE PRIORITÉ): $productId');
    } else if (priority == 'M' && budgetCheck.hasEnoughForEssentials) {
      // Moyenne priorité : seulement si budget permet les essentiels
      _selectedProductsByBoutique[boutiqueId]!.add(productId);
      _quantitiesByBoutique[boutiqueId]![productId] = requiredQuantity;
      print('  -> Sélectionné (MOYENNE PRIORITÉ): $productId');
    } else {
      // Basse priorité : ne pas sélectionner automatiquement
      print('  -> Non sélectionné (PRIORITÉ BASSE/INSUFFISANCE BUDGET): $productId');
    }
  }

  // AJUSTEMENT POUR BUDGET SERRÉ
  void _adjustForBudgetTight(String boutiqueId, Map<String, dynamic> boutique, BudgetCheckResult budgetCheck) {
    final products = boutique['products'] as List;
    final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
    double currentTotal = _calculateSelectedTotal(boutiqueId, boutique);
    
    print('\nAjustement boutique ${boutique['nom']}:');
    print('  Total actuel: $currentTotal FCFA');
    print('  Budget disponible: $_userBalance FCFA');
    print('  Déficit: ${budgetCheck.deficit} FCFA');
    
    // Si budget suffisant, pas d'ajustement
    if (currentTotal <= _userBalance) return;
    
    // Trier les produits sélectionnés par importance (moins importants d'abord)
    final selectedProductsList = products.where((p) => selectedProducts.contains(p['id'])).toList();
    selectedProductsList.sort((a, b) {
      // Moins importants d'abord : basse priorité > moyenne > haute > essentiels
      final priorityOrder = {'H': 3, 'M': 2, 'B': 1};
      final priorityA = priorityOrder[a['coursePriority']] ?? 0;
      final priorityB = priorityOrder[b['coursePriority']] ?? 0;
      
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB); // Basse priorité d'abord
      }
      
      // Même priorité, non-essentiels d'abord
      final essentialA = a['isEssential'] as bool? ?? false;
      final essentialB = b['isEssential'] as bool? ?? false;
      if (essentialA && !essentialB) return 1;
      if (!essentialA && essentialB) return -1;
      
      return 0;
    });
    
    // Désélectionner progressivement les moins importants jusqu'à ce que le budget soit suffisant
    double newTotal = currentTotal;
    for (var product in selectedProductsList) {
      if (newTotal <= _userBalance) break;
      
      final productId = product['id'];
      final isEssential = product['isEssential'] as bool? ?? false;
      
      // Ne jamais désélectionner les essentiels
      if (isEssential) continue;
      
      final productPrice = (product['price'] as num).toDouble();
      final quantity = _quantitiesByBoutique[boutiqueId]?[productId] ?? 1;
      final productTotal = productPrice * quantity;
      
      // Désélectionner ce produit
      _selectedProductsByBoutique[boutiqueId]!.remove(productId);
      _quantitiesByBoutique[boutiqueId]!.remove(productId);
      newTotal -= productTotal;
      
      print('  -> Désélectionné pour budget: ${product['nom']} (${productTotal}FCFA)');
    }
    
    print('  Nouveau total après ajustement: $newTotal FCFA');
  }

  // Toggle la sélection d'un produit
  void _toggleProductSelection(String boutiqueId, String productId) {
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
        // Initialiser avec la quantité requise depuis la course
        final boutique = _availableBoutiques.firstWhere(
          (b) => b['id'] == boutiqueId,
          orElse: () => {'products': []},
        );
        
        final product = (boutique['products'] as List).firstWhere(
          (p) => p['id'] == productId,
          orElse: () => {'requiredQuantity': 1},
        );
        
        _quantitiesByBoutique[boutiqueId]![productId] = product['requiredQuantity'] ?? 1;
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
        // Si quantité = 0, désélectionner le produit
        _selectedProductsByBoutique[boutiqueId]!.remove(productId);
        _quantitiesByBoutique[boutiqueId]!.remove(productId);
      }
    });
  }

  // Sélectionner/déselectionner les produits par priorité
  void _toggleProductsByPriority(String boutiqueId, List<dynamic> products, String priority) {
    setState(() {
      if (!_selectedProductsByBoutique.containsKey(boutiqueId)) {
        _selectedProductsByBoutique[boutiqueId] = {};
      }
      if (!_quantitiesByBoutique.containsKey(boutiqueId)) {
        _quantitiesByBoutique[boutiqueId] = {};
      }

      // Vérifier si tous les produits de cette priorité sont déjà sélectionnés
      bool allSelected = true;
      for (var product in products) {
        if (product['coursePriority'] == priority) {
          if (!_selectedProductsByBoutique[boutiqueId]!.contains(product['id'])) {
            allSelected = false;
            break;
          }
        }
      }

      if (allSelected) {
        // Désélectionner tous les produits de cette priorité (sauf essentiels)
        for (var product in products) {
          if (product['coursePriority'] == priority) {
            final isEssential = product['isEssential'] as bool? ?? false;
            if (!isEssential) { // Ne pas désélectionner les essentiels
              _selectedProductsByBoutique[boutiqueId]!.remove(product['id']);
              _quantitiesByBoutique[boutiqueId]!.remove(product['id']);
            }
          }
        }
      } else {
        // Sélectionner tous les produits de cette priorité
        for (var product in products) {
          if (product['coursePriority'] == priority) {
            _selectedProductsByBoutique[boutiqueId]!.add(product['id']);
            _quantitiesByBoutique[boutiqueId]![product['id']] = product['requiredQuantity'] ?? 1;
          }
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
        
        // Appliquer réduction selon priorité du produit (si applicable)
        int productPriority = product['productPriority'] as int? ?? 0;
        if (productPriority == 1) {
          price *= 0.9;
        } else if (productPriority == 2) {
          price *= 0.95;
        }
        
        total += price * quantity;
      }
    }

    // Ajouter les frais de livraison seulement si des produits sont sélectionnés
    if (selectedProducts.isNotEmpty) {
      total += (boutique['deliveryFee'] ?? 0).toDouble();
    }

    return total;
  }

  // Calculer le total par priorité
  Map<String, double> _calculateTotalByPriority(
      String boutiqueId, Map<String, dynamic> boutique) {
    final Map<String, double> totals = {'H': 0.0, 'M': 0.0, 'B': 0.0};
    final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
    final quantities = _quantitiesByBoutique[boutiqueId] ?? {};

    for (var product in boutique['products'] as List) {
      if (selectedProducts.contains(product['id'])) {
        double price = (product['price'] as num).toDouble();
        int quantity = quantities[product['id']] ?? 1;
        String priority = product['coursePriority'] as String;
        
        // Appliquer réduction selon priorité du produit (si applicable)
        int productPriority = product['productPriority'] as int? ?? 0;
        if (productPriority == 1) {
          price *= 0.9;
        } else if (productPriority == 2) {
          price *= 0.95;
        }
        
        totals[priority] = (totals[priority] ?? 0.0) + (price * quantity);
      }
    }

    return totals;
  }

  // Obtenir la couleur selon la priorité
  Color _getPriorityColor(String priority) {
    switch (priority) {
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

  // Vérifier si le budget est serré
  bool _isBudgetTight(double total) {
    return _userBalance - total < 5000 || total > _userBalance * 0.8;
  }

  // Obtenir les recommandations pour budget serré
  List<String> _getBudgetRecommendations(
      Map<String, double> totalsByPriority, double total, int selectedLow, int selectedMedium) {
    final recommendations = <String>[];

    if (_isBudgetTight(total)) {
      if (selectedLow > 0) {
        recommendations.add('Considérez réduire/supprimer les $selectedLow produit(s) basse priorité');
      }
      if (selectedMedium > 0 && _userBalance - total < 0) {
        recommendations.add('Réduisez les quantités des $selectedMedium produit(s) moyenne priorité');
      }
      if (total > _userBalance) {
        recommendations.add('Budget insuffisant! Réduisez votre sélection');
      }
    }

    return recommendations;
  }

  // Commander les produits SÉLECTIONNÉS
  void _placeOrder(Map<String, dynamic> boutique) async {
    final boutiqueId = boutique['id'];
    final total = _calculateSelectedTotal(boutiqueId, boutique);
    final selectedCount = _selectedProductsByBoutique[boutiqueId]?.length ?? 0;
    final totalsByPriority = _calculateTotalByPriority(boutiqueId, boutique);

    // Vérifier qu'au moins un produit est sélectionné
    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins un produit'),
          backgroundColor: warningColor,
        ),
      );
      return;
    }

    List<String> alerts = [];

    if (total > _userBalance) {
      alerts.add(
        'Solde insuffisant ! Vous avez ${_userBalance.toStringAsFixed(0)} FCFA',
      );
    }

    if (_userBalance - total < 5000) {
      alerts.add('Votre solde sera faible après cette commande');
    }

    // Ajouter les recommandations pour budget serré
    if (_isBudgetTight(total)) {
      // Compter les produits par priorité
      int selectedLow = 0;
      int selectedMedium = 0;
      final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
      for (var product in boutique['products'] as List) {
        if (selectedProducts.contains(product['id'])) {
          if (product['coursePriority'] == 'B') selectedLow++;
          if (product['coursePriority'] == 'M') selectedMedium++;
        }
      }
      
      final recommendations = _getBudgetRecommendations(totalsByPriority, total, selectedLow, selectedMedium);
      alerts.addAll(recommendations);
    }

    if (alerts.isNotEmpty) {
      _showAlertDialog(context, alerts, boutique, total, selectedCount, totalsByPriority);
    } else {
      _confirmAndPlaceOrder(boutique, total, selectedCount);
    }
  }

  void _showAlertDialog(
    BuildContext context,
    List<String> alerts,
    Map<String, dynamic> boutique,
    double total,
    int selectedCount,
    Map<String, double> totalsByPriority,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alertes et Recommandations'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...alerts.map(
                (alert) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        alert.contains('Considérez') || alert.contains('Réduisez') 
                            ? Icons.lightbulb_outline 
                            : Icons.warning,
                        size: 16,
                        color: alert.contains('Considérez') || alert.contains('Réduisez') 
                            ? infoColor 
                            : warningColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alert,
                          style: TextStyle(
                            fontSize: 14,
                            color: alert.contains('Considérez') || alert.contains('Réduisez') 
                                ? infoColor 
                                : warningColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Détails par priorité
              const Text(
                'Détails par priorité:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              if (totalsByPriority['H']! > 0)
                _buildPriorityDetailRow('Haute Priorité', totalsByPriority['H']!, highPriorityColor),
              if (totalsByPriority['M']! > 0)
                _buildPriorityDetailRow('Moyenne Priorité', totalsByPriority['M']!, mediumPriorityColor),
              if (totalsByPriority['B']! > 0)
                _buildPriorityDetailRow('Basse Priorité', totalsByPriority['B']!, lowPriorityColor),
              
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Solde actuel:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${_userBalance.toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: total > _userBalance ? errorColor : null,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total commande:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${total.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Solde après:', style: TextStyle(fontSize: 12)),
                  Text(
                    '${(_userBalance - total).toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontSize: 12,
                      color: _userBalance - total < 0 ? errorColor : 
                             _userBalance - total < 5000 ? warningColor : successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Produits sélectionnés: $selectedCount',
                style: const TextStyle(fontSize: 12),
              ),
              if (boutique['deliveryFee'] > 0)
                Text(
                  'Dont frais de livraison: ${boutique['deliveryFee'].toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ajuster'),
          ),
          ElevatedButton(
            onPressed: total <= _userBalance
                ? () {
                    Navigator.pop(context);
                    _confirmAndPlaceOrder(boutique, total, selectedCount);
                  }
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Confirmer quand même'),
          ),
        ],
      ),
    );
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

  Future<void> _confirmAndPlaceOrder(
    Map<String, dynamic> boutique,
    double total,
    int selectedCount,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez vous connecter'),
            backgroundColor: errorColor,
          ),
        );
        return;
      }

      final boutiqueId = boutique['id'];
      final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
      final quantities = _quantitiesByBoutique[boutiqueId] ?? {};

      // Préparer les items de la commande (uniquement les sélectionnés)
      final List<Map<String, dynamic>> orderItems = [];
      double subtotal = 0;

      for (var product in boutique['products'] as List) {
        if (selectedProducts.contains(product['id'])) {
          final itemPrice = (product['price'] as num).toDouble();
          final quantity = quantities[product['id']] ?? 1;
          final itemTotal = itemPrice * quantity;
          subtotal += itemTotal;

          orderItems.add({
            'productId': product['id'],
            'name': product['nom'],
            'price': itemPrice,
            'quantity': quantity,
            'total': itemTotal,
            'unit': product['unite'],
            'description': product['description'],
            'coursePriority': product['coursePriority'],
            'productPriority': product['productPriority'],
            'originalPrice': product['price'],
            'requiredQuantity': product['requiredQuantity'],
            'estimatedPrice': product['estimatedPrice'],
            'isEssential': product['isEssential'] ?? false,
            'courseId': product['courseId'],
          });
        }
      }

      // Créer la commande dans Firestore
      final orderData = {
        'userId': userId,
        'boutiqueId': boutique['id'],
        'boutiqueName': boutique['nom'],
        'boutiqueAddress': boutique['adresse'],
        'boutiquePhone': boutique['telephone'],
        'items': orderItems,
        'itemsCount': orderItems.length,
        'totalQuantity': quantities.values.fold(0, (sum, qty) => sum + qty),
        'selectedCount': selectedCount,
        'availableCount': (boutique['products'] as List).length,
        'subtotal': subtotal,
        'deliveryFee': boutique['deliveryFee'] ?? 0,
        'total': total,
        'deliveryType': 'pickup',
        'status': 'pending',
        'customerNotes': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'estimatedDelivery': DateTime.now()
            .add(const Duration(hours: 2))
            .toIso8601String(),
        'priorities': {
          'high': _calculateTotalByPriority(boutiqueId, boutique)['H'] ?? 0,
          'medium': _calculateTotalByPriority(boutiqueId, boutique)['M'] ?? 0,
          'low': _calculateTotalByPriority(boutiqueId, boutique)['B'] ?? 0,
        },
      };

      final orderRef = await _firestore.collection('orders').add(orderData);

      // Débiter le solde
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
        'balanceAfter': _userBalance - total,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Mettre à jour le solde local
      setState(() {
        _userBalance -= total;
      });

      // Afficher confirmation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: successColor),
              SizedBox(width: 12),
              Text('Commande confirmée !'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'N°${orderRef.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text('Boutique: ${boutique['nom']}'),
              Text('Produits commandés: $selectedCount'),
              Text('Total: ${total.toStringAsFixed(0)} FCFA'),
              const SizedBox(height: 12),
              const Text(
                'Votre commande sera prête dans environ 2 heures.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la commande: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Widget _buildMatchIndicator(
    int matchCount,
    int totalCourses,
    int percentage,
    int highPriorityCount,
    int mediumPriorityCount,
    int lowPriorityCount,
    int essentialCount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getMatchColor(percentage),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getMatchIcon(percentage), size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                '$matchCount/$totalCourses',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (essentialCount > 0)
                Row(
                  children: [
                    Icon(Icons.star, size: 10, color: Colors.yellow),
                    Text('$essentialCount', style: TextStyle(fontSize: 9, color: Colors.white)),
                    SizedBox(width: 2),
                  ],
                ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: highPriorityColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '$highPriorityCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: mediumPriorityColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '$mediumPriorityCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: lowPriorityColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '$lowPriorityCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                ),
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
    );
  }

  Widget _buildLoadingState() {
    return Column(
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
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _searchStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text('Retour aux courses'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // En-tête avec solde et informations
        Container(
          padding: const EdgeInsets.all(16),
          color: backgroundColor,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Votre solde',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${_userBalance.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Produits recherchés',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${widget.selectedCourses.length} produit(s)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildBudgetWarning(),
            ],
          ),
        ),

        // Bandeau d'information sur les priorités
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
                  ? '⚠️ Solde très faible ! Seuls les produits ESSENTIELS seront sélectionnés automatiquement.'
                  : 'ℹ️  Solde modéré. Les produits basse priorité ne seront pas sélectionnés automatiquement.',
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
    final boutiqueId = boutique['id'];
    final products = boutique['products'] as List;
    final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
    final selectedCount = selectedProducts.length;
    final total = _calculateSelectedTotal(boutiqueId, boutique);
    final totalsByPriority = _calculateTotalByPriority(boutiqueId, boutique);
    final exceedsBalance = total > _userBalance;
    final matchPercentage = boutique['matchPercentage'] as int;
    final isBudgetTight = _isBudgetTight(total);
    
    // Compter les produits sélectionnés par catégorie
    int selectedEssential = 0;
    int selectedHigh = 0;
    int selectedMedium = 0;
    int selectedLow = 0;
    
    for (var product in products) {
      if (selectedProducts.contains(product['id'])) {
        if (product['isEssential'] as bool? ?? false) {
          selectedEssential++;
        } else if (product['coursePriority'] == 'H') {
          selectedHigh++;
        } else if (product['coursePriority'] == 'M') {
          selectedMedium++;
        } else if (product['coursePriority'] == 'B') {
          selectedLow++;
        }
      }
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getMatchColor(matchPercentage).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de la boutique
            _buildBoutiqueHeader(boutique, matchPercentage),
            const SizedBox(height: 16),

            // Contrôles de sélection par priorité
            _buildPriorityControls(boutiqueId, products, selectedEssential, selectedHigh, selectedMedium, selectedLow, boutique),
            const SizedBox(height: 12),

            // Liste des produits triés par priorité
            ...products.map((product) => _buildProductItem(boutiqueId, product, selectedProducts, isBudgetTight)).toList(),

            const SizedBox(height: 16),

            // Total et bouton commander
            _buildOrderSummary(boutiqueId, boutique, selectedCount, total, totalsByPriority, 
                exceedsBalance, matchPercentage, isBudgetTight, selectedEssential, 
                selectedHigh, selectedMedium, selectedLow),
          ],
        ),
      ),
    );
  }

  Widget _buildBoutiqueHeader(Map<String, dynamic> boutique, int matchPercentage) {
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
              if (boutique['telephone'] != null && boutique['telephone'].isNotEmpty)
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
              Row(
                children: [
                  Icon(
                    Icons.star,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(boutique['rating'] as num).toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (boutique['deliveryFee'] > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: infoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Livraison: ${boutique['deliveryFee'].toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          fontSize: 11,
                          color: infoColor,
                          fontWeight: FontWeight.w600,
                        ),
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
    Map<String, dynamic> boutique
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sélection par catégorie:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (boutique['essentialCount'] > 0)
              _buildCategoryToggleButton(
                boutiqueId,
                products,
                'essential',
                'Essentiels',
                Colors.red,
                selectedEssential,
                boutique['essentialCount'],
                Icons.star,
              ),
            if (boutique['essentialCount'] > 0) const SizedBox(width: 8),
            _buildPriorityToggleButton(
              boutiqueId,
              products,
              'H',
              'Haute',
              highPriorityColor,
              selectedHigh,
              boutique['highPriorityCount'],
            ),
            const SizedBox(width: 8),
            _buildPriorityToggleButton(
              boutiqueId,
              products,
              'M',
              'Moyenne',
              mediumPriorityColor,
              selectedMedium,
              boutique['mediumPriorityCount'],
            ),
            const SizedBox(width: 8),
            _buildPriorityToggleButton(
              boutiqueId,
              products,
              'B',
              'Basse',
              lowPriorityColor,
              selectedLow,
              boutique['lowPriorityCount'],
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
    final allSelected = selectedCount == totalCount;
    final anySelected = selectedCount > 0;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleProductsByCategory(boutiqueId, products, category),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: anySelected ? color.withOpacity(0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: anySelected ? color : Colors.grey[300]!,
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
                    ? Icon(
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
                  color: anySelected ? color : Colors.grey[600],
                ),
              ),
              Text(
                '$selectedCount/$totalCount',
                style: TextStyle(
                  fontSize: 10,
                  color: anySelected ? color : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleProductsByCategory(String boutiqueId, List<dynamic> products, String category) {
    setState(() {
      if (!_selectedProductsByBoutique.containsKey(boutiqueId)) {
        _selectedProductsByBoutique[boutiqueId] = {};
      }
      if (!_quantitiesByBoutique.containsKey(boutiqueId)) {
        _quantitiesByBoutique[boutiqueId] = {};
      }

      // Vérifier si tous les produits de cette catégorie sont déjà sélectionnés
      bool allSelected = true;
      for (var product in products) {
        if (category == 'essential' ? (product['isEssential'] as bool? ?? false) : 
            product['coursePriority'] == category) {
          if (!_selectedProductsByBoutique[boutiqueId]!.contains(product['id'])) {
            allSelected = false;
            break;
          }
        }
      }

      if (allSelected) {
        // Désélectionner tous les produits de cette catégorie (sauf essentiels si catégorie essentielle)
        for (var product in products) {
          if (category == 'essential' ? (product['isEssential'] as bool? ?? false) : 
              product['coursePriority'] == category) {
            // Ne pas désélectionner les essentiels si c'est la catégorie essentielle
            if (category != 'essential' || !(product['isEssential'] as bool? ?? false)) {
              _selectedProductsByBoutique[boutiqueId]!.remove(product['id']);
              _quantitiesByBoutique[boutiqueId]!.remove(product['id']);
            }
          }
        }
      } else {
        // Sélectionner tous les produits de cette catégorie
        for (var product in products) {
          if (category == 'essential' ? (product['isEssential'] as bool? ?? false) : 
              product['coursePriority'] == category) {
            _selectedProductsByBoutique[boutiqueId]!.add(product['id']);
            _quantitiesByBoutique[boutiqueId]![product['id']] = product['requiredQuantity'] ?? 1;
          }
        }
      }
    });
  }

  Widget _buildPriorityToggleButton(
    String boutiqueId,
    List<dynamic> products,
    String priority,
    String label,
    Color color,
    int selectedCount,
    int totalCount,
  ) {
    final allSelected = selectedCount == totalCount;
    final anySelected = selectedCount > 0;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleProductsByPriority(boutiqueId, products, priority),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: anySelected ? color.withOpacity(0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: anySelected ? color : Colors.grey[300]!,
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
                    ? Icon(
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
                  color: anySelected ? color : Colors.grey[600],
                ),
              ),
              Text(
                '$selectedCount/$totalCount',
                style: TextStyle(
                  fontSize: 10,
                  color: anySelected ? color : Colors.grey[500],
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
    bool isBudgetTight
  ) {
    final productId = product['id'];
    final isSelected = selectedProducts.contains(productId);
    final quantity = _quantitiesByBoutique[boutiqueId]?[productId] ?? 1;
    double price = (product['price'] as num).toDouble();
    String priority = product['coursePriority'] as String;
    int productPriority = product['productPriority'] as int? ?? 0;
    double adjustedPrice = price;
    bool isEssential = product['isEssential'] as bool? ?? false;

    if (productPriority == 1) {
      adjustedPrice *= 0.9;
    } else if (productPriority == 2) {
      adjustedPrice *= 0.95;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? _getPriorityColor(priority).withOpacity(0.05)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? _getPriorityColor(priority).withOpacity(0.3)
              : Colors.grey[200]!,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleProductSelection(boutiqueId, productId),
                activeColor: _getPriorityColor(priority),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getPriorityColor(priority).withOpacity(0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getPriorityIcon(priority, isEssential),
                  color: isSelected
                      ? _getPriorityColor(priority)
                      : Colors.grey[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isEssential ? Colors.red : _getPriorityColor(priority),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isEssential ? '⭐' : priority,
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
                                  ? _getPriorityColor(priority)
                                  : Colors.black,
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
                              ? _getPriorityColor(priority).withOpacity(0.7)
                              : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (product['requiredQuantity'] != null)
                      Text(
                        'Quantité requise: ${product['requiredQuantity']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(adjustedPrice * quantity).toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? _getPriorityColor(priority)
                          : Colors.grey[800],
                    ),
                  ),
                  if (productPriority > 0 && adjustedPrice != price)
                    Row(
                      children: [
                        Text(
                          '${(price * quantity).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: productPriority == 1
                                ? successColor.withOpacity(0.1)
                                : infoColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            productPriority == 1 ? '-10%' : '-5%',
                            style: TextStyle(
                              fontSize: 10,
                              color: productPriority == 1
                                  ? successColor
                                  : infoColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          
          // Contrôle de quantité
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Quantité:',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: () {
                            if (quantity > 1) {
                              _updateQuantity(boutiqueId, productId, quantity - 1);
                            } else {
                              _toggleProductSelection(boutiqueId, productId);
                            }
                          },
                          padding: const EdgeInsets.all(4),
                        ),
                        Container(
                          width: 30,
                          alignment: Alignment.center,
                          child: Text(
                            quantity.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: () {
                            _updateQuantity(boutiqueId, productId, quantity + 1);
                          },
                          padding: const EdgeInsets.all(4),
                        ),
                      ],
                    ),
                  ),
                  if (isBudgetTight && priority == 'B' && !isEssential)
                    const SizedBox(width: 8),
                  if (isBudgetTight && priority == 'B' && !isEssential)
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
                          'Supprimer',
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
              : isBudgetTight
                  ? Colors.orange[200]!
                  : primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Détails par priorité
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Détails par catégorie:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              if (selectedEssential > 0)
                _buildPriorityTotalRow(
                  '⭐ Essentiels',
                  _calculateCategoryTotal(boutiqueId, boutique, 'essential'),
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
          
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Produits sélectionnés',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '$selectedCount produit(s)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total estimé',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '${total.toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: selectedCount == 0
                          ? Colors.grey
                          : exceedsBalance
                              ? errorColor
                              : isBudgetTight
                                  ? warningColor
                                  : primaryColor,
                    ),
                  ),
                  if (boutique['deliveryFee'] > 0 && selectedCount > 0)
                    Text(
                      'dont ${boutique['deliveryFee'].toStringAsFixed(0)} FCFA de livraison',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          // Message de recommandation pour budget serré
          if (isBudgetTight && (selectedLow > 0 || selectedMedium > 0))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: warningColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getBudgetTightMessage(selectedLow, selectedMedium, total),
                        style: TextStyle(
                          fontSize: 12,
                          color: warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: selectedCount == 0
                ? null
                : () => _placeOrder(boutique),
            icon: Icon(
              selectedCount == 0
                  ? Icons.shopping_cart_outlined
                  : isBudgetTight
                      ? Icons.warning
                      : Icons.shopping_cart,
              size: 20,
            ),
            label: Text(
              selectedCount == 0
                  ? 'Sélectionnez des produits'
                  : isBudgetTight
                      ? 'Vérifier le budget ($selectedCount)'
                      : 'Commander ($selectedCount)',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedCount == 0
                  ? Colors.grey
                  : isBudgetTight
                      ? warningColor
                      : matchPercentage >= 50
                          ? successColor
                          : primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateCategoryTotal(String boutiqueId, Map<String, dynamic> boutique, String category) {
    double total = 0;
    final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
    final quantities = _quantitiesByBoutique[boutiqueId] ?? {};

    for (var product in boutique['products'] as List) {
      if (selectedProducts.contains(product['id'])) {
        bool isInCategory = false;
        if (category == 'essential') {
          isInCategory = product['isEssential'] as bool? ?? false;
        } else {
          isInCategory = product['coursePriority'] == category;
        }
        
        if (isInCategory) {
          double price = (product['price'] as num).toDouble();
          int quantity = quantities[product['id']] ?? 1;
          
          // Appliquer réduction selon priorité du produit
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

  String _getBudgetTightMessage(int selectedLow, int selectedMedium, double total) {
    if (total > _userBalance) {
      return 'Budget insuffisant! Réduisez votre sélection de ${(total - _userBalance).toStringAsFixed(0)} FCFA';
    } else if (selectedLow > 0) {
      return 'Budget serré: réduisez les $selectedLow produit(s) basse priorité';
    } else if (selectedMedium > 0) {
      return 'Budget serré: réduisez les quantités des $selectedMedium produit(s) moyenne priorité';
    } else {
      return 'Budget serré: limitez-vous aux articles essentiels et haute priorité';
    }
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

  IconData _getPriorityIcon(String priority, bool isEssential) {
    if (isEssential) return Icons.star;
    switch (priority) {
      case 'H':
        return Icons.priority_high;
      case 'M':
        return Icons.circle;
      case 'B':
        return Icons.circle_outlined;
      default:
        return Icons.shopping_basket;
    }
  }
}