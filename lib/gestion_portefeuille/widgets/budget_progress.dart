import 'package:flutter/material.dart';

class BudgetProgress extends StatelessWidget {
  final double monthlyBudget;
  final double currentExpenses;
  final String currencySymbol;
  final double budgetPercentage; // NOUVEAU
  final bool isBudgetWarning; // NOUVEAU
  final bool isBudgetExceeded; // NOUVEAU

  const BudgetProgress({
    super.key,
    required this.monthlyBudget,
    required this.currentExpenses,
    required this.currencySymbol,
    required this.budgetPercentage, // NOUVEAU
    required this.isBudgetWarning, // NOUVEAU
    required this.isBudgetExceeded, // NOUVEAU
  });

  @override
  Widget build(BuildContext context) {
    final percentage = budgetPercentage;
    final remainingBudget = monthlyBudget - currentExpenses;

    Color progressColor;
    IconData statusIcon;
    String statusText;
    Color statusColor;

    if (isBudgetExceeded) {
      progressColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = 'Budget dépassé!';
      statusColor = Colors.red;
    } else if (isBudgetWarning) {
      progressColor = Colors.orange;
      statusIcon = Icons.warning_amber;
      statusText = 'Attention budget';
      statusColor = Colors.orange;
    } else {
      progressColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Budget OK';
      statusColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suivi du budget',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatAmount(currentExpenses)} / ${_formatAmount(monthlyBudget)} $currencySymbol',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Détails du budget
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBudgetDetail(
                  'Budget mensuel', monthlyBudget, const Color(0xFF0F9E99)),
              _buildBudgetDetail('Dépenses', currentExpenses, Colors.red),
              _buildBudgetDetail('Reste', remainingBudget,
                  remainingBudget >= 0 ? Colors.green : Colors.red),
            ],
          ),
          const SizedBox(height: 20),

          // Barre de progression avec marqueurs
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              final clampedPct = (percentage / 100).clamp(0.0, 1.0) as double;
              final marker80Left = (width * 0.8).clamp(0.0, width);
              final marker100Left = (width * 1.0).clamp(0.0, width);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Barre de progression
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: clampedPct,
                        backgroundColor: Colors.transparent,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 24,
                      ),
                    ),
                  ),

                  // Texte de pourcentage (centré)
                  Center(
                    child: Text(
                      '${(clampedPct * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 2,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Marqueur 80% (affiché seulement si utile)
                  if (percentage < 80)
                    Positioned(
                      left: marker80Left - 1, // centrer la ligne (≈ largeur 2)
                      top: -4,
                      child: Column(
                        children: [
                          Container(
                            width: 2,
                            height: 32,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '80%',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Marqueur 100%
                  Positioned(
                    left: marker100Left - 1,
                    top: -4,
                    child: Column(
                      children: [
                        Container(
                          width: 2,
                          height: 32,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '100%',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 10),

          // Légende
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: progressColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '100%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Message d'alerte
          if (isBudgetExceeded || isBudgetWarning)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, size: 20, color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isBudgetExceeded
                          ? 'Vous avez dépassé votre budget mensuel de ${_formatAmount(-remainingBudget)} $currencySymbol'
                          : 'Vous avez utilisé ${percentage.toStringAsFixed(1)}% de votre budget. Attention!',
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBudgetDetail(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatAmount(value)} $currencySymbol',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (currencySymbol == 'FCFA' || currencySymbol == 'XOF') {
      return amount.toStringAsFixed(0);
    } else {
      return amount.toStringAsFixed(2);
    }
  }
}
