// lib/gestion_portefeuille/screens/budget_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ← AJOUTER cet import
import '../services/portefeuille_service.dart';
import '../services/user_preferences.dart';
import '../models/portefeuille_model.dart';

class BudgetSettingsScreen extends StatefulWidget {
  final String userId;

  const BudgetSettingsScreen({super.key, required this.userId});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final PortefeuilleService _portefeuilleService = PortefeuilleService();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _exchangeRateController = TextEditingController();
  
  String _selectedCurrency = 'XOF';
  bool _isLoading = false;
  Portefeuille? _portefeuille;

  @override
  void initState() {
    super.initState();
    _loadPortefeuille();
  }

  Future<void> _loadPortefeuille() async {
    setState(() => _isLoading = true);
    try {
      _portefeuille = await _portefeuilleService.getOrCreatePortefeuille(widget.userId);
      _selectedCurrency = _portefeuille!.currency;
      _budgetController.text = _portefeuille!.monthlyBudget.toStringAsFixed(0);
      _exchangeRateController.text = _portefeuille!.exchangeRate.toStringAsFixed(2);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBudget() async {
    if (_budgetController.text.isEmpty) return;
    
    try {
      final newBudget = double.parse(_budgetController.text);
      await _portefeuilleService.updateMonthlyBudget(widget.userId, newBudget);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Budget mis à jour avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadPortefeuille(); // Recharger les données
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _changeCurrency() async {
    if (_portefeuille == null) return;
    
    try {
      await _portefeuilleService.changeCurrency(widget.userId, _selectedCurrency);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Devise changée en $_selectedCurrency'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadPortefeuille(); // Recharger les données
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateExchangeRate() async {
    if (_exchangeRateController.text.isEmpty) return;
    
    try {
      final newRate = double.parse(_exchangeRateController.text);
      // Ici, on appelle la méthode du service - pas d'extension
      await _portefeuilleService.updateExchangeRate(widget.userId, newRate);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Taux de change mis à jour!'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadPortefeuille();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetPortefeuille() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text(
          'Êtes-vous sûr de vouloir réinitialiser votre portefeuille ? '
          'Cette action supprimera toutes vos transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _portefeuilleService.resetPortefeuille(widget.userId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Portefeuille réinitialisé avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
        
        _loadPortefeuille();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres Budget'),
        backgroundColor: const Color(0xFF0F9E99),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section Budget Mensuel
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Budget Mensuel',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Définissez votre budget mensuel pour suivre vos dépenses',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _budgetController,
                            decoration: InputDecoration(
                              labelText: 'Budget mensuel',
                              hintText: _selectedCurrency == 'XOF' 
                                  ? 'Ex: 500000' 
                                  : 'Ex: 500',
                              suffixText: _selectedCurrency == 'XOF' ? 'FCFA' : '€',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 15),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: _updateBudget,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F9E99),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Mettre à jour'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section Devise
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Devise',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Choisissez votre devise préférée',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text('Franc CFA (FCFA)'),
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
                                  label: const Text('Euro (€)'),
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
                          if (_portefeuille != null && _portefeuille!.currency != _selectedCurrency)
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: _changeCurrency,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Changer de devise'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section Taux de Change
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Taux de Change',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '1 € = ? FCFA',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _exchangeRateController,
                            decoration: InputDecoration(
                              labelText: 'Taux de change',
                              hintText: 'Ex: 655.96',
                              suffixText: 'FCFA',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 15),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: _updateExchangeRate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F9E99),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Mettre à jour'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section Actions
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Actions irréversibles sur votre portefeuille',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 15),
                          
                          // Réinitialiser portefeuille
                          ListTile(
                            leading: const Icon(Icons.refresh, color: Colors.red),
                            title: const Text(
                              'Réinitialiser le portefeuille',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Remet à zéro votre solde et votre budget',
                            ),
                            trailing: ElevatedButton(
                              onPressed: _resetPortefeuille,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Réinitialiser'),
                            ),
                          ),

                          const Divider(),

                          // Exporter données
                          ListTile(
                            leading: const Icon(Icons.download, color: Color(0xFF0F9E99)),
                            title: const Text(
                              'Exporter les données',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Téléchargez vos transactions en format CSV',
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Fonctionnalité export à venir...'),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F9E99),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Exporter'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Informations actuelles
                  if (_portefeuille != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informations actuelles',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            _buildInfoItem(
                              'Devise actuelle',
                              _portefeuille!.currency == 'XOF' ? 'Franc CFA (FCFA)' : 'Euro (€)',
                            ),
                            _buildInfoItem(
                              'Budget mensuel',
                              _portefeuille!.formattedBudget,
                            ),
                            _buildInfoItem(
                              'Solde actuel',
                              _portefeuille!.formattedBalance,
                            ),
                            _buildInfoItem(
                              'Taux de change',
                              '1 € = ${_portefeuille!.exchangeRate} FCFA',
                            ),
                            _buildInfoItem(
                              'Dernière mise à jour',
                              '${_portefeuille!.lastUpdated.day}/${_portefeuille!.lastUpdated.month}/${_portefeuille!.lastUpdated.year}',
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }
}