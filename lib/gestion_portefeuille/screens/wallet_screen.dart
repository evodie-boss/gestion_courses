import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/portefeuille_service.dart';
import '../models/transaction_model.dart' as my_models;
import '../models/portefeuille_model.dart';
import '../widgets/balance_card.dart';
import '../widgets/budget_progress.dart';
import 'add_transaction_screen.dart';
import 'transaction_history_screen.dart';
import 'statistics_screen.dart';
import 'budget_settings_screen.dart';

class WalletScreen extends StatefulWidget {
  final String userId;

  const WalletScreen({super.key, required this.userId});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late WalletService walletService;
  final PortefeuilleService _portefeuilleService = PortefeuilleService();

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
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _portefeuilleService.getStatsStream(widget.userId),
        builder: (context, statsSnapshot) {
          if (statsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (statsSnapshot.hasError) {
            return Center(
              child: Text('Erreur: ${statsSnapshot.error}'),
            );
          }

          final stats = statsSnapshot.data ?? {};
          final portefeuille = stats['portefeuille'] as Portefeuille?;
          
          if (portefeuille == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final monthlyExpenses = stats['monthlyExpenses'] as double? ?? 0.0;
          final remainingBudget = stats['remainingBudget'] as double? ?? 0.0;
          final monthlyBudget = stats['monthlyBudget'] as double? ?? 0.0;
          final budgetPercentage = stats['budgetPercentage'] as double? ?? 0.0;
          final isBudgetWarning = stats['isBudgetWarning'] as bool? ?? false;
          final isBudgetExceeded = stats['isBudgetExceeded'] as bool? ?? false;
          final isLowBalance = stats['isLowBalance'] as bool? ?? false;

          return StreamBuilder<List<my_models.Transaction>>(
            stream: walletService.getTransactionsStream(widget.userId),
            builder: (context, transactionsSnapshot) {
              if (transactionsSnapshot.hasError) {
                return Center(
                  child: Text('Erreur transactions: ${transactionsSnapshot.error}'),
                );
              }

              final transactions = transactionsSnapshot.data ?? [];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Carte du solde et budget (DYNAMIQUE)
                    BalanceCard(
                      balance: portefeuille.balance,
                      monthlyExpenses: monthlyExpenses,
                      remainingBudget: remainingBudget,
                      isLoading: false,
                      currencySymbol: portefeuille.currencySymbol,
                      monthlyBudget: monthlyBudget, // NOUVEAU
                    ),
                    const SizedBox(height: 20),

                    // Barre de progression du budget (DYNAMIQUE)
                    BudgetProgress(
                      monthlyBudget: monthlyBudget,
                      currentExpenses: monthlyExpenses,
                      currencySymbol: portefeuille.currencySymbol,
                      budgetPercentage: budgetPercentage, // NOUVEAU
                      isBudgetWarning: isBudgetWarning,   // NOUVEAU
                      isBudgetExceeded: isBudgetExceeded, // NOUVEAU
                    ),
                    const SizedBox(height: 20),

                    // Alertes dynamiques
                    if (isBudgetExceeded)
                      _buildAlertCard(
                        '⚠️ Budget dépassé !',
                        'Vous avez dépensé ${portefeuille.formatAmount(monthlyExpenses)} sur ${portefeuille.formatAmount(monthlyBudget)}',
                        Colors.red,
                        Icons.warning,
                      ),
                    if (isBudgetWarning && !isBudgetExceeded)
                      _buildAlertCard(
                        '⚠️ Attention',
                        'Vous avez utilisé ${budgetPercentage.toStringAsFixed(1)}% de votre budget',
                        Colors.orange,
                        Icons.warning_amber,
                      ),
                    if (isLowBalance && portefeuille.balance < 50000)
                      _buildAlertCard(
                        '💰 Solde faible',
                        'Votre solde est de ${portefeuille.formattedBalance}',
                        Colors.blue,
                        Icons.account_balance_wallet,
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

  Widget _buildAlertCard(String title, String message, Color color, IconData icon) {
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
          Icon(icon, color: color),
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
                        transaction.currencySymbol,
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
}