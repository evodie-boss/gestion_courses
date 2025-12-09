// MODIFIER votre add_transaction_screen.dart

import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../models/transaction_model.dart' as my_models;

class AddTransactionScreen extends StatefulWidget {
  final String userId;

  const AddTransactionScreen({super.key, required this.userId});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final WalletService _walletService = WalletService();
  
  // Variables pour le formulaire
  String _selectedType = 'depense';
  String _selectedCurrency = 'XOF'; // ← NOUVEAU : Devise par défaut
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  
  // Taux de change (1€ = 655.96 FCFA)
  final double _exchangeRate = 655.96;
  
  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Calculer le montant converti
  double _getConvertedAmount() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    return amount;
  }

  // Formater selon devise
  String _formatAmount(double amount) {
    if (_selectedCurrency == 'XOF') {
      return '${amount.toStringAsFixed(0)} FCFA';
    } else {
      return '${amount.toStringAsFixed(2)} €';
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final transaction = my_models.Transaction.newTransaction(
          userId: widget.userId,
          type: _selectedType,
          amount: _getConvertedAmount(),
          description: _descriptionController.text,
          date: _selectedDate,
          currency: _selectedCurrency, // ← AJOUTER ce paramètre
        );

        await _walletService.addTransaction(transaction);
        
        // Retour à l'écran précédent
        if (mounted) {
          Navigator.pop(context, true);
        }
        
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Transaction'),
        backgroundColor: const Color(0xFF0F9E99),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type de transaction
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Type de transaction',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'depense',
                            label: Text('Dépense'),
                            icon: Icon(Icons.arrow_downward, color: Colors.red),
                          ),
                          ButtonSegment<String>(
                            value: 'ajout',
                            label: Text('Ajout'),
                            icon: Icon(Icons.arrow_upward, color: Colors.green),
                          ),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedType = newSelection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Devise et Montant
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Devise et Montant',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // Sélecteur de devise
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('FCFA'),
                              selected: _selectedCurrency == 'XOF',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCurrency = 'XOF';
                                });
                              },
                              selectedColor: const Color(0xFF0F9E99),
                              labelStyle: TextStyle(
                                color: _selectedCurrency == 'XOF' 
                                    ? Colors.white 
                                    : Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('€ Euro'),
                              selected: _selectedCurrency == 'EUR',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCurrency = 'EUR';
                                });
                              },
                              selectedColor: const Color(0xFF0F9E99),
                              labelStyle: TextStyle(
                                color: _selectedCurrency == 'EUR' 
                                    ? Colors.white 
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 15),
                      
                      // Champ montant
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Montant',
                          hintText: _selectedCurrency == 'XOF' 
                              ? 'Ex: 5000' 
                              : 'Ex: 50.00',
                          prefixIcon: Icon(
                            _selectedCurrency == 'XOF' 
                                ? Icons.money 
                                : Icons.euro,
                          ),
                          suffixText: _selectedCurrency == 'XOF' ? 'FCFA' : '€',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un montant';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null) {
                            return 'Montant invalide';
                          }
                          if (amount <= 0) {
                            return 'Le montant doit être positif';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {}); // Pour mettre à jour la conversion
                        },
                      ),
                      
                      // Affichage conversion
                      if (_amountController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _selectedCurrency == 'XOF'
                                ? '≈ ${(double.tryParse(_amountController.text) ?? 0) / _exchangeRate} €'
                                : '≈ ${(double.tryParse(_amountController.text) ?? 0) * _exchangeRate} FCFA',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Description
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Ex: Courses, Salaire, Restaurant...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer une description';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Date
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () => _selectDate(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F9E99).withOpacity(0.1),
                              foregroundColor: const Color(0xFF0F9E99),
                            ),
                            child: const Text('Changer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Bouton d'enregistrement
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9E99),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Enregistrer',
                  style: TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 10),

              // Bouton d'annulation
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}