// lib/gestion_portefeuille/widgets/transaction_item.dart

import 'package:flutter/material.dart';
import '../models/transaction_model.dart' as my_models;

class TransactionItem extends StatelessWidget {
  final my_models.Transaction transaction;
  final VoidCallback? onTap;
  final bool showDate;

  const TransactionItem({
    super.key,
    required this.transaction,
    this.onTap,
    this.showDate = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDepense = transaction.type == 'depense';
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isDepense
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              transaction.icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          title: Text(
            transaction.description,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: showDate
              ? Text(
                  _formatDate(transaction.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                )
              : null,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDepense ? '-' : '+'}${transaction.amount.toStringAsFixed(2)}€',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDepense ? Colors.red : Colors.green,
                ),
              ),
              Text(
                transaction.typeDisplay,
                style: TextStyle(
                  fontSize: 12,
                  color: isDepense ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDay = DateTime(date.year, date.month, date.day);
    
    if (transactionDay == today) {
      return "Aujourd'hui";
    } else if (transactionDay == today.subtract(const Duration(days: 1))) {
      return 'Hier';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}