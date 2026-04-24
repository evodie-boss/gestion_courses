// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gestion_courses/models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserModel? _currentUser;
  
  // NOUVEAU : Cache pour éviter trop de requêtes
  double? _cachedWalletBalance;

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            _currentUser = _userFromDocument(userDoc);
            // NOUVEAU : Charger le solde réel
            await _loadRealWalletBalance(user.uid);
          } else {
            _currentUser = _createUserModel(user);
            await _saveUserToFirestore(_currentUser!);
          }
        } catch (e) {
          print('Erreur récupération utilisateur: $e');
          _currentUser = _createUserModel(user);
        }
      } else {
        _currentUser = null;
        _cachedWalletBalance = null;
      }
      notifyListeners();
    });
  }

  // NOUVELLE MÉTHODE : Charger le solde réel depuis portefeuille
  Future<void> _loadRealWalletBalance(String userId) async {
    try {
      final walletDoc = await _firestore
          .collection('portefeuille')
          .doc(userId)
          .get();
      
      if (walletDoc.exists) {
        _cachedWalletBalance = (walletDoc.data()?['balance'] ?? 0.0).toDouble();
        print('💰 Solde réel chargé: $_cachedWalletBalance FCFA');
      } else {
        // Créer un portefeuille par défaut
        final defaultPortefeuille = {
          'userId': userId,
          'balance': 0.0,
          'monthlyBudget': 0.0,
          'currency': 'XOF',
          'exchangeRate': 655.96,
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        await _firestore.collection('portefeuille').doc(userId).set(defaultPortefeuille);
        _cachedWalletBalance = 0.0;
        print('💰 Portefeuille créé par défaut');
      }
    } catch (e) {
      print('❌ Erreur chargement solde: $e');
      _cachedWalletBalance = 0.0;
    }
  }

  // NOUVELLE MÉTHODE : Récupérer le solde réel
  Future<double> getRealWalletBalance(String userId) async {
    // Retourner le cache si disponible
    if (_cachedWalletBalance != null && userId == _currentUser?.id) {
      return _cachedWalletBalance!;
    }
    
    try {
      final walletDoc = await _firestore
          .collection('portefeuille')
          .doc(userId)
          .get();
      
      if (walletDoc.exists) {
        final balance = (walletDoc.data()?['balance'] ?? 0.0).toDouble();
        // Mettre en cache
        if (userId == _currentUser?.id) {
          _cachedWalletBalance = balance;
        }
        return balance;
      }
      return 0.0;
    } catch (e) {
      print('❌ Erreur getRealWalletBalance: $e');
      return 0.0;
    }
  }

  // NOUVELLE MÉTHODE : Rafraîchir le solde
  Future<void> refreshWalletBalance() async {
    if (_currentUser != null) {
      await _loadRealWalletBalance(_currentUser!.id);
      notifyListeners();
    }
  }

  // Getter pour le solde avec mise à jour automatique
  Future<double> get walletBalance async {
    if (_currentUser == null) return 0.0;
    return await getRealWalletBalance(_currentUser!.id);
  }

  // MÉTHODE EXISTANTE AMÉLIORÉE
  Future<UserModel?> getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final user = _userFromDocument(userDoc);
        // Charger le solde réel
        final balance = await getRealWalletBalance(userId);
        // Retourner un user avec le solde mis à jour
        return user.copyWith(soldePortefeuille: balance);
      }
      return null;
    } catch (e) {
      print('Erreur récupération utilisateur $userId: $e');
      return null;
    }
  }

  // MÉTHODE PRIVÉE - accessible seulement dans cette classe
  Future<void> _saveUserToFirestore(UserModel user) async {
    try {
      print('💾 Sauvegarde dans Firestore...');
      final data = user.toFirestore();
      print('📦 Données: $data');
      await _firestore.collection('users').doc(user.id).set(data);
      print('✅ Sauvegardé avec succès!');
    } catch (e) {
      print('❌ Erreur sauvegarde Firestore: $e');
      rethrow;
    }
  }

  UserModel _createUserModel(User user) {
    return UserModel(
      id: user.uid,
      nom: user.displayName?.split(' ').last ?? '',
      prenom: user.displayName?.split(' ').first ?? '',
      email: user.email ?? '',
      numeroPhone: user.phoneNumber ?? '',
      soldePortefeuille: 0.0,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  UserModel _userFromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel(
      id: doc.id,
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      email: data['email'] ?? '',
      numeroPhone: data['numeroPhone'] ?? '',
      soldePortefeuille: _cachedWalletBalance ?? (data['soldePortefeuille'] ?? 0.0).toDouble(), // CORRIGÉ
      createdAt: data['createdAt'] ?? '',
    );
  }

  // Inscription avec email/mot de passe
  Future<UserModel?> registerWithEmail(
    String email,
    String password,
    String nom,
    String prenom,
    String phone,
  ) async {
    try {
      print('🚀 Début inscription...');

      // 1. Création Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = result.user!;
      print('✅ Auth créé: ${user.uid}');

      // 2. Mise à jour display name
      await user.updateDisplayName('$prenom $nom');
      print('✅ Display name mis à jour');

      // 3. Création UserModel
      final userModel = UserModel(
        id: user.uid,
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: email.trim(),
        numeroPhone: phone.trim(),
        soldePortefeuille: 0.0,
        createdAt: DateTime.now().toIso8601String(),
      );
      print('✅ UserModel créé');

      // 4. Sauvegarde Firestore - APPEL DE LA MÉTHODE PRIVÉE
      await _saveUserToFirestore(userModel);

      // 5. Créer le portefeuille
      final defaultPortefeuille = {
        'userId': user.uid,
        'balance': 0.0,
        'monthlyBudget': 0.0,
        'currency': 'XOF',
        'exchangeRate': 655.96,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      await _firestore.collection('portefeuille').doc(user.uid).set(defaultPortefeuille);
      print('💰 Portefeuille créé');

      // 6. Vérification
      final doc = await _firestore.collection('users').doc(user.uid).get();
      print('📄 Document vérifié: ${doc.exists}');
      if (doc.exists) {
        print('📊 Données: ${doc.data()}');
      }

      // 7. Mise à jour état
      _currentUser = userModel;
      _cachedWalletBalance = 0.0;
      notifyListeners();

      print('🎉 Inscription réussie!');
      return userModel;
    } catch (e) {
      print('❌ Erreur inscription: $e');
      rethrow;
    }
  }

  // Connexion avec email/mot de passe
  Future<UserModel?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Récupérer les données depuis Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .get();

      if (userDoc.exists) {
        _currentUser = _userFromDocument(userDoc);
        // Charger le solde réel
        await _loadRealWalletBalance(result.user!.uid);
      } else {
        // Créer l'utilisateur dans Firestore s'il n'existe pas
        _currentUser = _createUserModel(result.user!);
        await _saveUserToFirestore(_currentUser!);
      }

      notifyListeners();
      return _currentUser;
    } catch (e) {
      print('Erreur de connexion: $e');
      rethrow;
    }
  }

  // Mettre à jour l'utilisateur dans Firestore
  Future<void> updateUserData(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.id)
          .update(user.toFirestore());
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      print('Erreur de mise à jour utilisateur: $e');
      rethrow;
    }
  }

  Stream<UserModel?> get user {
    return _auth.authStateChanges().asyncMap((User? user) async {
      if (user == null) return null;
      return await getUserData(user.uid); // Maintenant cette méthode existe
    });
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      _cachedWalletBalance = null;
      notifyListeners();
    } catch (e) {
      print('Erreur de déconnexion: $e');
      rethrow;
    }
  }

  bool get isLoggedIn => _auth.currentUser != null;

  UserModel? get currentUser => _currentUser;
}