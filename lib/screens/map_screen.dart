import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as FM;
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async'; // Ajout de l'import pour TimeoutException
import 'package:gestion_courses/constants/app_colors.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final FM.MapController _mapController;
  List<FM.Marker> _fmMarkers = [];
  LatLng _userLocation = LatLng(48.8566, 2.3522);
  List<Map<String, dynamic>> _shops = [];
  bool _isLoadingShops = true;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _mapController = FM.MapController();
    _initializeData();
  }
  
  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      await Future.wait([
        _getUserLocation(),
        _loadShopsFromFirebase(),
      ]);
    } catch (e) {
      print('Erreur initialisation: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _isLoadingShops = false;
        });
      }
    }
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La localisation est désactivée. Activez-la dans les paramètres.',
              ),
            ),
          );
        }
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        if (mounted) {
          setState(() {
            _userLocation = LatLng(position.latitude, position.longitude);
            _isLoadingLocation = false;
          });
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              _mapController.move(_userLocation, 14);
            } catch (_) {}
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
        }
      }
    } catch (e) {
      print('Erreur localisation: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _loadShopsFromFirebase() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('boutiques')
          .get()
          .timeout(const Duration(seconds: 10));

      List<Map<String, dynamic>> boutiques = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          boutiques.add({
            'id': doc.id,
            'name': data['nom'] ?? 'Boutique',
            'adresse': data['adresse'] ?? 'Localisation inconnue',
            'latitude': lat,
            'longitude': lng,
            'rating': (data['rating'] as num?)?.toDouble() ?? 4.0,
            'distance': data['distance'] as num? ?? 0,
          });
        }
      }

      if (mounted) {
        setState(() {
          _shops = boutiques;
          _isLoadingShops = false;
        });
        
        _addMarkersToMap();
      }
    } on TimeoutException catch (_) { // Correction: TimeoutException est maintenant disponible
      if (mounted) {
        setState(() => _isLoadingShops = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timeout lors du chargement des boutiques')),
        );
      }
    } catch (e) {
      print('Erreur chargement boutiques: $e');
      if (mounted) {
        setState(() => _isLoadingShops = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  void _addMarkersToMap() {
    if (_shops.isEmpty) return;

    final markers = <FM.Marker>[];

    // Marker pour la localisation de l'utilisateur
    markers.add(
      FM.Marker(
        width: 40,
        height: 40,
        point: _userLocation,
        child: GestureDetector(
          onTap: () {
            try {
              _mapController.move(_userLocation, 14);
            } catch (_) {}
          },
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 28,
          ),
        ),
      ),
    );

    // Markers pour chaque boutique
    for (var shop in _shops) {
      final point = LatLng(shop['latitude'], shop['longitude']);
      markers.add(
        FM.Marker(
          width: 40,
          height: 40,
          point: point,
          child: GestureDetector(
            onTap: () => _showShopDetails(shop),
            child: const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 36,
            ),
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _fmMarkers = markers;
      });
    }
  }

  void _showShopDetails(Map<String, dynamic> shop) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop['name'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${shop['rating']}/5',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Localisation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softIvory,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: AppColors.tropicalTeal, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Adresse',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            shop['adresse'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Coordonnées GPS
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softIvory,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed,
                        color: AppColors.tropicalTeal, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coordonnées GPS',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '${shop['latitude'].toStringAsFixed(4)}, ${shop['longitude'].toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openInGoogleMaps(shop),
                      icon: const Icon(Icons.directions),
                      label: const Text('Itinéraire'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tropicalTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _centerMapOnShop(shop);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Sur carte'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[400],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _centerMapOnShop(Map<String, dynamic> shop) {
    final lat = shop['latitude'];
    final lng = shop['longitude'];
    if (lat != null && lng != null) {
      try {
        _mapController.move(LatLng(lat, lng), 15);
      } catch (_) {}
    }
  }

  Future<void> _openInGoogleMaps(Map<String, dynamic> shop) async {
    final destinationLat = shop['latitude'];
    final destinationLng = shop['longitude'];
    
    final url =
        'https://www.google.com/maps/dir/?api=1&origin=${_userLocation.latitude},${_userLocation.longitude}&destination=$destinationLat,$destinationLng&travelmode=driving';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir Google Maps.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des Boutiques'),
        backgroundColor: AppColors.tropicalTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_shops.length} boutique(s)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoadingLocation || _isLoadingShops
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement de la carte...'),
                ],
              ),
            )
          : Stack(
              children: [
                FM.FlutterMap(
                  mapController: _mapController,
                  options: FM.MapOptions(
                    initialCenter: _userLocation, 
                    initialZoom: 14,          
                    maxZoom: 18,
                  ),
                  children: [
                    FM.TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.app',
                    ),
                    FM.MarkerLayer(markers: _fmMarkers),
                  ],
                ),

                // Bouton liste des boutiques en bas
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: _shops.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Aucune boutique trouvée',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () => _showShopsList(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tropicalTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.list),
                              const SizedBox(width: 8),
                              Text(
                                'Liste des ${_shops.length} boutiques',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  void _showShopsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Boutiques Disponibles',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _shops.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final shop = _shops[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.store,
                          color: AppColors.tropicalTeal,
                          size: 28,
                        ),
                        title: Text(
                          shop['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(shop['adresse']),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text('${shop['rating']}'),
                          ],
                        ),
                        onTap: () {
                          _centerMapOnShop(shop);
                          Navigator.pop(context);
                          _showShopDetails(shop);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}