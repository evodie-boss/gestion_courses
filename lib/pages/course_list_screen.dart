// lib/pages/course_list_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../course_model.dart';
import '../course_service.dart';
import 'add_edit_course_screen.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({Key? key}) : super(key: key);

  @override
  _CourseListScreenState createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  final CourseService _service = CourseService();
  String _sortBy = 'priority';
  bool _descending = false;

  // Palette de couleurs
  static const Color backgroundColor = Color(0xFFEFE9E0); // Beige clair
  static const Color primaryColor = Color(0xFF0F9E99); // Turquoise
  static const Color textPrimary = Color(0xFF1F2937); // Gris foncé
  static const Color textSecondary = Color(0xFF6B7280); // Gris moyen
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF10B981); // Vert émeraude
  static const Color warningColor = Color(0xFFF59E0B); // Orange ambre
  static const Color errorColor = Color(0xFFEF4444); // Rouge

  String get _userId {
    final u = FirebaseAuth.instance.currentUser;
    return u?.uid ?? 'test_user';
  }

  // Méthode pour obtenir la couleur de priorité
  Color _getPriorityColor(CoursePriority priority) {
    switch (priority) {
      case CoursePriority.high:
        return errorColor;
      case CoursePriority.medium:
        return warningColor;
      case CoursePriority.low:
        return successColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: PopupMenuButton<String>(
              color: cardColor,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onSelected: (v) {
                setState(() {
                  if (v == 'priority' || v == 'dueDate' || v == 'createdAt') _sortBy = v;
                  if (v == 'toggleOrder') _descending = !_descending;
                });
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'priority',
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: primaryColor, size: 20),
                      const SizedBox(width: 12),
                      const Text('Par priorité'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'dueDate',
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: primaryColor, size: 20),
                      const SizedBox(width: 12),
                      const Text('Par date limite'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'createdAt',
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: primaryColor, size: 20),
                      const SizedBox(width: 12),
                      const Text('Par création'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'toggleOrder',
                  child: Row(
                    children: [
                      Icon(
                        _descending ? Icons.arrow_upward : Icons.arrow_downward,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(_descending ? 'Ordre croissant' : 'Ordre décroissant'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add, size: 28),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditCourseScreen(
              userId: _userId,
              service: _service,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Course>>(
        stream: _service.coursesStream(
          userId: _userId,
          sortBy: _sortBy,
          descending: _descending,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: errorColor, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur de chargement',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }
          
          if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Chargement des courses...',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final courses = snapshot.data!;
          
          if (courses.isEmpty) {
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
                    Text(
                      'Aucune course pour le moment',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Appuyez sur le bouton + pour ajouter votre première course',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final course = courses[i];
              final isDone = course.status == CourseStatus.done;

              return Container(
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
                  color: cardColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone ? successColor : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Checkbox(
                        value: isDone,
                        activeColor: successColor,
                        shape: const CircleBorder(),
                        onChanged: (val) async {
                          try {
                            await _service.toggleComplete(course.id, val ?? false);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur: $e'),
                                  backgroundColor: errorColor,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDone ? textSecondary : textPrimary,
                              decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                              decorationThickness: 2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(course.priority)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getPriorityColor(course.priority)
                                  .withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            course.priority.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _getPriorityColor(course.priority),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondary,
                              fontStyle: isDone ? FontStyle.italic : FontStyle.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.attach_money,
                                size: 16,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${course.amount.toStringAsFixed(2)} €',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                              const Spacer(),
                              if (course.dueDate != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Échéance: ${course.dueDate!.day}/${course.dueDate!.month}/${course.dueDate!.year}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.1),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.edit, color: primaryColor, size: 20),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddEditCourseScreen(
                                  course: course,
                                  userId: _userId,
                                  service: _service,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: errorColor.withOpacity(0.1),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.delete, color: errorColor, size: 20),
                            onPressed: () => _confirmDelete(context, course),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

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
          'Voulez-vous vraiment supprimer "${course.title}" ? Cette action est irréversible.',
          style: TextStyle(color: textSecondary),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: textSecondary,
            ),
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
      // Sauvegarder une copie pour undo
      final courseCopy = Course(
        id: course.id,
        userId: course.userId,
        title: course.title,
        description: course.description,
        amount: course.amount,
        priority: course.priority,
        status: course.status,
        dueDate: course.dueDate,
        createdAt: course.createdAt,
      );

      try {
        await _service.deleteCourse(course.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Course supprimée avec succès'),
              backgroundColor: primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              action: SnackBarAction(
                label: 'Annuler',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    await _service.addCourse(courseCopy, useServerTimestamp: false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Course restaurée'),
                          backgroundColor: successColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Impossible de restaurer: $e'),
                          backgroundColor: errorColor,
                        ),
                      );
                    }
                  }
                },
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: $e'),
              backgroundColor: errorColor,
            ),
          );
        }
      }
    }
  }
}