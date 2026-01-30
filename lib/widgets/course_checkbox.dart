// lib/widgets/course_checkbox.dart
import 'package:flutter/material.dart';
import '../models/course_model.dart';

// Constantes de couleur partagées
class CourseCheckboxColors {
  static const Color backgroundColor = Color(0xFFEFE9E0); // Beige clair
  static const Color primaryColor = Color(0xFF0F9E99); // Turquoise
  static const Color textPrimary = Color(0xFF1F2937); // Gris foncé
  static const Color textSecondary = Color(0xFF6B7280); // Gris moyen
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF10B981); // Vert émeraude
  static const Color errorColor = Color(0xFFEF4444); // Rouge
  static const Color warningColor = Color(0xFFF59E0B); // Orange ambre
}

class CourseCheckbox extends StatelessWidget {
  final CourseStatus status;
  final ValueChanged<bool?>? onChanged;
  final double size;

  const CourseCheckbox({
    required this.status,
    this.onChanged,
    this.size = 24.0,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDone = status == CourseStatus.done;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDone ? CourseCheckboxColors.successColor : Colors.grey[300]!,
          width: 2,
        ),
        gradient: isDone
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CourseCheckboxColors.successColor.withOpacity(0.9),
                  CourseCheckboxColors.successColor.withOpacity(0.7),
                ],
              )
            : null,
        boxShadow: isDone
            ? [
                BoxShadow(
                  color: CourseCheckboxColors.successColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onChanged != null ? () => onChanged!(!isDone) : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: isDone
                  ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: size * 0.6,
                      key: const ValueKey('checked'),
                    )
                  : Container(
                      key: const ValueKey('unchecked'),
                      width: size * 0.6,
                      height: size * 0.6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// Variante avec animation de pulsation pour les tâches importantes
class AnimatedCourseCheckbox extends StatefulWidget {
  final CourseStatus status;
  final ValueChanged<bool?>? onChanged;
  final double size;
  final bool animate; // Pour animer les tâches importantes non terminées

  const AnimatedCourseCheckbox({
    required this.status,
    this.onChanged,
    this.size = 24.0,
    this.animate = false,
    Key? key,
  }) : super(key: key);

  @override
  _AnimatedCourseCheckboxState createState() => _AnimatedCourseCheckboxState();
}

class _AnimatedCourseCheckboxState extends State<AnimatedCourseCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _animation = TweenSequence<double>(
      [
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.2),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.2, end: 1.0),
          weight: 50,
        ),
      ],
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.animate && widget.status != CourseStatus.done) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedCourseCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && widget.status != CourseStatus.done) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.animate && widget.status != CourseStatus.done
              ? _animation.value
              : 1.0,
          child: CourseCheckbox(
            status: widget.status,
            onChanged: widget.onChanged,
            size: widget.size,
          ),
        );
      },
    );
  }
}

// Variante avec label (pour les listes simples)
class LabeledCourseCheckbox extends StatelessWidget {
  final String label;
  final CourseStatus status;
  final ValueChanged<bool?>? onChanged;
  final TextStyle? labelStyle;
  final bool showDivider;

  const LabeledCourseCheckbox({
    required this.label,
    required this.status,
    this.onChanged,
    this.labelStyle,
    this.showDivider = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            CourseCheckbox(
              status: status,
              onChanged: onChanged,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: labelStyle ?? TextStyle(
                  fontSize: 16,
                  color: CourseCheckboxColors.textPrimary,
                  decoration: status == CourseStatus.done
                      ? TextDecoration.lineThrough
                      : null,
                  decorationThickness: 2,
                  decorationColor: CourseCheckboxColors.successColor.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Divider(
              height: 1,
              color: Colors.grey[300],
              thickness: 0.5,
            ),
          ),
      ],
    );
  }
}

// Variante circulaire minimaliste
class CircularCourseCheckbox extends StatelessWidget {
  final CourseStatus status;
  final ValueChanged<bool?>? onChanged;
  final double size;

  const CircularCourseCheckbox({
    required this.status,
    this.onChanged,
    this.size = 32.0,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDone = status == CourseStatus.done;
    
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!isDone) : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDone ? CourseCheckboxColors.successColor : Colors.transparent,
          border: Border.all(
            color: isDone ? CourseCheckboxColors.successColor : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: Center(
          child: isDone
              ? Icon(
                  Icons.check,
                  color: Colors.white,
                  size: size * 0.5,
                )
              : null,
        ),
      ),
    );
  }
}