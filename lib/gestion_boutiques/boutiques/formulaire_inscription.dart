import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gestion_courses/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  runApp(MaterialApp(
    title: 'Création de Boutique',
    theme: ThemeData(
      fontFamily: 'Poppins',
      primaryColor: const Color(0xFF0F9E99), // Tropical Teal
      scaffoldBackgroundColor: const Color(0xFFEFE9E0), // Soft Ivory
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: MaterialColor(0xFF0F9E99, {
          50: Color(0xFFE0F2F1),
          100: Color(0xFFB2DFDB),
          200: Color(0xFF80CBC4),
          300: Color(0xFF4DB6AC),
          400: Color(0xFF26A69A),
          500: Color(0xFF0F9E99),
          600: Color(0xFF00897B),
          700: Color(0xFF00796B),
          800: Color(0xFF00695C),
          900: Color(0xFF004D40),
        }),
      ).copyWith(
        secondary: Color(0xFFEFE9E0), // Soft Ivory
      ),
    ),
    home: CreateBoutiquePage(firestore: FirebaseFirestore.instance),
    debugShowCheckedModeBanner: false,
  ));
}

class CreateBoutiquePage extends StatefulWidget {
  final FirebaseFirestore firestore;
  
  const CreateBoutiquePage({super.key, required this.firestore});

  @override
  State<CreateBoutiquePage> createState() => _CreateBoutiquePageState();
}

class _CreateBoutiquePageState extends State<CreateBoutiquePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  
  String? _selectedCategory;
  
  final List<Map<String, dynamic>> _boutiqueCategories = [
    {'value': 'supermarche', 'label': 'Supermarché', 'icon': Icons.shopping_cart},
    {'value': 'marche', 'label': 'Marché', 'icon': Icons.storefront},
    {'value': 'boutique', 'label': 'Boutique', 'icon': Icons.store},
    {'value': 'restaurant', 'label': 'Restaurant', 'icon': Icons.restaurant},
    {'value': 'pharmacie', 'label': 'Pharmacie', 'icon': Icons.local_pharmacy},
    {'value': 'boulangerie', 'label': 'Boulangerie', 'icon': Icons.bakery_dining},
    {'value': 'epicerie', 'label': 'Épicerie', 'icon': Icons.local_grocery_store},
    {'value': 'boucherie', 'label': 'Boucherie', 'icon': Icons.set_meal},
    {'value': 'primeur', 'label': 'Primeur', 'icon': Icons.grass},
    {'value': 'autre', 'label': 'Autre', 'icon': Icons.more_horiz},
  ];
  
  bool _isSubmitting = false;
  
  @override
  void dispose() {
    _nomController.dispose();
    _adresseController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }
  
  Future<void> _createBoutique() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une catégorie'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final docRef = widget.firestore.collection('boutiques').doc();
      
      await widget.firestore.collection('boutiques').add({
        'id': docRef.id,
        'nom': _nomController.text.trim(),
        'adresse': _adresseController.text.trim(),
        'categories': _selectedCategory!,
        'latitude': double.parse(_latitudeController.text.trim()),
        'longitude': double.parse(_longitudeController.text.trim()),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      // Réinitialiser le formulaire
      _formKey.currentState!.reset();
      _nomController.clear();
      _adresseController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      setState(() {
        _selectedCategory = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Boutique créée avec succès !'),
          backgroundColor: Color(0xFF0F9E99),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Attendre 2 secondes pour que l'utilisateur voie le message
      await Future.delayed(const Duration(seconds: 2));
      
      // Rediriger vers le dashboard
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardPage(),
          ),
        );
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE9E0), // Soft Ivory
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F9E99), // Tropical Teal
        title: const Text(
          'Création de Boutique',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Carte d'information
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F9E99), // Tropical Teal
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.white, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Informations importantes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Remplissez tous les champs pour créer votre boutique. '
                        'Les coordonnées GPS sont importantes pour permettre aux clients de vous localiser.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Formulaire
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informations de la boutique',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Remplissez les informations concernant votre boutique',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Nom de la boutique
                        TextFormField(
                          controller: _nomController,
                          decoration: InputDecoration(
                            labelText: 'Nom de la boutique *',
                            hintText: 'Ex: Supermarché ABC',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.store, color: Color(0xFF0F9E99)),
                            filled: true,
                            fillColor: const Color(0xFFF5F7FA),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le nom est obligatoire';
                            }
                            if (value.length < 3) {
                              return 'Le nom doit contenir au moins 3 caractères';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Adresse
                        TextFormField(
                          controller: _adresseController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Adresse complète *',
                            hintText: 'Ex: 123 Avenue de la République, 75000 Paris',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.location_on, color: Color(0xFF0F9E99)),
                            filled: true,
                            fillColor: const Color(0xFFF5F7FA),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'L\'adresse est obligatoire';
                            }
                            if (value.length < 10) {
                              return 'L\'adresse doit être complète';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Catégorie
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Type de boutique *',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2C3E50),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: const Icon(Icons.category, color: Color(0xFF0F9E99)),
                                filled: true,
                                fillColor: const Color(0xFFF5F7FA),
                              ),
                              hint: const Text('Sélectionnez le type de boutique'),
                              items: _boutiqueCategories.map<DropdownMenuItem<String>>((category) {
                                return DropdownMenuItem<String>(
                                  value: category['value'] as String,
                                  child: Row(
                                    children: [
                                      Icon(
                                        category['icon'] as IconData,
                                        color: const Color(0xFF0F9E99),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(category['label'] as String),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedCategory = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'La catégorie est obligatoire';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 30),
                        
                        const Text(
                          'Coordonnées GPS',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Ces coordonnées permettent aux clients de vous localiser sur la carte',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Coordonnées GPS
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latitudeController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Latitude *',
                                  hintText: 'Ex: 48.8566',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.navigation, color: Color(0xFF0F9E99)),
                                  filled: true,
                                  fillColor: const Color(0xFFF5F7FA),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'La latitude est obligatoire';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Veuillez entrer un nombre valide';
                                  }
                                  final lat = double.parse(value);
                                  if (lat < -90 || lat > 90) {
                                    return 'La latitude doit être entre -90 et 90';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: TextFormField(
                                controller: _longitudeController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Longitude *',
                                  hintText: 'Ex: 2.3522',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.navigation, color: Color(0xFF0F9E99)),
                                  filled: true,
                                  fillColor: const Color(0xFFF5F7FA),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'La longitude est obligatoire';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Veuillez entrer un nombre valide';
                                  }
                                  final long = double.parse(value);
                                  if (long < -180 || long > 180) {
                                    return 'La longitude doit être entre -180 et 180';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // SECTION POUR LES INSTRUCTIONS GPS
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF0F9E99).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.location_searching, color: Color(0xFF0F9E99), size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Comment obtenir les coordonnées GPS ?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 12,
                                  ),
                                  children: [
                                    TextSpan(text: '1. Allez sur '),
                                    TextSpan(
                                      text: 'Google Maps',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(text: '\n2. Cliquez droit sur l\'emplacement de votre boutique\n'),
                                    TextSpan(text: '3. Sélectionnez "Plus d\'infos" ou "Coordonnées"\n'),
                                    TextSpan(text: '4. Copiez les coordonnées\n'),
                                    TextSpan(
                                      text: '   • La ',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(
                                      text: 'première valeur ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F9E99),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'est la latitude (N/S)\n',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(
                                      text: '   • La ',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(
                                      text: 'deuxième valeur ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F9E99),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'est la longitude (E/O)',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: () {
                                  _latitudeController.text = '48.8566';
                                  _longitudeController.text = '2.3522';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Exemple de Paris inséré (48.8566, 2.3522)'),
                                      backgroundColor: Color(0xFF0F9E99),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F9E99),
                                ),
                                icon: const Icon(Icons.map, size: 16),
                                label: const Text('Insérer un exemple'),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Bouton de soumission
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _createBoutique,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F9E99),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add_business, size: 20),
                            label: _isSubmitting
                                ? const Text('Création en cours...')
                                : const Text('Créer la boutique'),
                          ),
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Bouton pour annuler
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0F9E99)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Annuler',
                              style: TextStyle(color: Color(0xFF0F9E99)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dashboard Page simplifiée
class DashboardPage extends StatelessWidget {
  DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE9E0), // Soft Ivory
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F9E99), // Tropical Teal
        title: const Text(
          'Tableau de Bord',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF0F9E99),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Boutique créée avec succès !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 15),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Votre boutique a été enregistrée avec succès. Vous pouvez maintenant gérer vos produits et voir les statistiques.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Retourner à la création d'une autre boutique
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => CreateBoutiquePage(firestore: FirebaseFirestore.instance),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9E99),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Créer une autre boutique'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  // Aller à la liste des boutiques (à implémenter)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Page liste des boutiques à implémenter'),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0F9E99)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Voir mes boutiques',
                  style: TextStyle(color: Color(0xFF0F9E99)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}