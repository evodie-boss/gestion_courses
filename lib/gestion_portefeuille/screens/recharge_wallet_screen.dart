import 'package:flutter/material.dart';
import 'package:gestion_courses/constants/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:gestion_courses/services/auth_service.dart';
import '../services/wallet_service.dart';
import '../models/transaction_model.dart' as my_models;

class RechargeWalletScreen extends StatefulWidget {
  const RechargeWalletScreen({super.key});

  @override
  State<RechargeWalletScreen> createState() => _RechargeWalletScreenState();
}

class _RechargeWalletScreenState extends State<RechargeWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCurrency = 'XOF';
  bool _isLoading = false;
  double _realWalletBalance = 0.0; // NOUVEAU : Pour stocker le solde réel

  final List<Map<String, dynamic>> _quickAmounts = [
    {'amount': 1000, 'label': '1.000 FCFA'},
    {'amount': 5000, 'label': '5.000 FCFA'},
    {'amount': 10000, 'label': '10.000 FCFA'},
    {'amount': 20000, 'label': '20.000 FCFA'},
    {'amount': 50000, 'label': '50.000 FCFA'},
    {'amount': 100000, 'label': '100.000 FCFA'},
  ];

  @override
  void initState() {
    super.initState();
    _descriptionController.text = 'Rechargement portefeuille';
    _loadRealWalletBalance();
  }

  Future<void> _loadRealWalletBalance() async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    
    if (user != null) {
      try {
        final balance = await authService.getRealWalletBalance(user.id);
        setState(() {
          _realWalletBalance = balance;
        });
      } catch (e) {
        print('Erreur chargement solde: $e');
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _rechargeWallet(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final amount = double.parse(_amountController.text);
        if (amount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Le montant doit être supérieur à 0'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final authService = Provider.of<AuthService>(context, listen: false);
        final walletService = WalletService();
        final user = authService.currentUser;

        if (user != null) {
          // Créer la transaction de recharge
          final transaction = my_models.Transaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userId: user.id,
            type: 'ajout',
            amount: amount,
            description: _descriptionController.text,
            date: DateTime.now(),
            currency: _selectedCurrency,
            createdAt: DateTime.now(),
          );

          // Ajouter la transaction
          await walletService.addTransaction(transaction);

          // IMPORTANT : Rafraîchir le solde dans AuthService
          await authService.refreshWalletBalance();

          // Mettre à jour le solde local
          await _loadRealWalletBalance();

          // Afficher un message de succès
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Portefeuille rechargé de ${amount.toStringAsFixed(0)} $_selectedCurrency'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Retourner à l'écran précédent AVEC succès
          Navigator.pop(context, true);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recharger le portefeuille',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.tropicalTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations actuelles - CORRIGÉ : Utiliser _realWalletBalance
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.tropicalTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.tropicalTeal.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.tropicalTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Solde actuel',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textColor,
                          ),
                        ),
                        Text(
                          '${_realWalletBalance.toStringAsFixed(0)} FCFA', // CORRIGÉ
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.tropicalTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Montants rapides
            const Text(
              'Montants rapides',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.tropicalTeal,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _quickAmounts.map((item) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _amountController.text = item['amount'].toString();
                      _selectedCurrency = 'XOF';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _amountController.text == item['amount'].toString()
                          ? AppColors.tropicalTeal
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _amountController.text == item['amount'].toString()
                            ? AppColors.tropicalTeal
                            : Colors.grey.shade300,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      item['label'],
                      style: TextStyle(
                        color: _amountController.text == item['amount'].toString()
                            ? Colors.white
                            : AppColors.textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // Formulaire de recharge
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Montant personnalisé',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.tropicalTeal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Montant',
                            prefixIcon: const Icon(Icons.attach_money_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un montant';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return 'Montant invalide';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 100,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCurrency,
                          decoration: InputDecoration(
                            labelText: 'Devise',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'XOF',
                              child: Text('FCFA'),
                            ),
                            DropdownMenuItem(
                              value: 'EUR',
                              child: Text('EUR'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCurrency = value!);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (optionnel)',
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 30),

                  // Bouton de recharge
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _rechargeWallet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tropicalTeal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                                SizedBox(width: 10),
                                Text(
                                  'Recharger maintenant',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note importante',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Le rechargement sera immédiatement disponible dans votre portefeuille.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}