import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_courses/gestion_boutiques/pages/boutique_detail.dart';
import 'package:gestion_courses/constants/app_colors.dart';

class ElegantBoutiquePage extends StatelessWidget {
  const ElegantBoutiquePage({super.key});

  void _createNewBoutique(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer une boutique'),
        content: const Text('Cette fonctionnalité sera bientôt disponible ici !'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Permet de retourner à la page précédente
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Boutiques',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.tropicalTeal,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('boutiques')
            .orderBy('nom')
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
                    'Aucune boutique disponible',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Soyez le premier à créer une boutique !',
                    style: TextStyle(color: Colors.grey),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Créer une boutique'),
                  ),
                ],
              ),
            );
          }

          final boutiques = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: boutiques.length,
            itemBuilder: (context, index) {
              final boutique = boutiques[index];
              final data = boutique.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BoutiqueDetailScreen(
                          boutiqueId: boutique.id,
                          boutiqueName:
                              data['nom'] ??
                              'Boutique', // <-- AJOUTEZ CE PARAMÈTRE
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  splashColor: AppColors.tropicalTeal.withOpacity(0.1),
                  highlightColor: AppColors.tropicalTeal.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.softIvory,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            size: 40,
                            color: AppColors.tropicalTeal,
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['nom'] ?? 'Boutique',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Icon(
                                    Icons.category,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      data['categories'] ?? 'Général',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Icon(Icons.chevron_right, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewBoutique(context),
        backgroundColor: AppColors.tropicalTeal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
      ),
    );
  }
}
