// MODIFIER votre wallet_screen.dart

import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/portefeuille_service.dart';
import '../services/budget_calculator.dart';
import '../models/transaction_model.dart' as my_models;
import '../models/portefeuille_model.dart';
import '../widgets/balance_card.dart';
import '../widgets/budget_progress.dart';
import 'add_transaction_screen.dart';
import 'transaction_history_screen.dart';
import 'statistics_screen.dart'; // ← AJOUTER CET IMPORT
import 'budget_settings_screen.dart'; // ← AJOUTER CET IMPORT


class WalletScreen extends StatefulWidget {
  final String userId;

  const WalletScreen({super.key, required this.userId});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late WalletService walletService;
  final PortefeuilleService _portefeuilleService = PortefeuilleService(); // ← NOUVEAU

  @override
  void initState() {
    super.initState();
    walletService = WalletService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mon Portefeuille',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: const Color(0xFF0F9E99),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettings();
            },
          ),
        ],
      ),
      body: StreamBuilder<Portefeuille>(
        stream: _portefeuilleService.getPortefeuilleStream(widget.userId),
        builder: (context, portefeuilleSnapshot) {
          if (!portefeuilleSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final portefeuille = portefeuilleSnapshot.data!;

          return StreamBuilder<List<my_models.Transaction>>(
            stream: walletService.getTransactionsStream(widget.userId),
            builder: (context, transactionsSnapshot) {
              if (transactionsSnapshot.hasError) {
                return Center(
                  child: Text('Erreur: ${transactionsSnapshot.error}'),
                );
              }

              if (!transactionsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final transactions = transactionsSnapshot.data!;
              
              // Calculs basés sur la devise du portefeuille
              final monthlyExpenses = _calculateMonthlyExpensesInPortefeuilleCurrency(
                transactions, 
                portefeuille
              );
              
              final remainingBudget = portefeuille.monthlyBudget - monthlyExpenses;
              final alerts = BudgetCalculator.checkAlerts(
                portefeuille.monthlyBudget, 
                transactions
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Carte du solde et budget (MAJ)
                    BalanceCard(
                      balance: portefeuille.balance,
                      monthlyExpenses: monthlyExpenses,
                      remainingBudget: remainingBudget,
                      isLoading: false,
                      currencySymbol: portefeuille.currencySymbol, // ← AJOUTER ce paramètre
                    ),
                    const SizedBox(height: 20),

                    // Barre de progression du budget (MAJ)
                    BudgetProgress(
                      monthlyBudget: portefeuille.monthlyBudget,
                      currentExpenses: monthlyExpenses,
                      alerts: alerts,
                      currencySymbol: portefeuille.currencySymbol, // ← AJOUTER ce paramètre
                    ),
                    const SizedBox(height: 20),

                    // Alertes
                    if (alerts['isBudgetExceeded'] == true)
                      _buildAlertCard(
                        '⚠️ Budget dépassé !',
                        'Vous avez dépensé ${portefeuille.formatAmount(monthlyExpenses)} sur ${portefeuille.formattedBudget}',
                        Colors.red,
                      ),
                    if (alerts['isBudgetWarning'] == true &&
                        alerts['isBudgetExceeded'] == false)
                      _buildAlertCard(
                        '⚠️ Attention',
                        'Vous avez utilisé ${alerts['percentageUsed'].toStringAsFixed(1)}% de votre budget',
                        Colors.orange,
                      ),
                    if (alerts['isLowBalance'] == true && portefeuille.balance < 50000)
                      _buildAlertCard(
                        '💰 Solde faible',
                        'Votre solde est de ${portefeuille.formattedBalance}',
                        Colors.blue,
                      ),

                    const SizedBox(height: 30),

                    // Actions rapides
                    _buildQuickActions(),

                    const SizedBox(height: 30),

                    // Dernières transactions
                    _buildRecentTransactions(transactions, portefeuille),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTransactionScreen(userId: widget.userId),
            ),
          ).then((value) {
            if (value == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction ajoutée avec succès!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          });
        },
        backgroundColor: const Color(0xFF0F9E99),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  // Calculer les dépenses mensuelles dans la devise du portefeuille
  double _calculateMonthlyExpensesInPortefeuilleCurrency(
    List<my_models.Transaction> transactions, 
    Portefeuille portefeuille
  ) {
    final now = DateTime.now();
    double total = 0.0;
    
    for (var transaction in transactions) {
      if (transaction.type == 'depense' && 
          transaction.date.month == now.month && 
          transaction.date.year == now.year) {
        
        // Convertir si la devise de la transaction est différente
        double amount = transaction.amount;
        if (transaction.currency != portefeuille.currency) {
          if (transaction.currency == 'EUR' && portefeuille.currency == 'XOF') {
            amount = portefeuille.convertToFCFA(amount);
          } else if (transaction.currency == 'XOF' && portefeuille.currency == 'EUR') {
            amount = portefeuille.convertToEUR(amount);
          }
        }
        total += amount;
      }
    }
    return total;
  }

  Widget _buildAlertCard(String title, String message, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.history,
                label: 'Historique',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TransactionHistoryScreen(userId: widget.userId),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                icon: Icons.analytics,
                label: 'Statistiques',
                onPressed: () {
                  _showStatistics();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                icon: Icons.settings,
                label: 'Paramètres',
                onPressed: () {
                  _showSettings();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F9E99),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(
    List<my_models.Transaction> transactions, 
    Portefeuille portefeuille
  ) {
    if (transactions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aucune transaction récente',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.receipt, size: 50, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    'Commencez par ajouter une transaction',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final recentTransactions = transactions.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Transactions récentes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TransactionHistoryScreen(userId: widget.userId),
                  ),
                );
              },
              child: const Text(
                'Voir tout',
                style: TextStyle(color: Color(0xFF0F9E99)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          children: recentTransactions.map((transaction) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: transaction.type == 'depense'
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      transaction.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.description,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          transaction.typeDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${transaction.type == 'depense' ? '-' : '+'}${transaction.formattedAmount}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: transaction.type == 'depense'
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                      Text(
                        '${transaction.currency == 'XOF' ? 'FCFA' : '€'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // MODIFIER les méthodes _showStatistics et _showSettings dans wallet_screen.dart

void _showStatistics() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => StatisticsScreen(userId: widget.userId),
    ),
  );
}

void _showSettings() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BudgetSettingsScreen(userId: widget.userId),
    ),
  );
}