import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderScreen extends StatefulWidget {
  final List<dynamic> selectedCourses;

  const OrderScreen({Key? key, required this.selectedCourses}) : super(key: key);

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
        final doc = await _firestore.collection('portefeuille').doc(userId).get();
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
      // Récupérer tous les produits des courses sélectionnées
      final courseNames = widget.selectedCourses
          .map((c) => c.nom?.toString() ?? '')
          .where((nom) => nom.isNotEmpty)
          .toSet();

      if (courseNames.isEmpty) {
        setState(() => _isLoadingBoutiques = false);
        return;
      }

      // Chercher les boutiques qui ont ces produits
      final boutiques = await _firestore.collection('boutiques').get();
      final Map<String, Map<String, dynamic>> boutiqueMap = {};

      for (var boutique in boutiques.docs) {
        final products = await _firestore
            .collection('boutiques')
            .doc(boutique.id)
            .collection('products')
            .get();

        List<Map<String, dynamic>> productsFound = [];
        for (var product in products.docs) {
          final productName = product.data()['nom'] as String? ?? '';
          if (courseNames.contains(productName)) {
            productsFound.add({
              'id': product.id,
              'nom': productName,
              'price': (product.data()['price'] ?? 0).toDouble(),
              'priority': product.data()['priority'] ?? 0,
            });
          }
        }

        if (productsFound.isNotEmpty) {
          boutiqueMap[boutique.id] = {
            'id': boutique.id,
            'nom': boutique.data()['nom'] ?? 'Boutique',
            'adresse': boutique.data()['adresse'] ?? '',
            'products': productsFound,
          };
        }
      }

      setState(() {
        _availableBoutiques = boutiqueMap.values.toList();
        _isLoadingBoutiques = false;
      });
    } catch (e) {
      print('Erreur chargement boutiques: $e');
      setState(() => _isLoadingBoutiques = false);
    }
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
      alerts.add('⚠️ Solde insuffisant ! Vous avez ${_userBalance.toStringAsFixed(0)} FCFA');
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

  void _showAlertDialog(BuildContext context, List<String> alerts, 
      Map<String, dynamic> boutique, double total) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Alertes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...alerts.map((alert) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(alert, style: const TextStyle(fontSize: 14)),
            )),
            const SizedBox(height: 16),
            Text(
              'Solde actuel: ${_userBalance.toStringAsFixed(0)} FCFA',
              style: const TextStyle(fontWeight: FontWeight.bold, color: warningColor),
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

  void _confirmAndPlaceOrder(Map<String, dynamic> boutique, double total) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Créer la commande
      await _firestore.collection('orders').add({
        'userId': userId,
        'boutiqueId': boutique['id'],
        'boutiqueName': boutique['nom'],
        'items': boutique['products'],
        'subtotal': boutique['products'].fold<double>(
          0,
          (sum, p) => sum + ((p['price'] as num).toDouble()),
        ),
        'deliveryFee': 0,
        'total': total,
        'deliveryType': 'pickup',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Débiter le solde
      await _firestore.collection('portefeuille').doc(userId).update({
        'balance': FieldValue.increment(-total),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande placée ! ${total.toStringAsFixed(0)} FCFA débités'),
          backgroundColor: successColor,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: errorColor),
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
                      Icon(Icons.store_mall_directory_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('Aucune boutique disponible',
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
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
                              const Text('Votre solde',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                '${_userBalance.toStringAsFixed(0)} FCFA',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (_userBalance < 10000)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: warningColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_rounded,
                                      size: 16, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Solde faible',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ],
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            boutique['nom'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            boutique['adresse'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.star,
                                              size: 16,
                                              color: Colors.amber),
                                          const SizedBox(width: 4),
                                          
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Produits
                                  ...((boutique['products'] as List)
                                      .map((product) {
                                    double price = (product['price'] as num)
                                        .toDouble();
                                    int priority =
                                        product['priority'] as int? ?? 0;
                                    double adjustedPrice = price;

                                    if (priority == 1) {
                                      adjustedPrice *= 0.9;
                                    } else if (priority == 2) {
                                      adjustedPrice *= 0.95;
                                    }

                                    return Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product['nom'],
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (adjustedPrice != price)
                                                Text(
                                                  '${price.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                    decoration:
                                                        TextDecoration.lineThrough,
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                          backgroundColor:
                                              exceedsBalance ? Colors.grey : primaryColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          exceedsBalance
                                              ? 'Solde faible'
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