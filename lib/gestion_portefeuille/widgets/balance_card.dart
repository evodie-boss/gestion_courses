// MODIFIER votre balance_card.dart

import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  final double balance;
  final double monthlyExpenses;
  final double remainingBudget;
  final bool isLoading;
  final String currencySymbol; // ← NOUVEAU paramètre

  const BalanceCard({
    super.key,
    required this.balance,
    required this.monthlyExpenses,
    required this.remainingBudget,
    required this.isLoading,
    this.currencySymbol = 'FCFA', // ← Valeur par défaut
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F9E99), Color(0xFF1BC6C0)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F9E99).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solde actuel',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_formatAmount(balance)} $currencySymbol',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('Dépenses mensuelles', monthlyExpenses),
                    _buildStatItem('Budget restant', remainingBudget),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${_formatAmount(value)} $currencySymbol',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // MODIFIER balance_card.dart - méthode _formatAmount

String _formatAmount(double amount) {
  if (currencySymbol == 'FCFA' || currencySymbol == 'XOF') {
    // Pour FCFA, on n'affiche pas de décimales
    return amount.toStringAsFixed(0);
  } else {
    // Pour €, 2 décimales
    return amount.toStringAsFixed(2);
  }
}
}