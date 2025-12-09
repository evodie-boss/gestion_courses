// lib/pages/add_edit_course_screen.dart
import 'package:flutter/material.dart';
import '../course_model.dart';
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

  // Palette de couleurs
  static const Color backgroundColor = Color(0xFFEFE9E0); // Beige clair
  static const Color primaryColor = Color(0xFF0F9E99); // Turquoise
  static const Color textPrimary = Color(0xFF1F2937); // Gris foncé
  static const Color textSecondary = Color(0xFF6B7280); // Gris moyen
  static const Color cardColor = Colors.white;
  static const Color errorColor = Color(0xFFEF4444); // Rouge
  static const Color successColor = Color(0xFF10B981); // Vert

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
    } else {
      _title = '';
      _description = '';
      _amount = 0;
    }
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
                      label: 'Titre',
                      initialValue: _title,
                      hintText: 'Ex: Courses supermarché',
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Veuillez entrer un titre' : null,
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

                    _buildAmountField(),
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

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Montant estimé (€)',
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
              initialValue: _amount == 0 ? '' : _amount.toString(),
              decoration: InputDecoration(
                hintText: 'Ex: 45.50',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.euro_symbol, color: primaryColor, size: 20),
                hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
              ),
              style: TextStyle(color: textPrimary, fontSize: 16),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (val) =>
                  val == null || double.tryParse(val) == null ? 'Entrer un nombre valide' : null,
              onSaved: (val) => _amount = double.parse(val!),
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
                Color priorityColor;
                switch (p) {
                  case CoursePriority.high:
                    priorityColor = errorColor;
                    break;
                  case CoursePriority.medium:
                    priorityColor = Color(0xFFF59E0B);
                    break;
                  case CoursePriority.low:
                    priorityColor = successColor;
                    break;
                }
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
                        p.name.toUpperCase(),
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

    FocusScope.of(context).unfocus();
    _formKey.currentState!.save();
    setState(() => _saving = true);

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
