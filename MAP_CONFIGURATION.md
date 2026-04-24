# Configuration Google Maps pour gestion_courses

## 🗺️ Écran de Carte Implémenté

### Fonctionnalités :
✅ **Affichage interactif des boutiques** sur Google Maps
✅ **Localisation de l'utilisateur** (position actuelle)
✅ **Marqueurs colorés** : 
   - 🔵 Position de l'utilisateur (bleu)
   - 🟢 Boutiques (vert)
✅ **Informations boutique** : nom, adresse, notation, coordonnées GPS
✅ **Bouton "Itinéraire"** : ouverture Google Maps navigation
✅ **Bouton "Sur carte"** : centrage sur la boutique sélectionnée
✅ **Liste des boutiques** : affichage scrollable de toutes les boutiques
✅ **Chargement depuis Firestore** : les coordonnées GPS de la base de données

---

## 📱 Configuration Requise

### 1. **Android (AndroidManifest.xml)**

Ajouter dans `android/app/src/main/AndroidManifest.xml` :

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Permissions pour la localisation -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.INTERNET" />
    
    <application>
        <!-- Clé API Google Maps -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="VOTRE_CLÉ_API_GOOGLE_MAPS" />
            
        <!-- Autres éléments de configuration -->
    </application>
</manifest>
```

### 2. **iOS (Info.plist)**

Ajouter dans `ios/Runner/Info.plist` :

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Cette application a besoin d'accéder à votre localisation pour afficher les boutiques proches.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Cette application a besoin d'accéder à votre localisation.</string>
<key>io.flutter.embedded_views_preview</key>
<true/>
```

Et configurer dans `ios/Runner/GeneratedPluginRegistrant.swift` si nécessaire.

---

## 🔑 Obtenir une Clé API Google Maps

1. **Aller à Google Cloud Console** : https://console.cloud.google.com
2. **Créer un nouveau projet** ou sélectionner un existant
3. **Activer l'API Google Maps** :
   - Aller à "APIs et services" → "Bibliothèque"
   - Chercher "Maps SDK for Android"
   - Cliquer sur "Activer"
4. **Créer une clé API** :
   - Aller à "Identifiants"
   - Cliquer sur "Créer des identifiants" → "Clé API"
   - Sélectionner "Clé API Android"
   - Ajouter les empreintes digitales SHA-1 (obtenir avec `flutter run`)
5. **Copier la clé API** et la placer dans `AndroidManifest.xml`

---

## 📍 Structure de Données Firestore - Collection `boutiques`

```json
{
  "name": "Supermarché Proxi",
  "location": "123 Rue de la Paix, Paris",
  "latitude": 48.8566,
  "longitude": 2.3522,
  "rating": 4.5,
  "distance": 0.5,
  "ownerId": "user_id_123",
  "createdAt": "2025-12-10T15:30:00Z"
}
```

**Champs importants** :
- `latitude` et `longitude` : **OBLIGATOIRES** pour afficher sur la carte
- `name` : Nom de la boutique
- `location` : Adresse complète
- `rating` : Note (1-5 étoiles)

---

## 🛠️ Utilisation

### Pour afficher les boutiques sur la carte :
1. Chaque boutique DOIT avoir `latitude` et `longitude` dans Firestore
2. La carte charge automatiquement les boutiques au démarrage
3. Cliquer sur un marqueur affiche les détails
4. Bouton "Itinéraire" ouvre Google Maps avec navigation

### Créer une boutique avec coordonnées GPS :
1. Cliquer sur "Créer une Boutique" depuis l'accueil
2. Remplir :
   - Nom de la boutique
   - Adresse/Localisation
   - **Latitude** (ex: 48.8566)
   - **Longitude** (ex: 2.3522)
3. Les coordonnées sont validées :
   - Latitude : -90 à 90
   - Longitude : -180 à 180

---

## 🔒 Permissions Requises (iOS + Android)

Le code demande automatiquement :
- ✅ **ACCESS_FINE_LOCATION** : Position GPS précise
- ✅ **ACCESS_COARSE_LOCATION** : Position approximative
- ✅ **INTERNET** : Accès à Internet pour Google Maps

---

## 📋 Fichiers Modifiés

| Fichier | Modifications |
|---------|--------------|
| `pubspec.yaml` | Ajout `google_maps_flutter`, `geolocator`, `url_launcher` |
| `lib/screens/map_screen.dart` | **NOUVEAU** - Écran de carte complet |
| `lib/screens/home_screen.dart` | Intégration du MapScreen, amélioration création boutique |

---

## 🧪 Tests

Pour tester la carte :

```bash
flutter run
```

Puis :
1. Naviguer vers l'onglet "Carte"
2. Cliquer sur "Créer une Boutique"
3. Entrer des coordonnées GPS valides (ex: Paris 48.8566, 2.3522)
4. Observer les marqueurs sur la carte
5. Cliquer sur un marqueur pour voir les détails
6. Utiliser "Itinéraire" pour lancer Google Maps

---

## 🐛 Dépannage

### "Google Maps ne s'affiche pas"
- ✅ Vérifier que la clé API est correctement configurée dans `AndroidManifest.xml`
- ✅ Vérifier que les empreintes SHA-1 sont ajoutées à la clé API
- ✅ Vérifier Internet activé sur le téléphone

### "Erreur de localisation"
- ✅ Vérifier les permissions dans les paramètres du téléphone
- ✅ Vérifier que le téléphone a accès à la localisation
- ✅ Essayer d'éteindre/rallumer la localisation

### "Boutiques ne s'affichent pas"
- ✅ Vérifier que les champs `latitude` et `longitude` existent dans Firestore
- ✅ Vérifier que les coordonnées sont valides (lat: -90 à 90, lng: -180 à 180)
- ✅ Vérifier la connexion Internet et l'accès à Firestore

---

## 🚀 Prochaines Étapes

- [ ] Ajouter clustering de marqueurs (trop de boutiques)
- [ ] Ajouter filtre par catégorie de produit
- [ ] Ajouter filtrage par distance/note
- [ ] Ajouter partage d'emplacement boutique
- [ ] Ajouter photos de boutique sur la carte

