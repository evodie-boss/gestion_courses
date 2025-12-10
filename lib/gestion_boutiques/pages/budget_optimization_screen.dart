import 'package:flutter/material.dart';

class BudgetOptimizationScreen extends StatefulWidget {
  final List<dynamic> selectedCourses;
  
  const BudgetOptimizationScreen({
    super.key,
    required this.selectedCourses,
  });
  
  @override
  _BudgetOptimizationScreenState createState() => _BudgetOptimizationScreenState();
}

class _BudgetOptimizationScreenState extends State<BudgetOptimizationScreen> {
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _runOptimization();
  }
  
  Future<void> _runOptimization() async {
    try {
      setState(() => _isLoading = true);
      
      // Optimization logic to be implemented
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimisation Budgétaire'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runOptimization,
          ),
        ],
      ),
      body: _buildContent(),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Analyse de vos courses...'),
            SizedBox(height: 10),
            Text(
              'Nous calculons la meilleure répartition\npour respecter votre budget',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 20),
              const Text(
                'Erreur d\'optimisation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(_error!),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _runOptimization,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Optimisation Budgétaire',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Vos courses ont été analysées',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}