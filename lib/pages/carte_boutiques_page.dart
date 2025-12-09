// lib/pages/carte_boutiques_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart'; // Pour l'itinéraire
import '../providers/boutiques_provider.dart';
import '../models/boutique.dart';
import '../utils/constants.dart'; // Pour les couleurs

class CarteBoutiquesPage extends StatefulWidget {
  const CarteBoutiquesPage({super.key});

  @override
  State<CarteBoutiquesPage> createState() => _CarteBoutiquesPageState();
}

class _CarteBoutiquesPageState extends State<CarteBoutiquesPage> {
  final Completer<GoogleMapController> _controller = Completer();

  // État de la carte
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Boutique? _destinationBoutique; // Boutique sélectionnée comme destination
  String _mapType = 'normal'; // Type de carte (normal, satellite, etc.)

  // Position par défaut (si la géolocalisation échoue ou est en attente)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(6.3646, 2.40833), // Coordonnées de Dantokpa (votre exemple)
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    // Tente de récupérer la position de l'utilisateur (déjà géré dans le Provider, mais on force ici)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BoutiquesProvider>(context, listen: false).refreshLocation();
    });
  }

  // Méthode pour créer les marqueurs des boutiques (Objectif 3)
  void _setMarkers(List<Boutique> boutiques) {
    _markers.clear();

    // 1. Ajouter les marqueurs des boutiques
    for (var boutique in boutiques) {
      final marker = Marker(
        markerId: MarkerId(boutique.id),
        position: LatLng(boutique.latitude, boutique.longitude),
        infoWindow: InfoWindow(
          title: boutique.nom,
          snippet: 'Distance: ${boutique.distanceKm.toStringAsFixed(1)} km',
          onTap: () {
            // Logique lorsque l'utilisateur clique sur le marqueur
            _selectDestination(boutique);
          },
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueCyan), // Couleur Cool Teal/Cyan
      );
      _markers.add(marker);
    }

    // 2. Si la position de l'utilisateur est connue, centrer la carte
    final provider = Provider.of<BoutiquesProvider>(context, listen: false);
    if (provider.currentPosition != null) {
      _centerMapOnUser(provider.currentPosition!);
    }

    // Mettre à jour l'UI
    setState(() {});
  }

  // Centre la carte sur une position donnée
  Future<void> _centerMapOnUser(Position position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15.0,
        ),
      ),
    );
  }

  // ------------------------- LOGIQUE D'ITINÉRAIRE (Objectif 4) -------------------------

  // Déclenchée lors du clic sur le marqueur ou via le panneau de contrôle
  void _selectDestination(Boutique boutique) {
    setState(() {
      _destinationBoutique = boutique;
      _polylines.clear(); // Efface l'ancien tracé
    });

    final currentPosition =
        Provider.of<BoutiquesProvider>(context, listen: false).currentPosition;

    if (currentPosition != null) {
      _getPolyline(currentPosition, boutique);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Impossible d\'obtenir votre position actuelle.')),
      );
    }
  }

  // Trace l'itinéraire entre l'utilisateur et la destination (Utilise flutter_polyline_points)
  Future<void> _getPolyline(Position start, Boutique end) async {
    PolylinePoints polylinePoints = PolylinePoints();

    // NOTE: Pour que cette requête fonctionne, vous devez configurer la VARIABLE D'ENVIRONNEMENT
    // qui contient votre CLÉ API Google Maps.
    // L'API Directions doit être activée dans votre console Google Cloud.

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY'), // CLE API ICI!
      PointLatLng(start.latitude, start.longitude),
      PointLatLng(end.latitude, end.longitude),
      travelMode: TravelMode.driving,
    );

    if (result.points.isNotEmpty) {
      List<LatLng> polylineCoordinates = result.points.map((point) {
        return LatLng(point.latitude, point.longitude);
      }).toList();

      setState(() {
        final Polyline polyline = Polyline(
          polylineId: const PolylineId('route'),
          color: kPrimaryColor, // Cool Teal pour l'itinéraire
          points: polylineCoordinates,
          width: 5,
        );
        _polylines.add(polyline);
      });
    } else {
      if (kDebugMode) {
        print(result.errorMessage);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de tracer l\'itinéraire.')),
      );
    }
  }

  // ------------------------- CONSTRUCTION DE L'UI -------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boutiques sur la Carte'),
        backgroundColor: kPrimaryColor,
        // Ajout d'une action pour la recherche (Objectif: Recherche)
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implémenter la logique de recherche
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Fonctionnalité de recherche à implémenter.')),
              );
            },
          ),
        ],
      ),
      body: Consumer<BoutiquesProvider>(
        builder: (context, provider, child) {
          // Mettre à jour les marqueurs à chaque changement dans le provider
          if (provider.boutiques.isNotEmpty) {
            _setMarkers(provider.boutiques);
          }

          return Stack(
            children: [
              // 1. Google Map (Objectifs 1, 2, 3)
              GoogleMap(
                mapType: MapType.values.firstWhere(
                  (e) => e.toString().split('.').last == _mapType,
                  orElse: () => MapType.normal,
                ),
                initialCameraPosition: _initialCameraPosition,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
                myLocationEnabled:
                    provider.currentPosition != null, // Objectif 2
                myLocationButtonEnabled: true,
                markers: _markers,
                polylines: _polylines,
              ),

              // 2. Affichage d'un indicateur de chargement
              if (provider.isLoading && provider.boutiques.isEmpty)
                const Center(child: CircularProgressIndicator()),

              // 3. Panneau de Contrôle/Sélection de Destination (Inspiration du design fourni)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildControlPanel(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControlPanel(BoutiquesProvider provider) {
    final destinationName =
        _destinationBoutique?.nom ?? 'Sélectionnez une destination';
    final distance = _destinationBoutique != null
        ? 'Distance: ${_destinationBoutique!.distanceKm.toStringAsFixed(1)} km'
        : '';

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kBackgroundColor, // Ivory White
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Définir les adresses de départ et destination',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          // Adresse de départ (Ma position actuelle)
          _buildAddressField(
            icon: Icons.my_location,
            label: 'Adresse de départ',
            value: 'Ma position actuelle',
            color: kPrimaryColor,
          ),
          const SizedBox(height: 10),

          // Adresse de destination (Boutique sélectionnée)
          _buildAddressField(
            icon: Icons.location_on,
            label: 'Adresse de destination',
            value: destinationName,
            color: kErrorColor, // Couleur d'accent pour la destination
            trailing: distance.isNotEmpty ? Text(distance) : null,
          ),

          const SizedBox(height: 20),

          // Bouton d'action (exemple: "Aller à la boutique")
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor, // Cool Teal
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _destinationBoutique == null
                  ? null
                  : () {
                      // Relance le tracé d'itinéraire si la destination est définie
                      _selectDestination(_destinationBoutique!);
                    },
              child: Text(
                _destinationBoutique == null
                    ? 'Sélectionnez une boutique'
                    : 'Afficher l\'itinéraire pour ${_destinationBoutique!.nom}',
                style: const TextStyle(color: kBackgroundColor, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressField({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
