// lib/widgets/course_tile.dart
import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../course_service.dart';
import '../pages/add_edit_course_screen.dart';
import './course_checkbox.dart';

class CourseTile extends StatelessWidget {
  final Course course;
  final CourseService service;
  final bool showActions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CourseTile({
    required this.course,
    required this.service,
    this.showActions = true,
    this.onTap,
    this.onLongPress,
    Key? key,
  }) : super(key: key);

  // Palette de couleurs
  static const Color backgroundColor = Color(0xFFEFE9E0);
  static const Color primaryColor = Color(0xFF0F9E99);
  static const Color accentColor = Color(0xFF0F9E99);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);

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
    final isDone = course.status == CourseStatus.done;

    return Dismissible(
      key: ValueKey(course.id),
      direction: DismissDirection.horizontal,
      background: _buildDismissBackground(),
      secondaryBackground: _buildDismissSecondaryBackground(),
      confirmDismiss: (direction) => _confirmDismiss(context, direction),
      onDismissed: (direction) => _handleDismiss(context, direction),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Card(
            color: cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDone ? successColor.withOpacity(0.2) : Colors.grey[200]!,
                width: isDone ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox personnalisé
                  CourseCheckbox(
                    status: course.status,
                    onChanged: (val) async {
                      try {
                        await service.toggleComplete(course.id, val ?? false);
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

                  const SizedBox(width: 16),

                  // Contenu principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête avec titre et priorité
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                course.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDone ? textSecondary : textPrimary,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  decorationThickness: 2,
                                  decorationColor: successColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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

                        const SizedBox(height: 8),

                        // Description
                        if (course.description.isNotEmpty)
                          Text(
                            course.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDone
                                  ? textSecondary.withOpacity(0.6)
                                  : textSecondary,
                              fontStyle: isDone ? FontStyle.italic : FontStyle.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                        const SizedBox(height: 12),

                        // Métadonnées
                        _buildMetadata(context),
                      ],
                    ),
                  ),

                  // Boutons d'action (optionnel)
                  if (showActions) ...[
                    const SizedBox(width: 12),
                    Column(
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
                                  service: service,
                                  userId: course.userId,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (course.dueDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Tooltip(
                              message: 'Échéance: ${_formatDate(course.dueDate!)}',
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getDueDateColor(course.dueDate!).withOpacity(0.1),
                                ),
                                child: Icon(
                                  Icons.access_time,
                                  color: _getDueDateColor(course.dueDate!),
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context) {
    final isDone = course.status == CourseStatus.done;
    final now = DateTime.now();
    final dueSoon = course.dueDate != null &&
        course.dueDate!.difference(now).inDays <= 2 &&
        course.dueDate!.difference(now).inDays >= 0;

    return Row(
      children: [
        // Montant
        Row(
          children: [
            Icon(
              Icons.euro_symbol,
              size: 14,
              color: isDone ? successColor : primaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              '${course.amount.toStringAsFixed(2)} €',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDone ? successColor : primaryColor,
              ),
            ),
          ],
        ),

        const SizedBox(width: 16),

        // Date de création (non-nullable donc pas de check)
        Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: textSecondary),
            const SizedBox(width: 4),
            Text(
              _formatDate(course.createdAt),
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ),
        const SizedBox(width: 16),

        // Indicateur "Échéance proche"
        if (dueSoon && !isDone)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: warningColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, size: 12, color: warningColor),
                const SizedBox(width: 4),
                Text(
                  'Bientôt',
                  style: TextStyle(
                    fontSize: 10,
                    color: warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      decoration: BoxDecoration(
        color: successColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Icon(Icons.check_circle, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            'Marquer comme terminé',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissSecondaryBackground() {
    return Container(
      decoration: BoxDecoration(
        color: errorColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Supprimer',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.delete_forever, color: Colors.white, size: 24),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Future<bool?> _confirmDismiss(
      BuildContext context, DismissDirection direction) async {
    if (direction == DismissDirection.startToEnd) {
      return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Marquer comme terminé'),
          content: Text('Marquer "${course.title}" comme terminé ?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: successColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Terminer'),
            ),
          ],
        ),
      );
    } else {
      return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Supprimer la course'),
          content: Text('Voulez-vous vraiment supprimer "${course.title}" ?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: errorColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleDismiss(
      BuildContext context, DismissDirection direction) async {
    if (direction == DismissDirection.startToEnd) {
      try {
        await service.toggleComplete(course.id, true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${course.title}" marqué comme terminé'),
              backgroundColor: successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              action: SnackBarAction(
                label: 'Annuler',
                onPressed: () async {
                  try {
                    await service.toggleComplete(course.id, false);
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
              duration: const Duration(seconds: 4),
            ),
          );
        }
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
    } else {
      Course? backup;
      try {
        backup = await service.deleteCourseWithBackup(course.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${course.title}" supprimé'),
              backgroundColor: primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              action: SnackBarAction(
                label: 'Annuler',
                onPressed: () async {
                  if (backup != null) {
                    try {
                      await service.restoreCourse(backup);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${course.title}" restauré'),
                            backgroundColor: successColor,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return "Aujourd'hui";
    } else if (dateDay == yesterday) {
      return 'Hier';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getDueDateColor(DateTime dueDate) {
    final now = DateTime.now();
    final daysDifference = dueDate.difference(now).inDays;

    if (daysDifference < 0) {
      return errorColor; // En retard
    } else if (daysDifference == 0) {
      return warningColor; // Aujourd'hui
    } else if (daysDifference <= 2) {
      return warningColor; // Bientôt
    } else {
      return successColor; // Dans le futur
    }
  }
}
