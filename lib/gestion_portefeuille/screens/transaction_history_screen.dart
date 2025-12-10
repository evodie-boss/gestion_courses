// lib/gestion_portefeuille/screens/transaction_history_screen.dart

import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        backgroundColor: const Color(0xFF0F9E99),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<my_models.Transaction>>(
        stream: _walletService.getTransactionsStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'Aucune transaction',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Ajoutez votre première transaction',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          List<my_models.Transaction> transactions = snapshot.data!;

          // Appliquer le filtre
          if (_filterType != 'tous') {
            transactions = transactions
                .where((t) => t.type == _filterType)
                .toList();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return TransactionItem(
                transaction: transaction,
                onTap: () {
                  _showTransactionDetails(transaction);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filtrer par type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Toutes les transactions'),
                value: 'tous',
                groupValue: _filterType,
                onChanged: (value) {
                  setState(() {
                    _filterType = value!;
                  });
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String>(
                title: const Text('Dépenses seulement'),
                value: 'depense',
                groupValue: _filterType,
                onChanged: (value) {
                  setState(() {
                    _filterType = value!;
                  });
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String>(
                title: const Text('Ajouts seulement'),
                value: 'ajout',
                groupValue: _filterType,
                onChanged: (value) {
                  setState(() {
                    _filterType = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTransactionDetails(my_models.Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Détails'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type: ${transaction.typeDisplay}'),
              const SizedBox(height: 8),
              Text('Montant: ${transaction.amount.toStringAsFixed(2)}€'),
              const SizedBox(height: 8),
              Text('Description: ${transaction.description}'),
              const SizedBox(height: 8),
              Text('Date: ${transaction.date.day}/${transaction.date.month}/${transaction.date.year}'),
            ],
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
}