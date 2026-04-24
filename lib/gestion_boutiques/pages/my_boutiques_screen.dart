// lib/gestion_boutiques/pages/my_boutiques_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gestion_courses/constants/app_colors.dart';
import 'package:gestion_courses/gestion_boutiques/boutiques/formulaire_inscription.dart';
import 'package:gestion_courses/gestion_boutiques/boutiques/dashboard.dart';

class MyBoutiquesScreen extends StatelessWidget {
  const MyBoutiquesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mes Boutiques'),
          backgroundColor: AppColors.tropicalTeal,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: MediaQuery.of(context).size.width * 0.2,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Connexion requise',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Veuillez vous connecter pour voir vos boutiques',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Boutiques'),
        backgroundColor: AppColors.tropicalTeal,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('boutiques')
            .where('ownerId', isEqualTo: userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.tropicalTeal),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Erreur: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final myBoutiques = snapshot.data!.docs;

          if (myBoutiques.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.store_mall_directory_outlined,
                      size: MediaQuery.of(context).size.width * 0.2,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Vous n\'avez pas encore créé de boutique',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Créez votre première boutique pour commencer',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _createNewBoutique(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tropicalTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Créer ma première boutique'),
                    ),
                  ],
                ),
              ),
            );
          }

          myBoutiques.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aNom = (aData['nom'] ?? '').toLowerCase();
            final bNom = (bData['nom'] ?? '').toLowerCase();
            return aNom.compareTo(bNom);
          });

          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth >= 600;
          final isDesktop = screenWidth >= 1200;

          if (isDesktop) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.9, // Changé de 0.8 à 0.9 pour plus de hauteur
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: myBoutiques.length,
                itemBuilder: (context, index) {
                  final boutique = myBoutiques[index];
                  final data = boutique.data() as Map<String, dynamic>;
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('boutiques')
                        .doc(boutique.id)
                        .snapshots(),
                    builder: (context, boutiqueSnapshot) {
                      if (!boutiqueSnapshot.hasData) {
                        return _buildBoutiqueCardDesktop(
                          context,
                          boutique.id,
                          data,
                          0.0,
                        );
                      }
                      final boutiqueData = boutiqueSnapshot.data!.data() as Map<String, dynamic>?;
                      final balance = (boutiqueData?['balance'] ?? 0.0).toDouble();
                      return _buildBoutiqueCardDesktop(
                        context,
                        boutique.id,
                        data,
                        balance,
                      );
                    },
                  );
                },
              ),
            );
          } else if (isTablet) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85, // Changé de 0.75 à 0.85
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: myBoutiques.length,
                itemBuilder: (context, index) {
                  final boutique = myBoutiques[index];
                  final data = boutique.data() as Map<String, dynamic>;
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('boutiques')
                        .doc(boutique.id)
                        .snapshots(),
                    builder: (context, boutiqueSnapshot) {
                      if (!boutiqueSnapshot.hasData) {
                        return _buildBoutiqueCardTablet(
                          context,
                          boutique.id,
                          data,
                          0.0,
                        );
                      }
                      final boutiqueData = boutiqueSnapshot.data!.data() as Map<String, dynamic>?;
                      final balance = (boutiqueData?['balance'] ?? 0.0).toDouble();
                      return _buildBoutiqueCardTablet(
                        context,
                        boutique.id,
                        data,
                        balance,
                      );
                    },
                  );
                },
              ),
            );
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: myBoutiques.length,
              itemBuilder: (context, index) {
                final boutique = myBoutiques[index];
                final data = boutique.data() as Map<String, dynamic>;
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('boutiques')
                      .doc(boutique.id)
                      .snapshots(),
                  builder: (context, boutiqueSnapshot) {
                    if (!boutiqueSnapshot.hasData) {
                      return _buildBoutiqueCardMobile(
                        context,
                        boutique.id,
                        data,
                        0.0,
                      );
                    }
                    final boutiqueData = boutiqueSnapshot.data!.data() as Map<String, dynamic>?;
                    final balance = (boutiqueData?['balance'] ?? 0.0).toDouble();
                    return _buildBoutiqueCardMobile(
                      context,
                      boutique.id,
                      data,
                      balance,
                    );
                  },
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewBoutique(context),
        backgroundColor: AppColors.tropicalTeal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_business),
      ),
    );
  }

  // Version mobile (liste) - Aucun changement nécessaire, ça fonctionne bien
  Widget _buildBoutiqueCardMobile(
    BuildContext context,
    String boutiqueId,
    Map<String, dynamic> data,
    double balance,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDashboard(
                boutiqueId: boutiqueId,
                boutiqueName: data['nom'] ?? 'Boutique',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Important pour éviter l'overflow
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.tropicalTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.storefront,
                      size: 24,
                      color: AppColors.tropicalTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['nom'] ?? 'Boutique sans nom',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data['categories'] ?? 'Général',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      data['adresse'] ?? 'Adresse non définie',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.tropicalTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.tropicalTeal.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: AppColors.tropicalTeal,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Solde:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${balance.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.tropicalTeal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItemMobile(Icons.shopping_cart, '0'),
                  _buildStatItemMobile(Icons.attach_money, '0 FCFA'),
                  _buildStatItemMobile(Icons.star, '4.5'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItemMobile(IconData icon, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.tropicalTeal),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  // Version tablette corrigée - Plus de Expanded problématique
  Widget _buildBoutiqueCardTablet(
    BuildContext context,
    String boutiqueId,
    Map<String, dynamic> data,
    double balance,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDashboard(
                boutiqueId: boutiqueId,
                boutiqueName: data['nom'] ?? 'Boutique',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Évite l'overflow
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo centré
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.tropicalTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.storefront,
                    size: 30,
                    color: AppColors.tropicalTeal,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data['nom'] ?? 'Boutique sans nom',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                data['categories'] ?? 'Général',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      data['adresse'] ?? 'Adresse non définie',
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.tropicalTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.tropicalTeal.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Solde',
                      style: TextStyle(fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${balance.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.tropicalTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Version desktop corrigée - Plus de Spacer() problématique
  Widget _buildBoutiqueCardDesktop(
    BuildContext context,
    String boutiqueId,
    Map<String, dynamic> data,
    double balance,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDashboard(
                boutiqueId: boutiqueId,
                boutiqueName: data['nom'] ?? 'Boutique',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min, // CRUCIAL pour éviter l'overflow
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.tropicalTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.storefront,
                      size: 25,
                      color: AppColors.tropicalTeal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['nom'] ?? 'Boutique sans nom',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          data['categories'] ?? 'Général',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      data['adresse'] ?? 'Adresse non définie',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.tropicalTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.tropicalTeal.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Solde:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${balance.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.tropicalTeal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItemDesktop(Icons.shopping_cart, '0'),
                  _buildStatItemDesktop(Icons.attach_money, '0 FCFA'),
                  _buildStatItemDesktop(Icons.star, '4.5'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItemDesktop(IconData icon, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.tropicalTeal),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  void _createNewBoutique(BuildContext context) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez vous connecter pour créer une boutique'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBoutiquePage(
            firestore: FirebaseFirestore.instance,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
}