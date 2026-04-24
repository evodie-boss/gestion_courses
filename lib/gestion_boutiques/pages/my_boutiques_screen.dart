// lib/gestion_boutiques/pages/my_boutiques_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gestion_courses/constants/app_colors.dart';
// En haut du fichier, ajoutez cet import :
import 'package:gestion_courses/gestion_boutiques/boutiques/formulaire_inscription.dart';
import 'package:gestion_courses/gestion_boutiques/boutiques/dashboard.dart'; // Tableau de bord individuel

class MyBoutiquesScreen extends StatelessWidget {
  const MyBoutiquesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Boutiques'),
        backgroundColor: AppColors.tropicalTeal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('boutiques')
            .where('createdBy', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.tropicalTeal),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_mall_directory_outlined,
                    size: 80,
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
            );
          }

          final boutiques = snapshot.data!.docs;

          // Trier localement côté client
          boutiques.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aNom = (aData['nom'] ?? '').toLowerCase();
            final bNom = (bData['nom'] ?? '').toLowerCase();
            return aNom.compareTo(bNom);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: boutiques.length,
            itemBuilder: (context, index) {
              final boutique = boutiques[index];
              final data = boutique.data() as Map<String, dynamic>;

              // Lire le solde en temps réel
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('boutiques')
                    .doc(boutique.id)
                    .snapshots(),
                builder: (context, boutiqueSnapshot) {
                  if (!boutiqueSnapshot.hasData) {
                    return _buildBoutiqueCard(
                      context,
                      boutique.id,
                      data,
                      0.0, // Valeur par défaut
                    );
                  }

                  final boutiqueData = boutiqueSnapshot.data!.data() as Map<String, dynamic>?;
                  final balance = (boutiqueData?['balance'] ?? 0.0).toDouble();
                  
                  return _buildBoutiqueCard(
                    context,
                    boutique.id,
                    data,
                    balance,
                  );
                },
              );
            },
          );
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

  Widget _buildBoutiqueCard(
    BuildContext context,
    String boutiqueId,
    Map<String, dynamic> data,
    double balance,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Aller au tableau de bord ADMIN pour CETTE boutique
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['nom'] ?? 'Boutique sans nom',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['categories'] ?? 'Général',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                data['adresse'] ?? 'Adresse non définie',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 8),
              
              // AFFICHAGE DU SOLDE DE LA BOUTIQUE
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tropicalTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
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
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Solde disponible:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${balance.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.tropicalTeal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(
                    Icons.shopping_cart,
                    'Commandes',
                    '0', // À remplacer par le vrai nombre
                    context,
                  ),
                  _buildStatItem(
                    Icons.attach_money,
                    'CA du mois',
                    '0 FCFA', // À remplacer par le vrai montant
                    context,
                  ),
                  _buildStatItem(
                    Icons.star,
                    'Évaluation',
                    '4.5', // À remplacer par la vraie note
                    context,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    BuildContext context,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.tropicalTeal),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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

      // Navigation vers votre formulaire d'inscription existant
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

// Dialogue de création de boutique
class CreateBoutiqueDialog extends StatefulWidget {
  const CreateBoutiqueDialog({Key? key}) : super(key: key);

  @override
  State<CreateBoutiqueDialog> createState() => _CreateBoutiqueDialogState();
}

class _CreateBoutiqueDialogState extends State<CreateBoutiqueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _adresseController = TextEditingController();
  final _categorieController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer une nouvelle boutique'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la boutique*',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le nom est obligatoire';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adresseController,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categorieController,
                decoration: const InputDecoration(
                  labelText: 'Catégorie (ex: Épicerie, Vêtements)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // Permet de retourner à la page précédente
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'nom': _nomController.text,
                'adresse': _adresseController.text,
                'categorie': _categorieController.text,
                'phone': _phoneController.text,
                'email': _emailController.text,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.tropicalTeal,
          ),
          child: const Text('Créer'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _adresseController.dispose();
    _categorieController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}