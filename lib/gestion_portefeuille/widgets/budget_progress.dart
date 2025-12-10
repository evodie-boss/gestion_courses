// MODIFIER votre budget_progress.dart

import 'package:flutter/material.dart';

class BudgetProgress extends StatelessWidget {
  final double monthlyBudget;
  final double currentExpenses;
  final Map<String, dynamic> alerts;
  final String currencySymbol; // ← NOUVEAU paramètre

  const BudgetProgress({
    super.key,
    required this.monthlyBudget,
    required this.currentExpenses,
    required this.alerts,
    this.currencySymbol = 'FCFA', // ← Valeur par défaut
  });

  @override
  Widget build(BuildContext context) {
    final percentage = monthlyBudget > 0 ? (currentExpenses / monthlyBudget) * 100 : 0;
    Color progressColor = const Color(0xFF4CAF50); // Vert
    
    if (percentage >= 80) progressColor = Colors.orange;
    if (percentage >= 100) progressColor = Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Budget mensuel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_formatAmount(currentExpenses)}$currencySymbol / ${_formatAmount(monthlyBudget)}$currencySymbol',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade200,
            color: progressColor,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}% utilisé',
                style: TextStyle(
                  color: progressColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${_formatAmount(monthlyBudget - currentExpenses)}$currencySymbol restant',
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Formater le montant selon la devise
  // MODIFIER budget_progress.dart - méthode _formatAmount

String _formatAmount(double amount) {
  if (currencySymbol == 'FCFA' || currencySymbol == 'XOF') {
    return amount.toStringAsFixed(0);
  } else {
    return amount.toStringAsFixed(2);
  }
}
}