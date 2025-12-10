// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:gestion_courses/constants/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:gestion_courses/services/auth_service.dart';
import 'package:gestion_courses/models/user_model.dart';
// AJOUTEZ CES IMPORTS
import 'package:gestion_courses/gestion_portefeuille/screens/recharge_wallet_screen.dart';
import 'package:gestion_courses/gestion_portefeuille/screens/transaction_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Récupérer l'utilisateur depuis AuthService
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    // Si l'utilisateur n'est pas connecté, afficher un message
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Profil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.tropicalTeal,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_rounded,
                size: 80,
                color: AppColors.tropicalTeal.withOpacity(0.3),
              ),
              const SizedBox(height: 20),
              const Text(
                'Non connecté',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tropicalTeal,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Veuillez vous connecter pour voir votre profil',
                style: TextStyle(fontSize: 16, color: AppColors.textColor),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Retour à l'écran précédent
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tropicalTeal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retour',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Si l'utilisateur est connecté, afficher son profil
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mon Profil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.tropicalTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () => _editProfile(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Section Avatar et Informations
            _buildProfileHeader(context, user),

            // Section Informations personnelles
            _buildPersonalInfoSection(context, user),

            // Section Solde du portefeuille
            _buildWalletSection(context, user),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.tropicalTeal,
            AppColors.tropicalTeal.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Avatar avec les initiales
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                user.prenom.isNotEmpty && user.nom.isNotEmpty
                    ? '${user.prenom[0]}${user.nom[0]}'.toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tropicalTeal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${user.prenom} ${user.nom}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.email,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'Compte vérifié',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(BuildContext context, UserModel user) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations personnelles',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.tropicalTeal,
            ),
          ),
          const SizedBox(height: 20),

          // Nom complet
          _buildInfoItem(
            context: context,
            icon: Icons.person_outline_rounded,
            label: 'Nom complet',
            value: '${user.prenom} ${user.nom}',
            onTap: () =>
                _editField(context, 'Nom', '${user.prenom} ${user.nom}'),
          ),

          const Divider(height: 24),

          // Email
          _buildInfoItem(
            context: context,
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email,
            onTap: () => _editField(context, 'Email', user.email),
          ),

          const Divider(height: 24),

          // Téléphone
          _buildInfoItem(
            context: context,
            icon: Icons.phone_outlined,
            label: 'Téléphone',
            value: user.numeroPhone.isNotEmpty
                ? user.numeroPhone
                : 'Non renseigné',
            onTap: () => _editField(context, 'Téléphone', user.numeroPhone),
          ),

          const Divider(height: 24),

          // Date d'inscription
          _buildInfoItem(
            context: context,
            icon: Icons.calendar_today_outlined,
            label: 'Membre depuis',
            value: _formatDate(user.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSection(BuildContext context, UserModel user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portefeuille',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.tropicalTeal,
            ),
          ),
          const SizedBox(height: 20),

          // Solde actuel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.tropicalTeal.withOpacity(0.1),
                  Colors.amber.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.tropicalTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Solde disponible',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textColor,
                        ),
                      ),
                      Text(
                        '${user.soldePortefeuille} FCFA',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.tropicalTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Actions portefeuille
          Row(
            children: [
              Expanded(
                child: _buildWalletAction(
                  icon: Icons.add_rounded,
                  label: 'Recharger',
                  color: AppColors.tropicalTeal,
                  onTap: () => _rechargeWallet(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWalletAction(
                  icon: Icons.history_rounded,
                  label: 'Historique',
                  color: Colors.blue.shade700,
                  onTap: () => _viewTransactionHistory(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildInfoItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.tropicalTeal.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 24, color: AppColors.tropicalTeal),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textColor.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.tropicalTeal,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        splashColor: color.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Méthodes utilitaires
  String _formatDate(String date) {
    try {
      // Essayer de parser la date
      final parsedDate = DateTime.tryParse(date);
      if (parsedDate != null) {
        // Formater la date en français
        final day = parsedDate.day.toString().padLeft(2, '0');
        final month = parsedDate.month.toString().padLeft(2, '0');
        final year = parsedDate.year;
        return '$day/$month/$year';
      }
      return date;
    } catch (e) {
      return date;
    }
  }

  void _editProfile(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier le profil'),
          content: const Text('Cette fonctionnalité sera bientôt disponible!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _editField(BuildContext context, String field, String currentValue) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Modifier $field'),
          content: Text('Modification de $field: $currentValue'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                // Ici, vous pourriez appeler authService.updateUserData()
                Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  // CORRIGEZ CES 3 MÉTHODES :

  void _rechargeWallet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RechargeWalletScreen(),
      ),
    );
  }

  void _viewTransactionHistory(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionHistoryScreen(userId: user.id),
        ),
      );
    }
  }

 }