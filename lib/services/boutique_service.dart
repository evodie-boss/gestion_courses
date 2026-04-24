import 'package:cloud_firestore/cloud_firestore.dart';

class BoutiqueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Récupérer toutes les boutiques
  Stream<List<dynamic>> get boutiquesStream {
    return _firestore.collection('boutiques').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => doc.data())
          .toList(),
    );
  }
  
  // Trouver les boutiques qui ont certains produits
  Future<List<dynamic>> findBoutiquesWithProducts(List<String> productIds) async {
    final snapshot = await _firestore.collection('boutiques').get();
    
    return snapshot.docs
        .map((doc) => doc.data())
        .toList();
  }
  
  // Calculer le prix total pour une liste de courses dans une boutique
  double calculateTotalForBoutique(List<dynamic> courses, dynamic boutique) {
    return 0.0;
  }
  
  // Créer une commande
  Future<void> createCommande(dynamic commande) async {
    await _firestore.collection('commandes').add({'data': 'commande'});
  }
  
  // Récupérer les commandes d'un utilisateur
  Stream<List<dynamic>> getCommandesStream(String userId) {
    return _firestore
        .collection('commandes')
        .where('userId', isEqualTo: userId)
        .orderBy('dateCommande', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList());
  }
}