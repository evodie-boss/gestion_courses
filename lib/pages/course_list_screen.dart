import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/course_model.dart';
import '../course_service.dart';
import 'add_edit_course_screen.dart';
import '../gestion_boutiques/pages/order_screen.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({Key? key}) : super(key: key);

  @override
  _CourseListScreenState createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  final CourseService _service = CourseService();
  String _sortBy = 'priority';
  bool _descending = true; // Par défaut: haute priorité d'abord
  bool _selectionMode = false;
  final Set<String> _selectedCourseIds = <String>{};

  // Palette de couleurs
  static const Color backgroundColor = Color(0xFFEFE9E0);
  static const Color primaryColor = Color(0xFF0F9E99);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);
  static const Color essentialColor = Color(0xFFFFB300); // Jaune pour essentiel

  String get _userId {
    final u = FirebaseAuth.instance.currentUser;
    return u?.uid ?? 'test_user';
  }

  // Méthode pour obtenir la couleur de priorité
  Color _getPriorityColor(CoursePriority priority) {
    return priority.color;
  }

  // Méthode pour obtenir l'icône de priorité
  IconData _getPriorityIcon(CoursePriority priority) {
    return priority.icon;
  }

  // Formater la date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final courseDate = DateTime(date.year, date.month, date.day);

    if (courseDate.isAtSameMomentAs(today)) {
      return "Aujourd'hui";
    } else if (courseDate.isAtSameMomentAs(
      today.add(const Duration(days: 1)),
    )) {
      return "Demain";
    } else {
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}";
    }
  }

  // Calculer le style de texte selon le statut
  TextStyle _getTextStyle(bool isDone) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: isDone ? textSecondary : textPrimary,
      decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
      decorationThickness: 2,
    );
  }

  // Toggle le mode de sélection
  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedCourseIds.clear();
      }
    });
  }

  // Sélectionner/déselectionner une course
  void _toggleCourseSelection(String courseId) {
    setState(() {
      if (_selectedCourseIds.contains(courseId)) {
        _selectedCourseIds.remove(courseId);
      } else {
        _selectedCourseIds.add(courseId);
      }
    });
  }

  // Sélectionner toutes les courses
  void _selectAllCourses(List<Course> courses) {
    setState(() {
      _selectedCourseIds.clear();
      for (var course in courses) {
        _selectedCourseIds.add(course.id);
      }
    });
  }

  // Désélectionner toutes les courses
  void _deselectAllCourses() {
    setState(() {
      _selectedCourseIds.clear();
    });
  }

  // Afficher le menu d'actions pour une course
  void _showCourseActions(BuildContext context, Course course) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: Icon(Icons.edit, color: primaryColor),
            title: const Text('Modifier la course'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditCourseScreen(
                    course: course,
                    userId: _userId,
                    service: _service,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.shopping_cart, color: infoColor),
            title: const Text('Commander cette course'),
            onTap: () {
              Navigator.pop(context);
              _navigateToOrderScreen(context, [course]);
            },
          ),
          if (course.status == CourseStatus.done)
            ListTile(
              leading: Icon(Icons.replay, color: warningColor),
              title: const Text('Remettre à "À faire"'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _service.toggleComplete(course.id, false);
                  _showSuccessSnackbar(context, 'Course remise à "À faire"');
                } catch (e) {
                  _showErrorSnackbar(context, 'Erreur: $e');
                }
              },
            )
          else
            ListTile(
              leading: Icon(Icons.check, color: successColor),
              title: const Text('Marquer comme fait'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _service.toggleComplete(course.id, true);
                  _showSuccessSnackbar(context, 'Course marquée comme faite');
                } catch (e) {
                  _showErrorSnackbar(context, 'Erreur: $e');
                }
              },
            ),
          ListTile(
            leading: Icon(Icons.delete, color: errorColor),
            title: const Text('Supprimer'),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(context, course);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Navigation vers l'écran de commande
  void _navigateToOrderScreen(BuildContext context, List<Course> courses) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderScreen(selectedCourses: courses),
      ),
    );
  }

  // Afficher un snackbar d'erreur
  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Afficher un snackbar de succès
  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Calculer le total des courses sélectionnées
  double _calculateSelectedTotal(List<Course> courses) {
    return courses
        .where((course) => _selectedCourseIds.contains(course.id))
        .fold(0.0, (sum, course) => sum + course.amount);
  }

  // Obtenir les cours sélectionnées
  List<Course> _getSelectedCourses(List<Course> allCourses) {
    return allCourses
        .where((course) => _selectedCourseIds.contains(course.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: _selectionMode
            ? Text(
                '${_selectedCourseIds.length} sélectionné${_selectedCourseIds.length > 1 ? 's' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            : const Text(
                'Mes Courses',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        actions: _buildAppBarActions(),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      body: StreamBuilder<List<Course>>(
        stream: _service.coursesStream(
          userId: _userId,
          sortBy: _sortBy,
          descending: _descending,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return _buildLoadingWidget();
          }

          final courses = snapshot.data!;

          if (courses.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              if (_selectionMode && _selectedCourseIds.isNotEmpty)
                _buildSelectionActions(courses),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: courses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _buildCourseCard(context, courses[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Construire les actions de l'app bar
  List<Widget> _buildAppBarActions() {
    if (_selectionMode) {
      return [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _toggleSelectionMode,
          tooltip: 'Annuler la sélection',
        ),
      ];
    } else {
      return [
        PopupMenuButton<String>(
          color: cardColor,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'select':
                setState(() {
                  _selectionMode = true;
                });
                break;
              case 'sort_priority':
                setState(() {
                  _sortBy = 'priority';
                  _descending = true; // Haute priorité d'abord
                });
                break;
              case 'sort_date':
                setState(() {
                  _sortBy = 'dueDate';
                  _descending = false; // Dates proches d'abord
                });
                break;
              case 'sort_created':
                setState(() {
                  _sortBy = 'createdAt';
                  _descending = true; // Récentes d'abord
                });
                break;
              case 'sort_amount':
                setState(() {
                  _sortBy = 'amount';
                  _descending = true; // Plus chères d'abord
                });
                break;
              case 'toggle_order':
                setState(() => _descending = !_descending);
                break;
              case 'show_essential':
                // TODO: Filtrer pour montrer seulement les essentiels
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'select',
              child: Row(
                children: [
                  Icon(Icons.checklist, color: Colors.grey),
                  SizedBox(width: 12),
                  Text('Sélection multiple'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'sort_priority',
              child: Row(
                children: [
                  Icon(Icons.flag,
                      color: _sortBy == 'priority' ? primaryColor : Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    'Trier par priorité',
                    style: TextStyle(
                      color: _sortBy == 'priority' ? primaryColor : null,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'sort_date',
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: _sortBy == 'dueDate' ? primaryColor : Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    'Trier par date limite',
                    style: TextStyle(
                      color: _sortBy == 'dueDate' ? primaryColor : null,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'sort_created',
              child: Row(
                children: [
                  Icon(Icons.access_time,
                      color: _sortBy == 'createdAt' ? primaryColor : Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    'Trier par date de création',
                    style: TextStyle(
                      color: _sortBy == 'createdAt' ? primaryColor : null,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'sort_amount',
              child: Row(
                children: [
                  Icon(Icons.attach_money,
                      color: _sortBy == 'amount' ? primaryColor : Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    'Trier par montant',
                    style: TextStyle(
                      color: _sortBy == 'amount' ? primaryColor : null,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'toggle_order',
              child: Row(
                children: [
                  Icon(
                    _descending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Text(_descending ? 'Ordre décroissant' : 'Ordre croissant'),
                ],
              ),
            ),
          ],
        ),
      ];
    }
  }

  // Construire le floating action button
  Widget? _buildFloatingActionButton() {
    if (_selectionMode) {
      return null;
    }

    return FloatingActionButton(
      backgroundColor: primaryColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.add, size: 28),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AddEditCourseScreen(userId: _userId, service: _service),
        ),
      ),
    );
  }

  // Construire le widget d'erreur
  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: errorColor, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => setState(() {}),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // Construire le widget de chargement
  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 16),
          const Text(
            'Chargement des courses...',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Construire l'état vide
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              color: primaryColor.withOpacity(0.5),
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucune course pour le moment',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ajoutez votre première course en appuyant sur le bouton +',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Construire les actions de sélection
  Widget _buildSelectionActions(List<Course> courses) {
    final selectedTotal = _calculateSelectedTotal(courses);
    final selectedCount = _selectedCourseIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: primaryColor.withOpacity(0.1),
      child: Row(
        children: [
          Checkbox(
            value: selectedCount == courses.length,
            onChanged: (value) {
              if (value == true) {
                _selectAllCourses(courses);
              } else {
                _deselectAllCourses();
              }
            },
            activeColor: primaryColor,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$selectedCount sur ${courses.length} sélectionné(s)',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (selectedCount > 0)
                  Text(
                    'Total: ${selectedTotal.toStringAsFixed(2)} FCFA',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.shopping_cart, color: infoColor),
            onPressed: selectedCount == 0
                ? null
                : () {
                    final selectedCourses = _getSelectedCourses(courses);
                    _navigateToOrderScreen(context, selectedCourses);
                  },
            tooltip: 'Commander les courses sélectionnées',
          ),
          IconButton(
            icon: Icon(Icons.auto_graph, color: warningColor),
            onPressed: selectedCount == 0
                ? null
                : () {
                    _showOptimizationDialog(context, courses);
                  },
            tooltip: 'Optimiser le budget',
          ),
        ],
      ),
    );
  }

  // Afficher le dialogue d'optimisation
  void _showOptimizationDialog(BuildContext context, List<Course> allCourses) {
    final selectedCourses = _getSelectedCourses(allCourses);
    final total = _calculateSelectedTotal(allCourses);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Optimisation Budgétaire'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selectedCourses.length} courses sélectionnées',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Total: ${total.toStringAsFixed(2)} FCFA'),
                const SizedBox(height: 16),
                const Text('Cette fonctionnalité sera bientôt disponible.'),
                const SizedBox(height: 8),
                const Text('Elle permettra de :'),
                const SizedBox(height: 8),
                const Text('• Réduire automatiquement les prix'),
                const Text('• Ajuster les quantités'),
                const Text('• Prioriser les articles essentiels'),
                const Text('• Suggérer des alternatives'),
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

  // Construire la carte d'une course
  Widget _buildCourseCard(BuildContext context, Course course) {
    final isSelected = _selectedCourseIds.contains(course.id);
    final isDone = course.status == CourseStatus.done;

    return GestureDetector(
      onLongPress: () {
        if (!_selectionMode) {
          setState(() {
            _selectionMode = true;
            _selectedCourseIds.add(course.id);
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Card(
          color: isSelected ? primaryColor.withOpacity(0.1) : cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? primaryColor
                  : course.isEssential
                      ? essentialColor.withOpacity(0.3)
                      : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _selectionMode
                ? () => _toggleCourseSelection(course.id)
                : () => _showCourseActions(context, course),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Colonne de gauche : Sélection ou priorité
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) => _toggleCourseSelection(course.id),
                        activeColor: primaryColor,
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          // Indicateur d'article essentiel
                          if (course.isEssential)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: Icon(
                                Icons.star,
                                color: essentialColor,
                                size: 16,
                              ),
                            ),
                          Icon(
                            _getPriorityIcon(course.priority),
                            color: _getPriorityColor(course.priority),
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            course.priority.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _getPriorityColor(course.priority),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Colonne du milieu : Informations
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (course.isEssential && !_selectionMode)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Icon(
                                        Icons.star,
                                        color: essentialColor,
                                        size: 16,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      course.title,
                                      style: _getTextStyle(isDone),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_selectionMode && isDone)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: successColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  'FAIT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: successColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (course.description.isNotEmpty)
                          Text(
                            course.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDone ? textSecondary : textPrimary,
                              fontStyle: FontStyle.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 12),
                        // Section d'informations détaillées
                        Row(
                          children: [
                            // Quantité et unité
                            if (course.quantity > 0)
                              Row(
                                children: [
                                  Icon(
                                    Icons.format_list_numbered,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${course.quantity} ${course.unit}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                            // Prix unitaire
                            if (course.unitPrice > 0)
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${course.unitPrice.toStringAsFixed(2)} FCFA/${course.unit}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                            // Montant total
                            Icon(
                              Icons.calculate,
                              size: 14,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${course.amount.toStringAsFixed(2)} FCFA',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Date limite
                        if (course.dueDate != null)
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Échéance: ${_formatDate(course.dueDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                              // Indicateur de retard
                              if (course.dueDate!.isBefore(DateTime.now()) &&
                                  !isDone)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: errorColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'EN RETARD',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: errorColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Colonne de droite : Statut (mode normal seulement)
                  if (!_selectionMode)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      child: Column(
                        children: [
                          Switch(
                            value: isDone,
                            onChanged: (value) async {
                              try {
                                await _service.toggleComplete(course.id, value);
                                _showSuccessSnackbar(
                                  context,
                                  value
                                      ? 'Course marquée comme faite'
                                      : 'Course remise à "À faire"',
                                );
                              } catch (e) {
                                _showErrorSnackbar(context, 'Erreur: $e');
                              }
                            },
                            activeColor: successColor,
                            activeTrackColor: successColor.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: Icon(
                              Icons.more_vert,
                              color: textSecondary,
                              size: 20,
                            ),
                            onPressed: () =>
                                _showCourseActions(context, course),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Confirmer la suppression d'une course
  Future<void> _confirmDelete(BuildContext context, Course course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: errorColor),
            const SizedBox(width: 12),
            const Text(
              'Supprimer la course',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer "${course.title}" ?\nCette action est irréversible.',
          style: const TextStyle(color: Colors.grey),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteCourse(course.id);
        _showSuccessSnackbar(context, 'Course supprimée avec succès');
      } catch (e) {
        _showErrorSnackbar(context, 'Erreur lors de la suppression: $e');
      }
    }
  }
}