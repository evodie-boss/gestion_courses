import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  final double balance;
  final double monthlyExpenses;
  final double remainingBudget;
  final bool isLoading;
  final String currencySymbol;
  final double monthlyBudget; // NOUVEAU: Ajout du paramètre

  const BalanceCard({
    super.key,
    required this.balance,
    required this.monthlyExpenses,
    required this.remainingBudget,
    required this.isLoading,
    required this.currencySymbol,
    required this.monthlyBudget, // NOUVEAU
  });

  @override
  Widget build(BuildContext context) {
    final percentage = monthlyBudget > 0 
        ? (monthlyExpenses / monthlyBudget) * 100 
        : 0.0;
    
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
                
                // NOUVEAU: Affichage du budget mensuel
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('Budget mensuel', monthlyBudget),
                    _buildPercentageItem(percentage),
                  ],
                ),
                const SizedBox(height: 10),
                
                // Barre de progression simple
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getProgressColor(percentage)
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                
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

  Widget _buildPercentageItem(double percentage) {
    Color textColor;
    String status;
    
    if (percentage >= 100) {
      textColor = Colors.red[100]!;
      status = 'DÉPASSÉ';
    } else if (percentage >= 80) {
      textColor = Colors.orange[100]!;
      status = 'ATTENTION';
    } else {
      textColor = Colors.green[100]!;
      status = 'OK';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Utilisation',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: textColor.withOpacity(0.5)),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 100) {
      return Colors.red;
    } else if (percentage >= 80) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

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