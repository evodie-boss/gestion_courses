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
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color backgroundColor = Color(0xFFEFE9E0);
  static const Color infoColor = Color(0xFF3B82F6);

  double _userBalance = 0;
  bool _isLoadingBalance = true;
  List<Map<String, dynamic>> _availableBoutiques = [];
  bool _isLoadingBoutiques = true;
  String _searchStatus = 'Recherche des boutiques...';

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
      print(
        'Nombre de courses sélectionnées: ${widget.selectedCourses.length}',
      );

      // 1. Préparer la liste des noms de produits recherchés
      final List<String> searchTerms = [];

      for (var course in widget.selectedCourses) {
        if (course.title.trim().isNotEmpty) {
          final courseName = course.title.trim();

          // Version originale (ex: "Poulet")
          searchTerms.add(courseName);

          // Version en minuscules (ex: "poulet")
          searchTerms.add(courseName.toLowerCase());

          // Version capitalisée (ex: "Poulet" si c'est "poulet")
          if (courseName != courseName.toUpperCase()) {
            searchTerms.add(
              courseName[0].toUpperCase() +
                  courseName.substring(1).toLowerCase(),
            );
          }

          // Version nettoyée
          final cleaned = _cleanSearchTerm(courseName);
          if (cleaned.isNotEmpty && cleaned != courseName) {
            searchTerms.add(cleaned);
            searchTerms.add(cleaned.toLowerCase());
            searchTerms.add(
              cleaned[0].toUpperCase() + cleaned.substring(1).toLowerCase(),
            );
          }

          print('Course: "$courseName"');
        }
      }

      // Filtrer les doublons
      final uniqueSearchTerms = searchTerms
          .toSet()
          .where((t) => t.isNotEmpty)
          .toList();
      print('Termes de recherche uniques: $uniqueSearchTerms');

      if (uniqueSearchTerms.isEmpty) {
        setState(() {
          _searchStatus = 'Aucun produit spécifié dans les courses';
          _isLoadingBoutiques = false;
        });
        return;
      }

      // 2. Méthode 1: Récupérer TOUS les produits (meilleure approche)
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

      // 3. Regrouper les produits correspondants par boutique
      final Map<String, Map<String, dynamic>> boutiquesMap = {};

      for (var productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        final productName = (productData['nom'] ?? '').toString();
        final boutiqueId = productData['boutique_id']?.toString();

        if (productName.isEmpty || boutiqueId == null || boutiqueId.isEmpty) {
          continue;
        }

        // Vérifier si ce produit correspond à une des courses
        bool isMatch = false;
        String matchedSearchTerm = '';

        for (var searchTerm in uniqueSearchTerms) {
          if (_isProductMatch(productName, searchTerm)) {
            isMatch = true;
            matchedSearchTerm = searchTerm;
            break;
          }
        }

        if (isMatch) {
          if (!boutiquesMap.containsKey(boutiqueId)) {
            boutiquesMap[boutiqueId] = {
              'id': boutiqueId,
              'products': [],
              'matchCount': 0,
              'matchedProductNames': {},
            };
          }

          // Vérifier si on a déjà ce produit (éviter les doublons)
          final productKey = productName.toLowerCase();
          final matchedNames =
              boutiquesMap[boutiqueId]!['matchedProductNames'] as Map;
          if (!matchedNames.containsKey(productKey)) {
            boutiquesMap[boutiqueId]!['products'].add({
              'id': productDoc.id,
              'nom': productName,
              'price': (productData['price'] ?? productData['prix'] ?? 0)
                  .toDouble(),
              'priority': productData['priority'] ?? 0,
              'description': productData['description'] ?? '',
              'quantity': productData['quantity'] ?? 1,
              'unite': productData['unite'] ?? productData['unit'] ?? 'unité',
              'searchTerm': matchedSearchTerm,
            });

            boutiquesMap[boutiqueId]!['matchCount']++;
            matchedNames[productKey] = true;

            print('✓ Match trouvé: "$productName" (boutique: $boutiqueId)');
          }
        }
      }

      print('Boutiques avec produits correspondants: ${boutiquesMap.length}');

      if (boutiquesMap.isEmpty) {
        setState(() {
          _searchStatus = 'Aucune boutique ne possède les produits demandés';
          _isLoadingBoutiques = false;
        });

        // Afficher quelques exemples de produits disponibles pour debug
        print('\n=== EXEMPLES DE PRODUITS DISPONIBLES ===');
        final sampleProducts = productsSnapshot.docs.take(5);
        for (var doc in sampleProducts) {
          final data = doc.data();
          print('  - ${data['nom'] ?? 'Sans nom'} (ID: ${doc.id})');
        }
        return;
      }

      // 4. Récupérer les informations des boutiques
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
              'products': boutiquesMap[boutiqueId]!['products'],
              'matchCount': boutiquesMap[boutiqueId]!['matchCount'],
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

      // 5. Trier les boutiques par pertinence
      boutiquesList.sort((a, b) {
        if (b['matchPercentage'] != a['matchPercentage']) {
          return b['matchPercentage'].compareTo(a['matchPercentage']);
        }
        if (b['rating'] != a['rating']) {
          return b['rating'].compareTo(a['rating']);
        }
        return 0;
      });

      print('\n=== RÉSULTAT FINAL ===');
      print('Boutiques disponibles: ${boutiquesList.length}');
      for (var boutique in boutiquesList) {
        print(
          '  - ${boutique['nom']} : ${boutique['matchCount']}/${widget.selectedCourses.length} produits (${boutique['matchPercentage']}%)',
        );
        final products = boutique['products'] as List;
        for (var product in products.take(3)) {
          print('    • ${product['nom']} (${product['price']} FCFA)');
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

  // Nettoyer le terme de recherche
  String _cleanSearchTerm(String term) {
    String cleaned = term.trim();

    // Liste des articles français
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
      'de l’',
      'au ',
      'aux ',
      'à la ',
      'à l\'',
      'à l’',
    ];

    // Enlever les articles au début (insensible à la casse)
    for (var article in articles) {
      if (cleaned.toLowerCase().startsWith(article)) {
        cleaned = cleaned.substring(article.length);
        break;
      }
    }

    // Enlever la ponctuation
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\sÀ-ÿ]'), '');

    return cleaned.trim();
  }

  // Vérifier si le produit correspond au terme de recherche
  bool _isProductMatch(String productName, String searchTerm) {
    if (productName.isEmpty || searchTerm.isEmpty) return false;

    // Convertir en minuscules pour comparaison insensible à la casse
    final productLower = productName.toLowerCase();
    final searchLower = searchTerm.toLowerCase();

    // 1. Correspondance exacte (insensible à la casse)
    if (productLower == searchLower) {
      return true;
    }

    // 2. Le produit contient le terme de recherche
    if (productLower.contains(searchLower)) {
      return true;
    }

    // 3. Le terme de recherche contient le nom du produit
    if (searchLower.contains(productLower)) {
      return true;
    }

    // 4. Correspondance par mots (diviser en mots)
    final productWords = productLower.split(RegExp(r'\s+'));
    final searchWords = searchLower.split(RegExp(r'\s+'));

    // Vérifier si un mot du produit correspond à un mot recherché
    for (var searchWord in searchWords) {
      for (var productWord in productWords) {
        if (productWord == searchWord) {
          return true;
        }
        if (productWord.contains(searchWord) && searchWord.length > 2) {
          return true;
        }
        if (searchWord.contains(productWord) && productWord.length > 2) {
          return true;
        }
      }
    }

    // 5. Gérer les pluriels
    if (_areSimilarWords(productLower, searchLower)) {
      return true;
    }

    return false;
  }

  // Vérifier si les mots sont similaires (pluriel/singulier)
  bool _areSimilarWords(String word1, String word2) {
    if (word1 == word2) return true;

    // Règles pour les pluriels français
    final singularWord1 = _toSingular(word1);
    final singularWord2 = _toSingular(word2);

    if (singularWord1 == singularWord2) {
      return true;
    }

    // Règles spécifiques
    if (word1.endsWith('s') && word1.substring(0, word1.length - 1) == word2) {
      return true;
    }
    if (word2.endsWith('s') && word2.substring(0, word2.length - 1) == word1) {
      return true;
    }

    return false;
  }

  // Convertir un mot au singulier (simplifié)
  String _toSingular(String word) {
    if (word.endsWith('s') &&
        !word.endsWith('ss') &&
        !word.endsWith('us') &&
        !word.endsWith('is')) {
      return word.substring(0, word.length - 1);
    }
    if (word.endsWith('aux')) {
      return word.substring(0, word.length - 3) + 'al';
    }
    if (word.endsWith('eaux')) {
      return word.substring(0, word.length - 4) + 'eau';
    }
    return word;
  }

  // Calculer le total ajusté selon la priorité
  double _calculateOrderTotal(Map<String, dynamic> boutique) {
    double total = 0;
    for (var product in boutique['products'] as List) {
      double price = (product['price'] as num).toDouble();
      int priority = product['priority'] as int? ?? 0;

      if (priority == 1) {
        price *= 0.9; // -10% pour priorité haute
      } else if (priority == 2) {
        price *= 0.95; // -5% pour priorité moyenne
      }

      total += price;
    }

    total += (boutique['deliveryFee'] ?? 0).toDouble();

    return total;
  }

  // Commander maintenant
  void _placeOrder(Map<String, dynamic> boutique) async {
    final total = _calculateOrderTotal(boutique);

    List<String> alerts = [];

    if (total > _userBalance) {
      alerts.add(
        'Solde insuffisant ! Vous avez ${_userBalance.toStringAsFixed(0)} FCFA',
      );
    }

    if (_userBalance - total < 5000) {
      alerts.add('Votre solde sera faible après cette commande');
    }

    if (alerts.isNotEmpty) {
      _showAlertDialog(context, alerts, boutique, total);
    } else {
      _confirmAndPlaceOrder(boutique, total);
    }
  }

  void _showAlertDialog(
    BuildContext context,
    List<String> alerts,
    Map<String, dynamic> boutique,
    double total,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alertes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(alert, style: const TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Solde actuel: ${_userBalance.toStringAsFixed(0)} FCFA',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: warningColor,
              ),
            ),
            Text(
              'Total commande: ${total.toStringAsFixed(0)} FCFA',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (boutique['deliveryFee'] > 0)
              Text(
                'Dont frais de livraison: ${boutique['deliveryFee'].toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: total <= _userBalance
                ? () {
                    Navigator.pop(context);
                    _confirmAndPlaceOrder(boutique, total);
                  }
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndPlaceOrder(
    Map<String, dynamic> boutique,
    double total,
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

      final List<Map<String, dynamic>> orderItems = [];
      double subtotal = 0;

      for (var product in boutique['products']) {
        final itemPrice = (product['price'] as num).toDouble();
        subtotal += itemPrice;

        orderItems.add({
          'productId': product['id'],
          'name': product['nom'],
          'price': itemPrice,
          'quantity': product['quantity'] ?? 1,
          'unit': product['unite'],
          'description': product['description'],
        });
      }

      final orderData = {
        'userId': userId,
        'boutiqueId': boutique['id'],
        'boutiqueName': boutique['nom'],
        'boutiqueAddress': boutique['adresse'],
        'boutiquePhone': boutique['telephone'],
        'items': orderItems,
        'itemsCount': orderItems.length,
        'matchPercentage': boutique['matchPercentage'],
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
      };

      final orderRef = await _firestore.collection('orders').add(orderData);

      await _firestore.collection('portefeuille').doc(userId).update({
        'balance': FieldValue.increment(-total),
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastOrder': orderRef.id,
        'lastOrderAmount': total,
      });

      await _firestore.collection('transactions').add({
        'userId': userId,
        'orderId': orderRef.id,
        'amount': -total,
        'type': 'order_payment',
        'description':
            'Commande #${orderRef.id.substring(0, 8)} - ${boutique['nom']}',
        'balanceAfter': _userBalance - total,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _userBalance -= total;
      });

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
              Text('Total: ${total.toStringAsFixed(0)} FCFA'),
              Text('${orderItems.length} produit(s)'),
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
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getMatchColor(percentage),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getMatchIcon(percentage), size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$matchCount/$totalCourses ($percentage%)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
          ? Column(
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
            )
          : _availableBoutiques.isEmpty
          ? Center(
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
            )
          : Column(
              children: [
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
                      if (_userBalance < 10000)
                        Container(
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
                                Icons.warning_amber,
                                color: warningColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _userBalance < 5000
                                      ? 'Solde très faible ! Rechargez votre portefeuille.'
                                      : 'Solde faible. Pensez à recharger.',
                                  style: TextStyle(
                                    color: warningColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

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
                        primaryColor.withOpacity(0.1),
                        infoColor.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.store, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_availableBoutiques.length} boutique(s) trouvée(s)',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Triées par pertinence',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableBoutiques.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final boutique = _availableBoutiques[index];
                      final total = _calculateOrderTotal(boutique);
                      final exceedsBalance = total > _userBalance;
                      final matchPercentage =
                          boutique['matchPercentage'] as int;

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: _getMatchColor(
                              matchPercentage,
                            ).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (boutique['adresse'] != null &&
                                            boutique['adresse'].isNotEmpty)
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: infoColor.withOpacity(
                                                    0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
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
                              ),

                              const SizedBox(height: 16),

                              const Text(
                                'Produits disponibles:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),

                              ...((boutique['products'] as List).take(5).map((
                                product,
                              ) {
                                double price = (product['price'] as num)
                                    .toDouble();
                                int priority = product['priority'] as int? ?? 0;
                                double adjustedPrice = price;

                                if (priority == 1) {
                                  adjustedPrice *= 0.9;
                                } else if (priority == 2) {
                                  adjustedPrice *= 0.95;
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.shopping_basket,
                                          color: primaryColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product['nom'],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (product['description'] !=
                                                    null &&
                                                (product['description']
                                                        as String)
                                                    .isNotEmpty)
                                              Text(
                                                product['description'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            if (product['searchTerm'] != null)
                                              Text(
                                                'Correspond à: ${product['searchTerm']}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green[700],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${adjustedPrice.toStringAsFixed(0)} FCFA',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                          if (priority > 0)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: priority == 1
                                                    ? successColor.withOpacity(
                                                        0.1,
                                                      )
                                                    : infoColor.withOpacity(
                                                        0.1,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                priority == 1 ? '-10%' : '-5%',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: priority == 1
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
                                );
                              }).toList()),

                              if ((boutique['products'] as List).length > 5)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '+ ${(boutique['products'] as List).length - 5} autre(s) produit(s)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: primaryColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 16),

                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: exceedsBalance
                                      ? Colors.grey[100]
                                      : primaryColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            color: exceedsBalance
                                                ? errorColor
                                                : primaryColor,
                                          ),
                                        ),
                                        if (boutique['deliveryFee'] > 0)
                                          Text(
                                            'dont ${boutique['deliveryFee'].toStringAsFixed(0)} FCFA de livraison',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: exceedsBalance
                                          ? null
                                          : () => _placeOrder(boutique),
                                      icon: Icon(
                                        exceedsBalance
                                            ? Icons.warning
                                            : Icons.shopping_cart,
                                        size: 20,
                                      ),
                                      label: Text(
                                        exceedsBalance
                                            ? 'Solde insuffisant'
                                            : 'Commander',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: exceedsBalance
                                            ? Colors.grey
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
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
