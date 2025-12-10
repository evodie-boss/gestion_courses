import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../course_service.dart';

class AddEditCourseScreen extends StatefulWidget {
  final Course? course;
  final String userId;
  final CourseService service;

  const AddEditCourseScreen({
    Key? key,
    this.course,
    required this.userId,
    required this.service,
  }) : super(key: key);

  @override
  _AddEditCourseScreenState createState() => _AddEditCourseScreenState();
}

class _AddEditCourseScreenState extends State<AddEditCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _description;
  late double _amount;
  CoursePriority _priority = CoursePriority.low;
  DateTime? _dueDate;
  bool _saving = false;
  
  // NOUVEAUX CHAMPS
  late int _quantity;
  late double _unitPrice;
  late String _unit;
  late bool _isEssential;
  final List<String> _units = ['pièce', 'kg', 'L', 'paquet', 'boîte', 'bouteille', 'sac'];

  // Palette de couleurs
  static const Color backgroundColor = Color(0xFFEFE9E0);
  static const Color primaryColor = Color(0xFF0F9E99);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color cardColor = Colors.white;
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    if (widget.course != null) {
      final c = widget.course!;
      _title = c.title;
      _description = c.description;
      _amount = c.amount;
      _priority = c.priority;
      _dueDate = c.dueDate;
      
      // Initialiser les nouveaux champs
      _quantity = c.quantity;
      _unitPrice = c.unitPrice;
      _unit = c.unit;
      _isEssential = c.isEssential;
      
      // Si unitPrice est 0 mais amount a une valeur, calculer unitPrice
      if (_unitPrice == 0 && _amount > 0 && _quantity > 0) {
        _unitPrice = _amount / _quantity;
      }
    } else {
      _title = '';
      _description = '';
      _amount = 0;
      _quantity = 1;
      _unitPrice = 0;
      _unit = 'pièce';
      _isEssential = false;
    }
  }

  // Méthode pour calculer le montant total
  void _calculateTotal() {
    setState(() {
      _amount = _quantity * _unitPrice;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.course != null ? 'Modifier Course' : 'Ajouter Course',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            color: cardColor,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Informations principales'),
                    const SizedBox(height: 16),

                    _buildTextField(
                      label: 'Produit',
                      initialValue: _title,
                      hintText: 'Ex: Lait',
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Veuillez entrer un produit' : null,
                      onSaved: (val) => _title = val!,
                      icon: Icons.title,
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(
                      label: 'Description',
                      initialValue: _description,
                      hintText: 'Décrivez votre course...',
                      onSaved: (val) => _description = val ?? '',
                      icon: Icons.description,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // QUANTITÉ
                    _buildQuantityField(),
                    const SizedBox(height: 20),

                    // PRIX UNITAIRE
                    _buildUnitPriceField(),
                    const SizedBox(height: 20),

                    // UNITÉ
                    _buildUnitField(),
                    const SizedBox(height: 20),

                    // MONTANT TOTAL (affichage seulement)
                    _buildTotalAmountDisplay(),
                    const SizedBox(height: 20),

                    // ARTICLE ESSENTIEL
                    _buildEssentialField(),
                    const SizedBox(height: 20),

                    Divider(color: Colors.grey[300], height: 40),

                    _buildSectionTitle('Paramètres'),
                    const SizedBox(height: 16),

                    _buildPriorityField(),
                    const SizedBox(height: 20),

                    _buildDueDateField(),
                    const SizedBox(height: 40),

                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    String? hintText,
    String? Function(String?)? validator,
    required Function(String?) onSaved,
    IconData? icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextFormField(
              initialValue: initialValue,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                icon: icon != null ? Icon(icon, color: primaryColor, size: 20) : null,
                hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
              ),
              style: TextStyle(color: textPrimary, fontSize: 16),
              validator: validator,
              onSaved: onSaved,
              maxLines: maxLines,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantité',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Bouton diminuer
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor),
              ),
              child: IconButton(
                icon: Icon(Icons.remove, size: 20, color: primaryColor),
                onPressed: () {
                  if (_quantity > 1) {
                    setState(() {
                      _quantity--;
                      _calculateTotal();
                    });
                  }
                },
              ),
            ),
            
            // Affichage quantité
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextFormField(
                    textAlign: TextAlign.center,
                    initialValue: _quantity.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Quantité',
                      prefixIcon: Icon(Icons.format_list_numbered, color: primaryColor, size: 20),
                    ),
                    style: TextStyle(color: textPrimary, fontSize: 16),
                    onChanged: (value) {
                      int? qty = int.tryParse(value);
                      if (qty != null && qty > 0) {
                        setState(() {
                          _quantity = qty;
                          _calculateTotal();
                        });
                      }
                    },
                    onSaved: (value) {
                      int? qty = int.tryParse(value ?? '1');
                      if (qty != null && qty > 0) {
                        _quantity = qty;
                      }
                    },
                  ),
                ),
              ),
            ),
            
            // Bouton augmenter
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor),
              ),
              child: IconButton(
                icon: Icon(Icons.add, size: 20, color: primaryColor),
                onPressed: () {
                  setState(() {
                    _quantity++;
                    _calculateTotal();
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnitPriceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prix unitaire (FCFA)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextFormField(
              initialValue: _unitPrice == 0 ? '' : _unitPrice.toStringAsFixed(2),
              decoration: InputDecoration(
                hintText: 'Ex: 1.50',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.euro_symbol, color: primaryColor, size: 20),
                hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
              ),
              style: TextStyle(color: textPrimary, fontSize: 16),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Veuillez entrer un prix';
                }
                final price = double.tryParse(val);
                if (price == null || price <= 0) {
                  return 'Prix invalide';
                }
                return null;
              },
              onChanged: (value) {
                double? price = double.tryParse(value);
                if (price != null && price > 0) {
                  setState(() {
                    _unitPrice = price;
                    _calculateTotal();
                  });
                }
              },
              onSaved: (value) {
                double? price = double.tryParse(value ?? '0');
                if (price != null && price > 0) {
                  _unitPrice = price;
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unité',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _unit,
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.square_foot, color: Color(0xFF0F9E99)),
              ),
              icon: Icon(Icons.arrow_drop_down, color: primaryColor),
              dropdownColor: cardColor,
              style: TextStyle(color: textPrimary, fontSize: 16),
              items: _units.map((unit) {
                return DropdownMenuItem(
                  value: unit,
                  child: Text(
                    unit[0].toUpperCase() + unit.substring(1),
                    style: TextStyle(color: textPrimary),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _unit = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalAmountDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate, color: primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Montant total',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
                Text(
                  '${_amount.toStringAsFixed(2)} FCFA',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_quantity} × ${_unitPrice.toStringAsFixed(2)}FCFA',
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '= ${(_quantity * _unitPrice).toStringAsFixed(2)} FCFA',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEssentialField() {
    return Row(
      children: [
        Checkbox(
          value: _isEssential,
          onChanged: (value) {
            setState(() => _isEssential = value ?? false);
          },
          activeColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Article essentiel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              Text(
                'Ne sera pas réduit en cas de budget serré',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isEssential ? Colors.amber.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _isEssential ? Colors.amber : Colors.transparent,
            ),
          ),
          child: Text(
            _isEssential ? 'ESSENTIEL' : 'NORMAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _isEssential ? Colors.amber.shade700 : textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priorité',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<CoursePriority>(
              value: _priority,
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.flag, color: Color(0xFF0F9E99)),
              ),
              icon: Icon(Icons.arrow_drop_down, color: primaryColor),
              dropdownColor: cardColor,
              style: TextStyle(color: textPrimary, fontSize: 16),
              items: CoursePriority.values.map((p) {
                Color priorityColor = p.color;
                return DropdownMenuItem(
                  value: p,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        p.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: priorityColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (p) => setState(() => _priority = p!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDueDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date limite',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ListTile(
            leading: Icon(Icons.calendar_today, color: primaryColor),
            title: Text(
              _dueDate != null
                  ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                  : 'Aucune date sélectionnée',
              style: TextStyle(
                color: _dueDate != null ? textPrimary : textSecondary,
                fontSize: 16,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_dueDate != null)
                  IconButton(
                    icon: Icon(Icons.clear, color: errorColor, size: 20),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton(
                    onPressed: _pickDueDate,
                    child: Text(
                      _dueDate != null ? 'Changer' : 'Choisir',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: primaryColor.withOpacity(0.4),
        ),
        onPressed: _saving ? null : _saveCourse,
        child: _saving
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.course != null ? 'Mettre à jour' : 'Créer la course',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: cardColor,
          ),
          child: child!,
        );
      },
    );
    if (date != null) setState(() => _dueDate = date);
  }

  void _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier que le prix unitaire est valide
    if (_unitPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Le prix unitaire doit être supérieur à 0'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    _formKey.currentState!.save();
    setState(() => _saving = true);

    // Recalculer le montant total
    _calculateTotal();

    // Créer un nouvel objet Course avec tous les champs
    final course = Course(
      id: widget.course?.id ?? '',
      userId: widget.userId,
      title: _title,
      description: _description,
      amount: _amount,
      priority: _priority,
      status: widget.course?.status ?? CourseStatus.todo,
      createdAt: widget.course?.createdAt ?? DateTime.now(),
      dueDate: _dueDate,
      
      // Nouveaux champs
      quantity: _quantity,
      unitPrice: _unitPrice,
      unit: _unit,
      isEssential: _isEssential,
    );

    try {
      if (widget.course != null) {
        await widget.service.updateCourse(widget.course!.id, course);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Course mise à jour avec succès'),
              backgroundColor: successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        await widget.service.addCourse(course, useServerTimestamp: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Course créée avec succès'),
              backgroundColor: successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}