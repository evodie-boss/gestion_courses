# gestion_courses

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.









Membre	     Fonctionnalités assignées	      Détails précis

Mary-Shanna : Page d’accueil + navigation + profil utilisateur	

- Créer la page Home avec design violet/blanc.
- Ajouter drawer / bottom navigation bar pour accéder à : Courses, Portefeuille, Boutiques, Commandes.
- Page Profil utilisateur : nom, email, solde portefeuille.
- Assurer navigation vers toutes les pages avec Navigator.push.
- Ajouter animations / hover effects sur boutons.
- Connexion avec Firebase Auth pour récupérer l’utilisateur connecté.

Albine : Courses – création, modification, suppression + priorités
	
- Créer page Courses listant les courses depuis Firestore filtrées par userId.
- Ajouter / Modifier / Supprimer une course.
- Chaque course : titre, description, montant estimé, priorité (Haute/Moyenne/Basse), status (À faire/Fait), date limite.
- Trier les courses par priorité ou date.
- Marquer comme terminée et synchroniser avec Firestore en temps réel.

Evodie : Portefeuille + gestion du budget	

- Page Portefeuille affichant : solde actuel, dépenses totales, budget restant.
- Ajouter transactions : dépense ou ajout de fonds.
- Calcul automatique du budget restant après chaque transaction.
- Ajouter alertes / notifications si dépassement du budget.
- Historique des transactions et synchronisation avec Firestore.

Jenny : Boutiques – liste, détails + commandes	

- Page Boutiques : afficher nom, adresse, coordonnées, téléphone.
- Page Commandes : associer courses à une boutique, calculer le total.
- Afficher statut des commandes : En cours / Livrée.
- Ajouter historique des commandes passées.
- Sauvegarde des boutiques et commandes dans Firestore.

Hermine : Géolocalisation + cartes + itinéraires
	
- Intégrer Google Maps et geolocator.
- Afficher position actuelle de l’utilisateur.
- Afficher toutes les boutiques sur la carte avec markers.
- Calculer itinéraire et distance vers boutique sélectionnée.
- Mettre à jour coordonnées boutiques si nécessaire dans Firestore.
- Tester la géolocalisation sur différents appareils pour précision.