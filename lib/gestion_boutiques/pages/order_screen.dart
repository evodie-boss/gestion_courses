// order_screen.dart (Code complet corrigé)

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

  Map<String, Map<String, int>> _quantitiesByBoutique = {};
  Map<String, Set<String>> _selectedProductsByBoutique = {};
  Map<String, String> _productToCourseMap = {};

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
    _initializeBoutiqueBalances(); // <-- Ajoutez cette ligne
  }

  Future<void> _initializeBoutiqueBalances() async {
    try {
      final boutiquesSnapshot = await _firestore.collection('boutiques').get();

      for (var doc in boutiquesSnapshot.docs) {
        final data = doc.data();

        // Si le champ balance n'existe pas, l'initialiser à 0
        if (!data.containsKey('balance')) {
          await doc.reference.set({
            'balance': 0.0,
            'lastBalanceUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ Balance initialisée pour ${data['nom'] ?? doc.id}');
        }
      }
    } catch (e) {
      print('Erreur initialisation balances: $e');
    }
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
        } else {
          // Si le portefeuille n'existe pas, le créer
          await _firestore.collection('portefeuille').doc(userId).set({
            'balance': 0.0,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          setState(() {
            _userBalance = 0;
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
      print('Nombre de courses: ${widget.selectedCourses.length}');

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

      print('Produits trouvés: ${productsSnapshot.docs.length}');

      final Map<String, Map<String, dynamic>> boutiquesMap = {};

      for (var course in widget.selectedCourses) {
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

          if (_isExactProductMatch(productName, courseName)) {
            print('✓ Match trouvé: "$courseName" -> "$productName"');

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

              // Sélection automatique basée sur le solde
              _applySmartSelection(boutiqueId, productId, coursePriorityCode,
                  isEssential, course.quantity);
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

      print('Boutiques trouvées: ${boutiquesMap.length}');

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

      setState(() {
        _availableBoutiques = boutiquesList;
        _isLoadingBoutiques = false;
        _searchStatus = '${boutiquesList.length} boutique(s) trouvée(s)';
      });

      print('=== FIN _loadAvailableBoutiques - Succès ===');
    } catch (e) {
      print('ERREUR dans _loadAvailableBoutiques: $e');
      setState(() {
        _isLoadingBoutiques = false;
        _searchStatus = 'Erreur lors de la recherche: $e';
      });
    }
  }

  bool _isExactProductMatch(String productName, String courseName) {
    if (productName.isEmpty || courseName.isEmpty) return false;

    final product = productName.trim().toLowerCase();
    final course = courseName.trim().toLowerCase();

    // 1. Comparaison exacte
    if (product == course) {
      return true;
    }

    // 2. Nettoyer les chaînes
    String cleanText(String text) {
      final articles = [
        'le',
        'la',
        'les',
        'l\'',
        'un',
        'une',
        'des',
        'du',
        'de'
      ];
      var cleaned = text.toLowerCase();

      cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), ' ');

      final words = cleaned.split(' ');
      final filteredWords = words.where((word) {
        return word.isNotEmpty && !articles.contains(word);
      }).toList();

      return filteredWords.join(' ').trim();
    }

    final cleanProduct = cleanText(product);
    final cleanCourse = cleanText(course);

    // 3. Comparaison après nettoyage
    if (cleanProduct == cleanCourse) {
      return true;
    }

    // 4. Vérifier si tous les mots du cours sont dans le produit
    final productWords = cleanProduct.split(RegExp(r'[\s\-_]+'));
    final courseWords = cleanCourse.split(RegExp(r'[\s\-_]+'));

    bool allCourseWordsInProduct = true;
    for (var courseWord in courseWords) {
      if (courseWord.isEmpty) continue;

      if (courseWord.length <= 3) {
        // Pour les mots courts, vérifier comme mot complet
        final wordRegex = RegExp(r'\b' + RegExp.escape(courseWord) + r'\b',
            caseSensitive: false);
        if (!wordRegex.hasMatch(cleanProduct)) {
          allCourseWordsInProduct = false;
          break;
        }
      } else {
        // Pour les mots longs, vérifier s'ils sont contenus
        if (!cleanProduct.contains(courseWord)) {
          allCourseWordsInProduct = false;
          break;
        }
      }
    }

    return allCourseWordsInProduct;
  }

  void _applySmartSelection(String boutiqueId, String productId,
      String priorityCode, bool isEssential, int requiredQuantity) {
    if (!_selectedProductsByBoutique.containsKey(boutiqueId)) {
      _selectedProductsByBoutique[boutiqueId] = {};
    }
    if (!_quantitiesByBoutique.containsKey(boutiqueId)) {
      _quantitiesByBoutique[boutiqueId] = {};
    }

    // Règles de sélection automatique
    final globalTotal = _calculateGlobalTotal();

    if (isEssential) {
      // Toujours sélectionner les essentiels
      _selectedProductsByBoutique[boutiqueId]!.add(productId);
      _quantitiesByBoutique[boutiqueId]![productId] = requiredQuantity;
    } else if (priorityCode == 'H' && _userBalance - globalTotal >= 2000) {
      // Sélectionner haute priorité si budget suffisant
      _selectedProductsByBoutique[boutiqueId]!.add(productId);
      _quantitiesByBoutique[boutiqueId]![productId] = requiredQuantity;
    } else if (priorityCode == 'M' && _userBalance - globalTotal >= 5000) {
      // Sélectionner moyenne priorité si bon budget
      _selectedProductsByBoutique[boutiqueId]!.add(productId);
      _quantitiesByBoutique[boutiqueId]![productId] = requiredQuantity;
    }
    // Basse priorité: ne pas sélectionner automatiquement
  }

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

    print('=== DÉBUT _placeGlobalOrder ===');
    print('Total global: $globalTotal');
    print('Produits sélectionnés: $globalCount');
    print('Solde utilisateur: $_userBalance');

    if (globalCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins un produit.'),
          backgroundColor: warningColor,
        ),
      );
      return;
    }

    if (globalTotal > _userBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Solde insuffisant. Il vous manque ${(globalTotal - _userBalance).toStringAsFixed(0)} FCFA'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    _showGlobalAlertDialog(globalTotal, globalCount);
  }

  void _showGlobalAlertDialog(double globalTotal, int globalCount) {
    final List<String> alerts = [];
    final Map<String, double> globalTotalsByPriority = {
      'H': 0.0,
      'M': 0.0,
      'B': 0.0,
      'E': 0.0
    };
    double globalDeliveryFee = 0.0;

    for (var boutique in _availableBoutiques) {
      final boutiqueId = boutique['id'];
      final selectedCount =
          _selectedProductsByBoutique[boutiqueId]?.length ?? 0;

      if (selectedCount > 0) {
        final totalsByPriority =
            _calculateTotalByPriority(boutiqueId, boutique);

        globalTotalsByPriority['H'] =
            globalTotalsByPriority['H']! + totalsByPriority['H']!;
        globalTotalsByPriority['M'] =
            globalTotalsByPriority['M']! + totalsByPriority['M']!;
        globalTotalsByPriority['B'] =
            globalTotalsByPriority['B']! + totalsByPriority['B']!;
        globalTotalsByPriority['E'] =
            globalTotalsByPriority['E']! + totalsByPriority['E']!;
        globalDeliveryFee += (boutique['deliveryFee'] ?? 0).toDouble();

        if (_userBalance - _calculateSelectedTotal(boutiqueId, boutique) <
            5000) {
          alerts.add('Solde faible après commande chez ${boutique['nom']}');
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shopping_cart_checkout, color: primaryColor),
            const SizedBox(width: 8),
            const Text('Confirmation de Commande'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (alerts.isNotEmpty) ...[
                const Text('Alertes:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: errorColor)),
                const SizedBox(height: 8),
                ...alerts.map((alert) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.warning, size: 14, color: warningColor),
                          const SizedBox(width: 4),
                          Text(alert, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                const Divider(),
              ],
              const Text('Répartition:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (globalTotalsByPriority['E']! > 0)
                _buildPriorityDetailRow(
                    '⭐ Essentiels', globalTotalsByPriority['E']!, Colors.red),
              if (globalTotalsByPriority['H']! > 0)
                _buildPriorityDetailRow('Haute Priorité',
                    globalTotalsByPriority['H']!, highPriorityColor),
              if (globalTotalsByPriority['M']! > 0)
                _buildPriorityDetailRow('Moyenne Priorité',
                    globalTotalsByPriority['M']!, mediumPriorityColor),
              if (globalTotalsByPriority['B']! > 0)
                _buildPriorityDetailRow('Basse Priorité',
                    globalTotalsByPriority['B']!, lowPriorityColor),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Frais de livraison:',
                      style: const TextStyle(fontSize: 14)),
                  Text('${globalDeliveryFee.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL ($globalCount produits):',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${globalTotal.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryColor,
                      )),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Solde restant:', style: TextStyle(fontSize: 14)),
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
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processConfirmedGlobalOrder(globalTotal, globalCount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer la Commande'),
          ),
        ],
      ),
    );
  }

  Future<void> _processConfirmedGlobalOrder(
      double globalTotal, int globalCount) async {
    print('=== DÉBUT _processConfirmedGlobalOrder ===');
    print('Total: $globalTotal, Solde: $_userBalance');

    if (globalTotal > _userBalance) {
      print('❌ Solde insuffisant');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solde insuffisant pour confirmer la commande'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ Utilisateur non connecté');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez vous connecter'),
            backgroundColor: errorColor,
          ),
        );
        return;
      }

      // 1. VÉRIFIER LE PORTEFEUILLE
      final walletRef = _firestore.collection('portefeuille').doc(userId);
      final walletDoc = await walletRef.get();

      if (!walletDoc.exists) {
        print('⚠️ Création du portefeuille...');
        await walletRef.set({
          'balance': _userBalance,
          'lastUpdated': FieldValue.serverTimestamp(),
          'userId': userId,
        });
      }

      // 2. CRÉER UN BATCH POUR TOUTES LES OPÉRATIONS
      final batch = _firestore.batch();
      List<String> orderIds = [];
      double runningTotal = 0;

      // 3. CRÉER LES COMMANDES POUR CHAQUE BOUTIQUE
      for (var boutique in _availableBoutiques) {
        final boutiqueId = boutique['id'];
        final selectedProducts = _selectedProductsByBoutique[boutiqueId] ?? {};
        final quantities = _quantitiesByBoutique[boutiqueId] ?? {};

        if (selectedProducts.isEmpty) continue;

        double subtotal = 0;
        final List<Map<String, dynamic>> orderItems = [];

        for (var product in boutique['products'] as List) {
          if (selectedProducts.contains(product['id'])) {
            double price = (product['price'] as num).toDouble();
            int quantity = quantities[product['id']] ?? 1;

            // Appliquer réduction si applicable
            int productPriority = product['productPriority'] as int? ?? 0;
            if (productPriority == 1)
              price *= 0.9;
            else if (productPriority == 2) price *= 0.95;

            final itemTotal = price * quantity;
            subtotal += itemTotal;

            orderItems.add({
              'productId': product['id'],
              'productName': product['nom'],
              'quantity': quantity,
              'unitPrice': product['price'],
              'finalPrice': price,
              'total': itemTotal,
              'courseId': product['courseId'],
              'coursePriority': product['coursePriority'],
              'isEssential': product['isEssential'],
            });
          }
        }

        final deliveryFee = (boutique['deliveryFee'] ?? 0).toDouble();
        final total = subtotal + deliveryFee;
        runningTotal += total;

        final orderRef = _firestore.collection('orders').doc();
        orderIds.add(orderRef.id);

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
          'selectedCount': selectedProducts.length,
          'userBalanceBefore': _userBalance,
          'userBalanceAfter': _userBalance - runningTotal,
        };

        batch.set(orderRef, orderData);
        print('✅ Commande créée pour ${boutique['nom']}: $total FCFA');

        // ⭐⭐⭐ AJOUT IMPORTANT : CRÉDITER LA BOUTIQUE ⭐⭐⭐
        final boutiqueRef = _firestore.collection('boutiques').doc(boutiqueId);

        // Option 1: Si le champ balance existe déjà
        batch.update(boutiqueRef, {
          'balance': FieldValue.increment(total),
          'lastBalanceUpdate': FieldValue.serverTimestamp(),
        });

        // Option 2: Si vous n'êtes pas sûr que le champ existe
        // batch.set(boutiqueRef, {
        //   'balance': FieldValue.increment(total),
        //   'lastBalanceUpdate': FieldValue.serverTimestamp(),
        // }, SetOptions(merge: true));

        print(
            '💰 Boutique ${boutique['nom']} créditée de ${total.toStringAsFixed(0)} FCFA');

        // ENREGISTRER LE PAIEMENT POUR L'HISTORIQUE
        final paymentRef = _firestore.collection('boutique_payments').doc();
        batch.set(paymentRef, {
          'boutiqueId': boutiqueId,
          'boutiqueName': boutique['nom'],
          'orderId': orderRef.id,
          'userId': userId,
          'amount': total,
          'type': 'order_payment',
          'status': 'credited',
          'timestamp': FieldValue.serverTimestamp(),
          'description':
              'Paiement pour commande #${orderRef.id.substring(0, 8)}',
          'breakdown': {
            'products': subtotal,
            'delivery': deliveryFee,
            'total': total,
          },
        });
      }

      // 4. METTRE À JOUR LE SOLDE UTILISATEUR
      batch.update(walletRef, {
        'balance': FieldValue.increment(-globalTotal),
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastOrderAmount': globalTotal,
        'lastOrderCount': orderIds.length,
      });

      // 5. CRÉER LA TRANSACTION UTILISATEUR
      final transactionRef = _firestore.collection('transactions').doc();
      batch.set(transactionRef, {
        'userId': userId,
        'orderIds': orderIds,
        'amount': -globalTotal,
        'type': 'order_payment',
        'description': 'Commande de $globalCount produit(s)',
        'balanceBefore': _userBalance,
        'balanceAfter': _userBalance - globalTotal,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 6. EXÉCUTER LE BATCH
      await batch.commit();
      print('✅ Batch exécuté avec succès');

      // 7. METTRE À JOUR L'ÉTAT LOCAL
      setState(() {
        _userBalance -= globalTotal;
        _selectedProductsByBoutique.clear();
        _quantitiesByBoutique.clear();
      });

      // 8. AFFICHER CONFIRMATION
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: successColor),
              SizedBox(width: 12),
              Text('Commande Confirmée !'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${orderIds.length} commande(s) passée(s) avec succès.'),
              const SizedBox(height: 8),
              Text('Total débité: ${globalTotal.toStringAsFixed(0)} FCFA'),
              const SizedBox(height: 8),
              Text('Solde restant: ${(_userBalance).toStringAsFixed(0)} FCFA'),
              const SizedBox(height: 12),
              const Text(
                'Les boutiques ont été créditées automatiquement.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
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

      print('=== FIN _processConfirmedGlobalOrder - Succès ===');
    } catch (e, stackTrace) {
      print('❌ ERREUR dans _processConfirmedGlobalOrder: $e');
      print('Stack trace: $stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la commande: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  // ===============================================
  // GESTION DE LA SÉLECTION
  // ===============================================

  void _toggleProductSelection(String boutiqueId, String productId) {
    final boutique =
        _availableBoutiques.firstWhere((b) => b['id'] == boutiqueId);
    final products =
        (boutique['products'] as List).cast<Map<String, dynamic>>();
    final product = products.firstWhere((p) => p['id'] == productId);
    final isEssential = product['isEssential'] as bool? ?? false;

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
        _quantitiesByBoutique[boutiqueId]![productId] =
            product['requiredQuantity'] ?? 1;
      }
    });
  }

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
          _selectedProductsByBoutique[boutiqueId]!.remove(product['id']);
          _quantitiesByBoutique[boutiqueId]!.remove(product['id']);
        }
      } else {
        // Sélectionner
        for (var product in categoryProducts) {
          _selectedProductsByBoutique[boutiqueId]!.add(product['id']);
          _quantitiesByBoutique[boutiqueId]![product['id']] =
              product['requiredQuantity'] ?? 1;
        }
      }
    });
  }

  // ===============================================
  // CALCULS
  // ===============================================

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
        if (productPriority == 1)
          price *= 0.9;
        else if (productPriority == 2) price *= 0.95;

        total += price * quantity;
      }
    }

    if (selectedProducts.isNotEmpty) {
      total += (boutique['deliveryFee'] ?? 0).toDouble();
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
        if (productPriority == 1)
          price *= 0.9;
        else if (productPriority == 2) price *= 0.95;

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
    return total > _userBalance * 0.8 || _userBalance - total < 5000;
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
              const Text('Total Global:',
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
                      ? 'Solde insuffisant'
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  'Tri: Essentiels > Haute > Moyenne > Basse priorité',
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
                  ? 'Solde faible ! Seuls les produits ESSENTIELS sont sélectionnés automatiquement.'
                  : 'Solde modéré. Les produits basse priorité ne sont pas sélectionnés automatiquement.',
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
    final matchPercentage = boutique['matchPercentage'] as int;

    int selectedEssential = 0;
    int selectedHigh = 0;
    int selectedMedium = 0;
    int selectedLow = 0;

    for (var product in products) {
      if (selectedProducts.contains(product['id'])) {
        if (product['isEssential'] as bool? ?? false) selectedEssential++;
        final priority = product['coursePriority'] as String;
        if (priority == 'H')
          selectedHigh++;
        else if (priority == 'M')
          selectedMedium++;
        else if (priority == 'B') selectedLow++;
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: primaryColor.withOpacity(0.1),
          width: 1,
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
                .map((product) =>
                    _buildProductItem(boutiqueId, product, selectedProducts))
                .toList(),
            const SizedBox(height: 16),
            if (selectedCount > 0)
              _buildOrderSummary(
                  boutiqueId,
                  boutique,
                  selectedCount,
                  total,
                  totalsByPriority,
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
    String priorityCode,
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
                _toggleProductsByCategory(boutiqueId, products, priorityCode),
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
  ) {
    final productId = product['id'] as String;
    final isSelected = selectedProducts.contains(productId);
    final quantity = _quantitiesByBoutique[boutiqueId]?[productId] ?? 1;
    final price = (product['price'] as num).toDouble();
    final productPriority = product['productPriority'] as int? ?? 0;
    final priorityCode = product['coursePriority'] as String;
    final isEssential = product['isEssential'] as bool? ?? false;

    double adjustedPrice = price;
    if (productPriority == 1)
      adjustedPrice *= 0.9;
    else if (productPriority == 2) adjustedPrice *= 0.95;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _toggleProductSelection(boutiqueId, productId),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? _getPriorityColor(priorityCode)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? _getPriorityColor(priorityCode)
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                ],
              ),
            ],
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
            : primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedCount == 0
              ? Colors.grey[200]!
              : primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Résumé de la sélection:',
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
                'Total ($selectedCount produits + livraison)',
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
                  color: primaryColor,
                ),
              ),
            ],
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
}
