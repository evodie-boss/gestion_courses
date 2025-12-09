// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gestion_courses/models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserModel? _currentUser;

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
      }
      notifyListeners();
    });
  }

  // MÉTHODE MANQUANTE : Ajoutez cette méthode
  Future<UserModel?> getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return _userFromDocument(userDoc);
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
      soldePortefeuille: (data['soldePortefeuille'] ?? 0.0).toDouble(),
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

      // 5. Vérification
      final doc = await _firestore.collection('users').doc(user.uid).get();
      print('📄 Document vérifié: ${doc.exists}');
      if (doc.exists) {
        print('📊 Données: ${doc.data()}');
      }

      // 6. Mise à jour état
      _currentUser = userModel;
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
      notifyListeners();
    } catch (e) {
      print('Erreur de déconnexion: $e');
      rethrow;
    }
  }

  bool get isLoggedIn => _auth.currentUser != null;

  UserModel? get currentUser => _currentUser;
}
