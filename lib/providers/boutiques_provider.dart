// lib/providers/boutiques_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/boutique.dart';
import '../services/location_service.dart';
import '../utils/constants.dart'; // Pour kBoutiquesCollection

class BoutiquesProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Boutique> _boutiques = [];
  Position? _currentPosition;
  bool _isLoading = true;

  // Accesseurs
  List<Boutique> get boutiques => _boutiques;
  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;

  // Liste triée par distance (Objectif 4 : Calculer distance)
  List<Boutique> get boutiquesSortedByDistance {
    if (_currentPosition == null) {
      // Si la position n'est pas connue, retourne la liste non triée
      return _boutiques;
    }
    // Crée une copie pour éviter de modifier la liste d'origine
    final sortedList = List<Boutique>.from(_boutiques);
    sortedList.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return sortedList;
  }

  BoutiquesProvider() {
    // Lance le chargement des boutiques et tente d'obtenir la position au démarrage
    _loadBoutiquesStream();
    _fetchUserLocation();
  }

  // ------------------------- GESTION DE LA LOCALISATION -------------------------

  // Obtient la position initiale de l'utilisateur (Objectif 2)
  Future<void> _fetchUserLocation() async {
    try {
      final position = await LocationService.getCurrentPosition();
      _currentPosition = position;
      _calculateDistances();
      // Notifier après la position et le calcul de distance
      notifyListeners();
    } catch (e) {
      // Gérer l'exception (ex: permissions refusées)
      if (kDebugMode) {
        print("Erreur de géolocalisation: $e");
      }
      // Nous ne notifions pas l'écouteur si la localisation échoue,
      // car les boutiques peuvent toujours être affichées.
    }
  }

  // Recalcule les distances pour toutes les boutiques
  void _calculateDistances() {
    if (_currentPosition == null) return;

    final userLat = _currentPosition!.latitude;
    final userLng = _currentPosition!.longitude;

    for (var boutique in _boutiques) {
      // Utilise la méthode statique de LocationService
      boutique.distanceKm = LocationService.getDistance(
            userLat,
            userLng,
            boutique.latitude,
            boutique.longitude,
          ) /
          1000; // Conversion de mètres en kilomètres
    }
  }

  // ------------------------- GESTION DE FIREBASE -------------------------

  void _loadBoutiquesStream() {
    _isLoading = true;
    _db
        .collection(
            kBoutiquesCollection) // Assurez-vous que kBoutiquesCollection est défini dans constants.dart
        .snapshots()
        .listen((snapshot) {
      _boutiques =
          snapshot.docs.map((doc) => Boutique.fromFirestore(doc)).toList();

      // Après le chargement des données, mettre à jour les distances
      _calculateDistances();
      _isLoading = false;
      notifyListeners();
    });
  }

  // Permet d'actualiser la position manuellement (ex: bouton actualiser)
  Future<void> refreshLocation() async {
    await _fetchUserLocation();
  }
}
