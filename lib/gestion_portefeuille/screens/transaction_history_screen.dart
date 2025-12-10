// lib/gestion_portefeuille/screens/transaction_history_screen.dart

import 'package:flutter/material.dart';
import 'package:gestion_courses/constants/app_colors.dart';
import 'package:intl/intl.dart';
import '../services/wallet_service.dart';
import '../models/transaction_model.dart' as my_models;
import '../widgets/transaction_item.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String userId;

  const TransactionHistoryScreen({super.key, required this.userId});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final WalletService _walletService = WalletService();
  String _filterType = 'tous'; // 'tous', 'depense', 'ajout'
  String _selectedMonth = 'all';
  bool _isLoading = false;
  List<my_models.Transaction> _allTransactions = [];

  final List<String> _months = [
    'all',
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _walletService.getTransactionsStream(widget.userId).first;
      setState(() {
        _allTransactions = snapshot;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Erreur chargement transactions: $e');
    }
  }

  List<my_models.Transaction> _getFilteredTransactions() {
    List<my_models.Transaction> filtered = _allTransactions;

    // Filtrer par type
    if (_filterType != 'tous') {
      filtered = filtered.where((t) => t.type == _filterType).toList();
    }

    // Filtrer par mois
    if (_selectedMonth != 'all') {
      final monthIndex = _months.indexOf(_selectedMonth) - 1;
      final currentYear = DateTime.now().year;
      filtered = filtered.where((t) {
        return t.date.month == monthIndex && t.date.year == currentYear;
      }).toList();
    }

    return filtered;
  }

  double _calculateTotal(List<my_models.Transaction> transactions) {
    double total = 0;
    for (var transaction in transactions) {
      if (transaction.type == 'ajout') {
        total += transaction.amount;
      } else {
        total -= transaction.amount;
      }
    }
    return total;
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _getFilteredTransactions();
    final total = _calculateTotal(filteredTransactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historique des transactions',
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
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Résumé
          if (filteredTransactions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.tropicalTeal.withOpacity(0.05),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${filteredTransactions.length} transaction${filteredTransactions.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.tropicalTeal,
                        ),
                      ),
                      Text(
                        _selectedMonth == 'all' 
                          ? 'Tous les mois' 
                          : 'Mois de $_selectedMonth',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Solde: ${total >= 0 ? '+' : ''}${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: total >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        _filterType == 'tous' 
                          ? 'Tous types' 
                          : _filterType == 'ajout' 
                            ? 'Rechargements' 
                            : 'Dépenses',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Liste des transactions
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.tropicalTeal,
                    ),
                  )
                : filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 80,
                              color: AppColors.tropicalTeal.withOpacity(0.3),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Aucune transaction',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.tropicalTeal,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _filterType == 'tous'
                                  ? 'Vous n\'avez encore effectué aucune transaction'
                                  : 'Aucune transaction de type $_filterType',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _loadTransactions,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.tropicalTeal,
                              ),
                              child: const Text(
                                'Actualiser',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.tropicalTeal,
                        onRefresh: _loadTransactions,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final transaction = filteredTransactions[index];
                            return TransactionItem(
                              transaction: transaction,
                              onTap: () {
                                _showTransactionDetails(transaction);
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrer les transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tropicalTeal,
                ),
              ),
              const SizedBox(height: 20),
              
              // Filtre par type
              const Text(
                'Type de transaction',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  _buildFilterChip('Toutes', 'tous'),
                  _buildFilterChip('Dépenses', 'depense'),
                  _buildFilterChip('Rechargements', 'ajout'),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Filtre par mois
              const Text(
                'Mois',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _months.length,
                  itemBuilder: (context, index) {
                    final month = _months[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _buildFilterChip(
                        month == 'all' ? 'Tous les mois' : month,
                        month,
                        isMonth: true,
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Boutons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filterType = 'tous';
                          _selectedMonth = 'all';
                        });
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: AppColors.tropicalTeal),
                      ),
                      child: const Text(
                        'Réinitialiser',
                        style: TextStyle(color: AppColors.tropicalTeal),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tropicalTeal,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text(
                        'Appliquer',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isMonth = false}) {
    final isSelected = isMonth ? _selectedMonth == value : _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (isMonth) {
            _selectedMonth = value;
          } else {
            _filterType = value;
          }
        });
        if (!isMonth) {
          Navigator.pop(context);
        }
      },
      selectedColor: AppColors.tropicalTeal,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textColor,
      ),
    );
  }

  void _showTransactionDetails(my_models.Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Détails de la transaction',
            style: TextStyle(color: AppColors.tropicalTeal),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Type', transaction.typeDisplay),
                _buildDetailRow('Montant', transaction.formattedAmount),
                _buildDetailRow('Description', transaction.description),
                _buildDetailRow('Date', _formatDate(transaction.date)),
                _buildDetailRow('Devise', transaction.currency),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: transaction.type == 'ajout' 
                      ? Colors.green.withOpacity(0.1) 
                      : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        transaction.type == 'ajout' 
                          ? Icons.add_circle_outline 
                          : Icons.remove_circle_outline,
                        color: transaction.type == 'ajout' ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          transaction.type == 'ajout'
                            ? 'Cette transaction a augmenté votre solde'
                            : 'Cette transaction a diminué votre solde',
                          style: TextStyle(
                            color: transaction.type == 'ajout' ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}