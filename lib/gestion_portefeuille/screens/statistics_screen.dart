// lib/gestion_portefeuille/screens/statistics_screen.dart

import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/portefeuille_service.dart';
import '../models/transaction_model.dart' as my_models;
import '../models/portefeuille_model.dart';

class StatisticsScreen extends StatefulWidget {
  final String userId;

  const StatisticsScreen({super.key, required this.userId});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final WalletService _walletService = WalletService();
  final PortefeuilleService _portefeuilleService = PortefeuilleService();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: const Color(0xFF0F9E99),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _showDatePicker(context),
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
            stream: _walletService.getTransactionsStream(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              final allTransactions = snapshot.data ?? [];
              final monthlyTransactions = _filterTransactionsByMonth(
                allTransactions, 
                _selectedMonth, 
                _selectedYear
              );

              final stats = _calculateStatistics(
                monthlyTransactions, 
                portefeuille
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête mois
                    _buildMonthHeader(),
                    const SizedBox(height: 20),

                    // Cartes statistiques
                    _buildStatCards(stats, portefeuille),
                    const SizedBox(height: 30),

                    // Répartition des dépenses
                    _buildExpensesChart(monthlyTransactions, portefeuille),
                    const SizedBox(height: 30),

                    // Comparatif mois précédent
                    _buildMonthComparison(allTransactions, portefeuille),
                    const SizedBox(height: 30),

                    // Top dépenses
                    _buildTopExpenses(monthlyTransactions, portefeuille),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMonthHeader() {
    final monthNames = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${monthNames[_selectedMonth - 1]} $_selectedYear',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: () => _showDatePicker(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(Map<String, dynamic> stats, Portefeuille portefeuille) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          title: 'Dépenses totales',
          value: stats['totalExpenses'],
          color: Colors.red,
          icon: Icons.trending_down,
          portefeuille: portefeuille,
        ),
        _buildStatCard(
          title: 'Ajouts totaux',
          value: stats['totalIncome'],
          color: Colors.green,
          icon: Icons.trending_up,
          portefeuille: portefeuille,
        ),
        _buildStatCard(
          title: 'Transactions',
          value: stats['transactionCount'].toDouble(),
          color: Colors.blue,
          icon: Icons.list,
          isCount: true,
          portefeuille: portefeuille,
        ),
        _buildStatCard(
          title: 'Moyenne/jour',
          value: stats['dailyAverage'],
          color: Colors.orange,
          icon: Icons.calendar_today,
          portefeuille: portefeuille,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required double value,
    required Color color,
    required IconData icon,
    required Portefeuille portefeuille,
    bool isCount = false,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCount
                      ? value.toInt().toString()
                      : portefeuille.formatAmount(value),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesChart(
    List<my_models.Transaction> transactions,
    Portefeuille portefeuille
  ) {
    final dailyExpenses = _calculateDailyExpenses(transactions, portefeuille);
    final maxExpense = dailyExpenses.isNotEmpty 
        ? dailyExpenses.values.reduce((a, b) => a > b ? a : b) 
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dépenses quotidiennes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_selectedMonth}/${_selectedYear}',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: dailyExpenses.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucune donnée pour ce mois',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: dailyExpenses.length,
                      itemBuilder: (context, index) {
                        final day = index + 1;
                        final expense = dailyExpenses[day] ?? 0.0;
                        final height = maxExpense > 0 
                            ? (expense / maxExpense) * 100 
                            : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Tooltip(
                                message: '${portefeuille.formatAmount(expense)}\nJour $day',
                                child: Container(
                                  width: 20,
                                  height: height,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F9E99),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$day',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthComparison(
    List<my_models.Transaction> allTransactions,
    Portefeuille portefeuille
  ) {
    final currentMonthExpenses = _calculateMonthExpenses(
      allTransactions, 
      _selectedMonth, 
      _selectedYear, 
      portefeuille
    );
    
    final prevMonth = _selectedMonth == 1 ? 12 : _selectedMonth - 1;
    final prevYear = _selectedMonth == 1 ? _selectedYear - 1 : _selectedYear;
    final prevMonthExpenses = _calculateMonthExpenses(
      allTransactions, 
      prevMonth, 
      prevYear, 
      portefeuille
    );

    final difference = currentMonthExpenses - prevMonthExpenses;
    final percentageChange = prevMonthExpenses > 0 
        ? (difference / prevMonthExpenses) * 100 
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparaison mensuelle',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mois précédent',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      portefeuille.formatAmount(prevMonthExpenses),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Ce mois',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      portefeuille.formatAmount(currentMonthExpenses),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Icon(
                  difference >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: difference >= 0 ? Colors.red : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 5),
                Text(
                  '${difference >= 0 ? '+' : ''}${portefeuille.formatAmount(difference.abs())} '
                  '(${percentageChange.abs().toStringAsFixed(1)}%)',
                  style: TextStyle(
                    color: difference >= 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  difference >= 0 ? 'd\'augmentation' : 'de réduction',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopExpenses(
    List<my_models.Transaction> transactions,
    Portefeuille portefeuille
  ) {
    final expenses = transactions
        .where((t) => t.type == 'depense')
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final topExpenses = expenses.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 5 dépenses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (topExpenses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    'Aucune dépense ce mois-ci',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Column(
                children: topExpenses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final transaction = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F9E99).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F9E99),
                            ),
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
                                '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '-${portefeuille.formatAmount(transaction.amount)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // Méthodes utilitaires
  List<my_models.Transaction> _filterTransactionsByMonth(
    List<my_models.Transaction> transactions,
    int month,
    int year
  ) {
    return transactions
        .where((t) => t.date.month == month && t.date.year == year)
        .toList();
  }

  Map<String, dynamic> _calculateStatistics(
    List<my_models.Transaction> transactions,
    Portefeuille portefeuille
  ) {
    double totalExpenses = 0.0;
    double totalIncome = 0.0;
    int daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;

    for (var transaction in transactions) {
      double amount = transaction.amount;
      // Convertir si besoin
      if (transaction.currency != portefeuille.currency) {
        if (transaction.currency == 'EUR' && portefeuille.currency == 'XOF') {
          amount = portefeuille.convertToFCFA(amount);
        } else if (transaction.currency == 'XOF' && portefeuille.currency == 'EUR') {
          amount = portefeuille.convertToEUR(amount);
        }
      }

      if (transaction.type == 'depense') {
        totalExpenses += amount;
      } else {
        totalIncome += amount;
      }
    }

    final dailyAverage = totalExpenses / daysInMonth;

    return {
      'totalExpenses': totalExpenses,
      'totalIncome': totalIncome,
      'transactionCount': transactions.length,
      'dailyAverage': dailyAverage,
    };
  }

  Map<int, double> _calculateDailyExpenses(
    List<my_models.Transaction> transactions,
    Portefeuille portefeuille
  ) {
    final Map<int, double> dailyExpenses = {};

    for (var transaction in transactions) {
      if (transaction.type == 'depense') {
        final day = transaction.date.day;
        double amount = transaction.amount;
        
        // Convertir si besoin
        if (transaction.currency != portefeuille.currency) {
          if (transaction.currency == 'EUR' && portefeuille.currency == 'XOF') {
            amount = portefeuille.convertToFCFA(amount);
          } else if (transaction.currency == 'XOF' && portefeuille.currency == 'EUR') {
            amount = portefeuille.convertToEUR(amount);
          }
        }

        dailyExpenses[day] = (dailyExpenses[day] ?? 0.0) + amount;
      }
    }

    return dailyExpenses;
  }

  double _calculateMonthExpenses(
    List<my_models.Transaction> allTransactions,
    int month,
    int year,
    Portefeuille portefeuille
  ) {
    final monthlyTransactions = _filterTransactionsByMonth(allTransactions, month, year);
    double total = 0.0;

    for (var transaction in monthlyTransactions) {
      if (transaction.type == 'depense') {
        double amount = transaction.amount;
        // Convertir si besoin
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

  Future<void> _showDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = picked.month;
        _selectedYear = picked.year;
      });
    }
  }
}