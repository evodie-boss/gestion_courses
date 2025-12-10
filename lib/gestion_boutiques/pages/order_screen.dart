import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_courses/models/course_model.dart';

class OrderScreen extends StatefulWidget {
  final List<dynamic> selectedCourses;

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

  double _userBalance = 0;
  bool _isLoadingBalance = true;
  List<Map<String, dynamic>> _availableBoutiques = [];
  bool _isLoadingBoutiques = true;

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
      print('Nombre de cours sélectionnés: ${widget.selectedCourses.length}');

      // 1. Récupérer les noms des cours de façon robuste
      final Set<String> courseNames = {};
      
      for (var course in widget.selectedCourses) {
        String name = '';
        
        if (course is Course) {
          name = course.title.trim();
          print('→ Objet Course trouvé: "$name"');
        } else if (course is Map<String, dynamic>) {
          name = (course['title'] ?? course['nom'] ?? '').toString().trim();
          print('→ Map trouvée: "$name"');
        } else {
          try {
            // Essayer d'accéder par réflexion
            final dynamicTitle = course.title;
            final dynamicName = course.nom;
            name = (dynamicTitle ?? dynamicName ?? '').toString().trim();
            print('→ Autre type: "$name"');
          } catch (e) {
            name = course.toString().trim();
            print('→ Conversion string: "$name"');
          }
        }
        
        if (name.isNotEmpty) {
          courseNames.add(name.toLowerCase());
        }
      }

      print('Noms uniques des cours: $courseNames');

      if (courseNames.isEmpty) {
        print('⚠️ Aucun nom de cours valide à chercher');
        setState(() => _isLoadingBoutiques = false);
        return;
      }

      // 2. Chercher TOUS les produits d'abord
      final productsSnapshot = await _firestore
          .collection('products')
          .get();

      print('Total produits dans Firestore: ${productsSnapshot.docs.length}');

      // 3. Filtrer les produits qui correspondent aux courses
      final Map<String, List<Map<String, dynamic>>> productsByBoutique = {};
      final Set<String> boutiqueIds = {};

      for (var productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        final productName = (productData['nom'] ?? '').toString().toLowerCase();
        final boutiqueId = productData['boutique_id']?.toString();

        if (boutiqueId == null || boutiqueId.isEmpty) {
          continue;
        }

        // Recherche approximative
        bool isMatch = false;
        for (var courseName in courseNames) {
          // Vérifier les correspondances dans les deux sens
          if (productName.contains(courseName) || 
              courseName.contains(productName) ||
              _areSimilar(productName, courseName)) {
            isMatch = true;
            break;
          }
        }

        if (isMatch) {
          boutiqueIds.add(boutiqueId);
          
          if (!productsByBoutique.containsKey(boutiqueId)) {
            productsByBoutique[boutiqueId] = [];
          }
          
          productsByBoutique[boutiqueId]!.add({
            'id': productDoc.id,
            'nom': productData['nom'] ?? 'Produit sans nom',
            'price': (productData['prix'] ?? 0).toDouble(),
            'priority': productData['priority'] ?? 0,
            'description': productData['description'] ?? '',
          });
        }
      }

      print('Boutiques avec produits correspondants: ${boutiqueIds.length}');

      // 4. Récupérer les informations des boutiques
      final List<Map<String, dynamic>> boutiquesList = [];

      for (var boutiqueId in boutiqueIds) {
        try {
          final boutiqueDoc = await _firestore
              .collection('boutiques')
              .doc(boutiqueId)
              .get();

          if (boutiqueDoc.exists) {
            final boutiqueData = boutiqueDoc.data()!;
            final boutiqueProducts = productsByBoutique[boutiqueId] ?? [];
            
            print('✅ Boutique "${boutiqueData['nom']}" : ${boutiqueProducts.length} produit(s)');

            boutiquesList.add({
              'id': boutiqueId,
              'nom': boutiqueData['nom'] ?? 'Boutique sans nom',
              'adresse': boutiqueData['adresse'] ?? '',
              'latitude': boutiqueData['latitude'] ?? 0.0,
              'longitude': boutiqueData['longitude'] ?? 0.0,
              'rating': boutiqueData['rating'] ?? 0.0,
              'products': boutiqueProducts,
            });
          }
        } catch (e) {
          print('❌ Erreur boutique $boutiqueId: $e');
        }
      }

      print('\n=== RÉSULTAT FINAL ===');
      print('Boutiques disponibles: ${boutiquesList.length}');
      for (var boutique in boutiquesList) {
        print('  - ${boutique['nom']} : ${boutique['products'].length} produit(s)');
      }

      setState(() {
        _availableBoutiques = boutiquesList;
        _isLoadingBoutiques = false;
      });

    } catch (e) {
      print('❌ ERREUR CRITIQUE dans _loadAvailableBoutiques: $e');
      setState(() => _isLoadingBoutiques = false);
    }
  }

  // Fonction pour vérifier la similarité entre noms
  bool _areSimilar(String name1, String name2) {
    // Convertir les pluriels en singulier pour comparaison
    final singular1 = _toSingular(name1);
    final singular2 = _toSingular(name2);
    
    return singular1 == singular2 ||
           name1.startsWith(name2) || 
           name2.startsWith(name1);
  }

  // Conversion simplifiée du pluriel au singulier
  String _toSingular(String word) {
    if (word.endsWith('s') && word.length > 1) {
      return word.substring(0, word.length - 1);
    }
    if (word.endsWith('es') && word.length > 2) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('aux') && word.length > 3) {
      return word.substring(0, word.length - 3) + 'al';
    }
    return word;
  }

  double _calculateOrderTotal(Map<String, dynamic> boutique) {
    double total = 0;
    for (var product in boutique['products'] as List) {
      double price = (product['price'] as num).toDouble();
      int priority = product['priority'] as int? ?? 0;

      // Ajuster le prix selon la priorité
      if (priority == 1) {
        price *= 0.9; // -10% pour priorité haute
      } else if (priority == 2) {
        price *= 0.95; // -5% pour priorité moyenne
      }
      total += price;
    }
    return total;
  }

  void _placeOrder(Map<String, dynamic> boutique) async {
    final total = _calculateOrderTotal(boutique);

    // Vérifier les alertes
    List<String> alerts = [];

    if (total > _userBalance) {
      alerts.add(
        '⚠️ Solde insuffisant ! Vous avez ${_userBalance.toStringAsFixed(0)} FCFA',
      );
    }

    if (_userBalance - total < 5000) {
      alerts.add('⚠️ Votre solde sera faible après cette commande');
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
        title: const Text('⚠️ Alertes'),
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
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _confirmAndPlaceOrder(
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

      // Créer la commande
      final orderRef = await _firestore.collection('orders').add({
        'userId': userId,
        'boutiqueId': boutique['id'],
        'boutiqueName': boutique['nom'],
        'boutiqueAddress': boutique['adresse'],
        'items': boutique['products'],
        'itemsCount': (boutique['products'] as List).length,
        'subtotal': boutique['products'].fold<double>(
          0,
          (sum, p) => sum + ((p['price'] as num).toDouble()),
        ),
        'deliveryFee': 0,
        'total': total,
        'deliveryType': 'pickup',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Débiter le solde
      await _firestore.collection('portefeuille').doc(userId).update({
        'balance': FieldValue.increment(-total),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Mettre à jour le solde local
      setState(() {
        _userBalance -= total;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Commande #${orderRef.id.substring(0, 8)} placée ! ${total.toStringAsFixed(0)} FCFA débités',
          ),
          backgroundColor: successColor,
          duration: const Duration(seconds: 3),
        ),
      );

      // Retourner à l'écran précédent
      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélectionner une boutique'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingBoutiques || _isLoadingBalance
          ? const Center(child: CircularProgressIndicator())
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
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aucun produit correspondant à vos courses',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                    child: const Text('Retour'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Affichage du solde
                Container(
                  padding: const EdgeInsets.all(16),
                  color: backgroundColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Votre solde',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${_userBalance.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (_userBalance < 10000)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: warningColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Solde faible',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Nombre de boutiques trouvées
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: primaryColor.withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(Icons.store, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        '${_availableBoutiques.length} boutique(s) trouvée(s)',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
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
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final boutique = _availableBoutiques[index];
                      final total = _calculateOrderTotal(boutique);
                      final exceedsBalance = total > _userBalance;

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // En-tête boutique
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          boutique['nom'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          boutique['adresse'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
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
                                        '${(boutique['rating'] as num?)?.toStringAsFixed(1) ?? '5.0'}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Produits correspondants
                              Text(
                                'Produits correspondants:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              ...((boutique['products'] as List).map((product) {
                                double price = (product['price'] as num).toDouble();
                                int priority = product['priority'] as int? ?? 0;
                                double adjustedPrice = price;

                                if (priority == 1) {
                                  adjustedPrice *= 0.9;
                                } else if (priority == 2) {
                                  adjustedPrice *= 0.95;
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product['nom'],
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (product['description'] != null && 
                                                (product['description'] as String).isNotEmpty)
                                              Text(
                                                product['description'],
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            if (priority > 0)
                                              Text(
                                                priority == 1
                                                    ? '🔴 Haute priorité (-10%)'
                                                    : '🟡 Priorité normale (-5%)',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (adjustedPrice != price)
                                            Text(
                                              '${price.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                          Text(
                                            '${adjustedPrice.toStringAsFixed(0)} FCFA',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList()),
                              
                              const Divider(height: 16),
                              
                              // Total et bouton
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '${total.toStringAsFixed(0)} FCFA',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: exceedsBalance
                                              ? errorColor
                                              : primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton(
                                    onPressed: exceedsBalance
                                        ? null
                                        : () => _placeOrder(boutique),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: exceedsBalance
                                          ? Colors.grey
                                          : primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      exceedsBalance
                                          ? 'Solde insuffisant'
                                          : 'Commander',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
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