import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/course_model.dart';
import '../course_service.dart';
import '../gestion_portefeuille/services/portefeuille_service.dart';
import 'add_edit_course_screen.dart';
import '../gestion_boutiques/pages/order_screen.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({Key? key}) : super(key: key);

  @override
  _CourseListScreenState createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  final CourseService _service = CourseService();
  final PortefeuilleService _portefeuilleService = PortefeuilleService();
  String _sortBy = 'priority';
  bool _descending = true; // Par défaut: haute priorité d'abord
  String _selectedMonthKey = _currentMonthKey();
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

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String _formatMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    const monthNames = <String>[
      'Janvier',
      'Fevrier',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Aout',
      'Septembre',
      'Octobre',
      'Novembre',
      'Decembre',
    ];
    final monthIndex = int.tryParse(parts[1]);
    if (monthIndex == null || monthIndex < 1 || monthIndex > 12) {
      return monthKey;
    }
    return '${monthNames[monthIndex - 1]} ${parts[0]}';
  }

  List<String> _extractMonthKeys(List<Course> courses) {
    final monthKeys = courses.map((course) => course.monthKey).toSet().toList();
    monthKeys.sort((a, b) => b.compareTo(a));
    return monthKeys;
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
  void _toggleCourseSelection(String courseId, Course course) {
    // Vérifier si la course est marquée comme faite
    if (course.status == CourseStatus.done) {
      _showErrorSnackbar(
          context, 'Impossible de sélectionner une course déjà faite');
      return;
    }

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
        // Ne sélectionner que les courses qui ne sont pas faites
        if (course.status != CourseStatus.done) {
          _selectedCourseIds.add(course.id);
        }
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
        .where((course) =>
            _selectedCourseIds.contains(course.id) &&
            course.status != CourseStatus.done) // Exclure les courses faites
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
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return _buildLoadingWidget();
          }

          final allCourses = snapshot.data!;
          final monthKeys = _extractMonthKeys(allCourses);
          if (!monthKeys.contains(_selectedMonthKey) && monthKeys.isNotEmpty) {
            _selectedMonthKey = monthKeys.first;
          }
          final courses = allCourses
              .where((course) => course.monthKey == _selectedMonthKey)
              .toList();

          switch (_sortBy) {
            case 'dueDate':
              courses.sort((a, b) {
                final aD = a.dueDate ?? DateTime(2100);
                final bD = b.dueDate ?? DateTime(2100);
                return _descending ? bD.compareTo(aD) : aD.compareTo(bD);
              });
              break;
            case 'createdAt':
              courses.sort((a, b) => _descending
                  ? b.createdAt.compareTo(a.createdAt)
                  : a.createdAt.compareTo(b.createdAt));
              break;
            case 'amount':
              courses.sort((a, b) => _descending
                  ? b.amount.compareTo(a.amount)
                  : a.amount.compareTo(b.amount));
              break;
            case 'priority':
            default:
              courses.sort((a, b) => _descending
                  ? b.priority.index.compareTo(a.priority.index)
                  : a.priority.index.compareTo(b.priority.index));
          }

          if (allCourses.isEmpty) {
            return _buildEmptyState();
          }

          return StreamBuilder<Map<String, dynamic>>(
            stream: _portefeuilleService.getStatsStream(_userId),
            builder: (context, statsSnapshot) {
              final stats = statsSnapshot.data ?? const <String, dynamic>{};
              final monthlyBudget = (stats['monthlyBudget'] as double?) ?? 0.0;
              final remainingBudget =
                  (stats['remainingBudget'] as double?) ?? monthlyBudget;
              final plannedTotal = courses.fold<double>(
                0.0,
                (sum, course) => sum + course.amount,
              );

              return Column(
                children: [
                  _buildMonthSelector(monthKeys),
                  _buildBudgetSummary(
                    monthKey: _selectedMonthKey,
                    monthlyBudget: monthlyBudget,
                    remainingBudget: remainingBudget,
                    plannedTotal: plannedTotal,
                  ),
                  if (_selectionMode && _selectedCourseIds.isNotEmpty)
                    _buildSelectionActions(courses),
                  Expanded(
                    child: courses.isEmpty
                        ? _buildEmptyMonthState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: courses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _buildCourseCard(context, courses[index]),
                          ),
                  ),
                ],
              );
            },
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
                      color:
                          _sortBy == 'priority' ? primaryColor : Colors.grey),
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
                      color:
                          _sortBy == 'createdAt' ? primaryColor : Colors.grey),
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

  Widget _buildEmptyMonthState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: primaryColor.withOpacity(0.45),
              size: 72,
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune course pour ${_formatMonthKey(_selectedMonthKey)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ajoute les courses de ce mois pour mieux suivre ton budget mensuel.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(List<String> monthKeys) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mois de courses',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: monthKeys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final monthKey = monthKeys[index];
                final isSelected = monthKey == _selectedMonthKey;
                return ChoiceChip(
                  label: Text(_formatMonthKey(monthKey)),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedMonthKey = monthKey;
                      _selectedCourseIds.clear();
                      _selectionMode = false;
                    });
                  },
                  selectedColor: primaryColor,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: isSelected ? primaryColor : Colors.grey.shade300,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSummary({
    required String monthKey,
    required double monthlyBudget,
    required double remainingBudget,
    required double plannedTotal,
  }) {
    final isCurrentMonth = monthKey == _currentMonthKey();
    final referenceBudget = isCurrentMonth ? remainingBudget : monthlyBudget;
    final gap = referenceBudget - plannedTotal;
    final isOverBudget = gap < 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverBudget
              ? errorColor.withOpacity(0.25)
              : primaryColor.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resume budget ${_formatMonthKey(monthKey)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBudgetMetric(
                  isCurrentMonth ? 'Budget disponible' : 'Budget mensuel',
                  referenceBudget,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBudgetMetric(
                  'Total prevu',
                  plannedTotal,
                  warningColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBudgetMetric(
                  isOverBudget ? 'Depassement' : 'Ecart',
                  gap.abs(),
                  isOverBudget ? errorColor : successColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetMetric(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${value.toStringAsFixed(0)} FCFA',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Construire les actions de sélection
  Widget _buildSelectionActions(List<Course> courses) {
    final selectedTotal = _calculateSelectedTotal(courses);
    final selectedCount = _selectedCourseIds.length;
    final doneCoursesCount =
        courses.where((c) => c.status == CourseStatus.done).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: primaryColor.withOpacity(0.1),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: selectedCount ==
                    courses.where((c) => c.status != CourseStatus.done).length,
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
                      '$selectedCount sur ${courses.length - doneCoursesCount} sélectionnable(s)',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (selectedCount > 0)
                      Text(
                        '$selectedCount sur ${courses.length - doneCoursesCount} sélectionnable(s)',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
          // Message informatif
          if (doneCoursesCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.info, size: 14, color: infoColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$doneCoursesCount course(s) marquée(s) comme faite(s) ne peuvent pas être sélectionnées',
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Afficher le dialogue d'optimisation
  Future<void> _showOptimizationDialog(
      BuildContext context, List<Course> allCourses) async {
    final selectedCourses = _getSelectedCourses(allCourses);
    final total = selectedCourses.fold<double>(
      0.0,
      (sum, course) => sum + course.amount,
    );

    if (selectedCourses.isEmpty) {
      _showErrorSnackbar(
        context,
        'Selectionne au moins une course a reajuster',
      );
      return;
    }

    final stats = await _portefeuilleService.getStatsStream(_userId).first;
    final monthlyBudget = (stats['monthlyBudget'] as double?) ?? 0.0;
    final remainingBudget = (stats['remainingBudget'] as double?) ?? monthlyBudget;
    final availableBudget = _selectedMonthKey == _currentMonthKey()
        ? remainingBudget
        : monthlyBudget;
    final result = _computeBudgetOptimization(
      selectedCourses,
      availableBudget: availableBudget,
      monthlyBudget: monthlyBudget,
      remainingBudget: remainingBudget,
    );

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
                Text('Mois: ${_formatMonthKey(_selectedMonthKey)}'),
                const SizedBox(height: 6),
                Text('Total actuel: ${total.toStringAsFixed(0)} FCFA'),
                const SizedBox(height: 6),
                Text(
                  _selectedMonthKey == _currentMonthKey()
                      ? 'Budget disponible: ${availableBudget.toStringAsFixed(0)} FCFA'
                      : 'Budget mensuel: ${availableBudget.toStringAsFixed(0)} FCFA',
                ),
                const SizedBox(height: 16),
                if (result.excess <= 0)
                  const Text(
                    'Les courses selectionnees rentrent deja dans le budget.',
                  )
                else ...[
                  Text(
                    'Depassement: ${result.excess.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total apres reajustement: ${result.optimizedTotal.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.unresolvedExcess > 0
                        ? 'Il reste ${result.unresolvedExcess.toStringAsFixed(0)} FCFA impossibles a absorber sans toucher aux articles essentiels.'
                        : 'Le reajustement tient compte des priorites et protege les articles essentiels autant que possible.',
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: result.changes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final change = result.changes[index];
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(change.label),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            if (result.excess > 0 && result.changes.isNotEmpty)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _applyOptimization(result);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Appliquer'),
              ),
          ],
        );
      },
    );
  }

  _BudgetOptimizationResult _computeBudgetOptimization(
    List<Course> selectedCourses, {
    required double availableBudget,
    required double monthlyBudget,
    required double remainingBudget,
  }) {
    final total = selectedCourses.fold<double>(
      0.0,
      (sum, course) => sum + course.amount,
    );
    final excess = total - availableBudget;
    if (excess <= 0) {
      return _BudgetOptimizationResult(
        availableBudget: availableBudget,
        currentTotal: total,
        optimizedTotal: total,
        excess: 0,
        unresolvedExcess: 0,
        changes: const [],
      );
    }

    final courses = List<Course>.from(selectedCourses);
    courses.sort((a, b) {
      final essentialOrder = (a.isEssential ? 1 : 0).compareTo(b.isEssential ? 1 : 0);
      if (essentialOrder != 0) return essentialOrder;
      final priorityOrder = b.priority.order.compareTo(a.priority.order);
      if (priorityOrder != 0) return priorityOrder;
      return b.amount.compareTo(a.amount);
    });

    final changes = <_BudgetChange>[];
    double remainingExcess = excess;

    for (final course in courses) {
      if (remainingExcess <= 0) break;
      final maxRemovableUnits = course.isEssential
          ? (course.quantity - 1).clamp(0, course.quantity)
          : course.quantity;
      if (maxRemovableUnits <= 0) continue;

      final unitPrice = course.unitPrice > 0
          ? course.unitPrice
          : (course.quantity > 0 ? course.amount / course.quantity : course.amount);
      if (unitPrice <= 0) continue;

      final unitsToRemove = (remainingExcess / unitPrice).ceil().clamp(1, maxRemovableUnits);
      final removedAmount = unitsToRemove * unitPrice;
      final newQuantity = course.quantity - unitsToRemove;

      if (newQuantity <= 0) {
        changes.add(
          _BudgetChange(
            course: course,
            newQuantity: 0,
            removedAmount: removedAmount,
            deleteCourse: true,
            label: 'Retirer ${course.title} pour economiser ${removedAmount.toStringAsFixed(0)} FCFA',
          ),
        );
      } else {
        changes.add(
          _BudgetChange(
            course: course,
            newQuantity: newQuantity,
            removedAmount: removedAmount,
            deleteCourse: false,
            label:
                'Reduire ${course.title} de ${course.quantity} a $newQuantity (${removedAmount.toStringAsFixed(0)} FCFA economises)',
          ),
        );
      }

      remainingExcess -= removedAmount;
    }

    final optimizedTotal =
        total - changes.fold<double>(0.0, (sum, change) => sum + change.removedAmount);

    return _BudgetOptimizationResult(
      availableBudget: availableBudget,
      currentTotal: total,
      optimizedTotal: optimizedTotal,
      excess: excess,
      unresolvedExcess: remainingExcess > 0 ? remainingExcess : 0,
      changes: changes,
    );
  }

  Future<void> _applyOptimization(_BudgetOptimizationResult result) async {
    try {
      for (final change in result.changes) {
        if (change.deleteCourse) {
          await _service.deleteCourse(change.course.id);
        } else {
          final updatedCourse = change.course.adjustQuantity(change.newQuantity);
          await _service.updateCourse(change.course.id, updatedCourse);
        }
      }

      if (!mounted) return;
      _selectedCourseIds.clear();
      _selectionMode = false;
      setState(() {});
      _showSuccessSnackbar(
        context,
        result.unresolvedExcess > 0
            ? 'Reajustement applique partiellement'
            : 'Reajustement budgetaire applique',
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar(context, 'Erreur lors du reajustement: $e');
    }
  }

  // Construire la carte d'une course
  Widget _buildCourseCard(BuildContext context, Course course) {
    final isSelected = _selectedCourseIds.contains(course.id);
    final isDone = course.status == CourseStatus.done;

    return GestureDetector(
      onLongPress: () {
        // Ne pas activer le mode sélection sur les courses faites
        if (isDone) {
          _showErrorSnackbar(context,
              'Cette course est déjà faite et ne peut pas être commandée');
          return;
        }

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
          color: isSelected
              ? primaryColor.withOpacity(0.1)
              : isDone
                  ? Colors.grey[100]
                  : cardColor, // Griser les courses faites
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? primaryColor
                  : isDone
                      ? Colors
                          .grey[300]! // Bordure grise pour les courses faites
                      : course.isEssential
                          ? essentialColor.withOpacity(0.3)
                          : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _selectionMode
                ? () {
                    if (isDone) {
                      _showErrorSnackbar(context,
                          'Cette course est déjà faite et ne peut pas être commandée');
                      return;
                    }
                    _toggleCourseSelection(course.id, course);
                  }
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
                        onChanged: isDone
                            ? null // Désactiver pour les courses faites
                            : (value) =>
                                _toggleCourseSelection(course.id, course),
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
                                color: isDone
                                    ? Colors.grey
                                    : essentialColor, // Griser si fait
                                size: 16,
                              ),
                            ),
                          Icon(
                            _getPriorityIcon(course.priority),
                            color: isDone
                                ? Colors.grey
                                : _getPriorityColor(
                                    course.priority), // Griser si fait
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            course.priority.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDone
                                  ? Colors.grey
                                  : _getPriorityColor(
                                      course.priority), // Griser si fait
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
                                        color: isDone
                                            ? Colors.grey
                                            : essentialColor, // Griser si fait
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
                              color: isDone
                                  ? Colors.grey[500]
                                  : textPrimary, // Griser si fait
                              fontStyle: FontStyle.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 12),
                        // Passe sur plusieurs lignes quand l'espace manque.
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (course.quantity > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.format_list_numbered,
                                    size: 14,
                                    color: isDone
                                        ? Colors.grey
                                        : primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${course.quantity} ${course.unit}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDone
                                          ? Colors.grey
                                          : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            if (course.unitPrice > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    size: 14,
                                    color: isDone
                                        ? Colors.grey
                                        : primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${course.unitPrice.toStringAsFixed(2)} FCFA/${course.unit}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDone
                                          ? Colors.grey
                                          : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calculate,
                                  size: 14,
                                  color: isDone
                                      ? Colors.grey
                                      : primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${course.amount.toStringAsFixed(2)} FCFA',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDone
                                        ? Colors.grey
                                        : primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Date limite
                        if (course.dueDate != null)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: isDone
                                    ? Colors.grey
                                    : textSecondary,
                              ),
                              Text(
                                'Échéance: ${_formatDate(course.dueDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDone
                                      ? Colors.grey
                                      : textSecondary,
                                ),
                              ),
                              if (course.dueDate!.isBefore(DateTime.now()) &&
                                  !isDone)
                                Container(
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
                              color: isDone
                                  ? Colors.grey
                                  : textSecondary, // Griser si fait
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

class _BudgetOptimizationResult {
  final double availableBudget;
  final double currentTotal;
  final double optimizedTotal;
  final double excess;
  final double unresolvedExcess;
  final List<_BudgetChange> changes;

  const _BudgetOptimizationResult({
    required this.availableBudget,
    required this.currentTotal,
    required this.optimizedTotal,
    required this.excess,
    required this.unresolvedExcess,
    required this.changes,
  });
}

class _BudgetChange {
  final Course course;
  final int newQuantity;
  final double removedAmount;
  final bool deleteCourse;
  final String label;

  const _BudgetChange({
    required this.course,
    required this.newQuantity,
    required this.removedAmount,
    required this.deleteCourse,
    required this.label,
  });
}
