// lib/constants/app_widgets.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_theme.dart';

// Widgets réutilisables

/// Card élégante pour affichage de contenu
class ElegantCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double elevation;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final bool withShadow;

  const ElegantCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacing16),
    this.elevation = 2,
    this.backgroundColor = Colors.white,
    this.onTap,
    this.withShadow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: withShadow ? AppShadows.medium : null,
      ),
      child: child,
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          splashColor: AppColors.tropicalTeal.withOpacity(0.1),
          highlightColor: AppColors.tropicalTeal.withOpacity(0.05),
          child: card,
        ),
      );
    }

    return Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: card,
    );
  }
}

/// Bouton personnalisé avec style app
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double width;
  final bool isOutlined;
  final double borderRadius;

  const AppButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.width = double.infinity,
    this.isOutlined = false,
    this.borderRadius = AppTheme.radiusMedium,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      if (isOutlined) {
        return SizedBox(
          width: width,
          height: AppTheme.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? SizedBox(
                    width: AppTheme.iconSize,
                    height: AppTheme.iconSize,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Icon(icon),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: backgroundColor ?? AppColors.tropicalTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
        );
      } else {
        return SizedBox(
          width: width,
          height: AppTheme.buttonHeight,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? SizedBox(
                    width: AppTheme.iconSize,
                    height: AppTheme.iconSize,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(icon),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor ?? AppColors.tropicalTeal,
              foregroundColor: foregroundColor ?? Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
        );
      }
    } else {
      if (isOutlined) {
        return SizedBox(
          width: width,
          height: AppTheme.buttonHeight,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: backgroundColor ?? AppColors.tropicalTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: AppTheme.iconSize,
                    height: AppTheme.iconSize,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(label),
          ),
        );
      } else {
        return SizedBox(
          width: width,
          height: AppTheme.buttonHeight,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor ?? AppColors.tropicalTeal,
              foregroundColor: foregroundColor ?? Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: AppTheme.iconSize,
                    height: AppTheme.iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(label),
          ),
        );
      }
    }
  }
}

/// Conteneur avec badge
class BadgeContainer extends StatelessWidget {
  final Widget child;
  final String badgeLabel;
  final Color badgeColor;
  final Color badgeTextColor;

  const BadgeContainer({
    Key? key,
    required this.child,
    required this.badgeLabel,
    this.badgeColor = AppColors.warningColor,
    this.badgeTextColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: -8,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing8,
              vertical: AppTheme.spacing4,
            ),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                color: badgeTextColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Badge de statut
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    Key? key,
    required this.label,
    this.backgroundColor = AppColors.tropicalTeal,
    this.textColor = Colors.white,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: backgroundColor.withOpacity(0.3),
          width: AppTheme.borderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: backgroundColor,
            ),
            const SizedBox(width: AppTheme.spacing8),
          ],
          Text(
            label,
            style: TextStyle(
              color: backgroundColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section avec titre
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? actionButton;
  final EdgeInsets padding;

  const SectionHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.actionButton,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTheme.spacing24,
      vertical: AppTheme.spacing16,
    ),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (actionButton != null) actionButton!,
        ],
      ),
    );
  }
}

/// Diviseur personnalisé
class AppDivider extends StatelessWidget {
  final double height;
  final Color color;
  final EdgeInsets padding;

  const AppDivider({
    Key? key,
    this.height = 1,
    this.color = AppColors.mediumGrey,
    this.padding = const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        height: height,
        color: color,
      ),
    );
  }
}

/// Loader centralisé
class AppLoader extends StatelessWidget {
  final String? message;
  final Color color;

  const AppLoader({
    Key? key,
    this.message,
    this.color = AppColors.tropicalTeal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeWidth: 3,
          ),
          if (message != null) ...[
            const SizedBox(height: AppTheme.spacing16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// Message vide
class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  final Color iconColor;

  const EmptyState({
    Key? key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox,
    this.action,
    this.iconColor = AppColors.mediumGrey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: AppTheme.iconSizeXLarge,
            color: iconColor,
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppTheme.spacing8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppTheme.spacing24),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Snackbar personnalisé
void showAppSnackBar(
  BuildContext context, {
  required String message,
  SnackBarType type = SnackBarType.info,
  Duration duration = const Duration(seconds: 3),
  VoidCallback? onUndo,
}) {
  final colors = _getSnackBarColors(type);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(colors['icon'], color: Colors.white, size: 20),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: colors['color'],
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      margin: const EdgeInsets.all(AppTheme.spacing16),
      action: onUndo != null
          ? SnackBarAction(
              label: 'Annuler',
              textColor: Colors.white,
              onPressed: onUndo,
            )
          : null,
    ),
  );
}

enum SnackBarType { success, error, warning, info }

Map<String, dynamic> _getSnackBarColors(SnackBarType type) {
  switch (type) {
    case SnackBarType.success:
      return {'color': AppColors.successColor, 'icon': Icons.check_circle};
    case SnackBarType.error:
      return {'color': AppColors.errorColor, 'icon': Icons.error};
    case SnackBarType.warning:
      return {'color': AppColors.warningColor, 'icon': Icons.warning};
    case SnackBarType.info:
      return {'color': AppColors.infoColor, 'icon': Icons.info};
  }
}

// Extension pour spacing horizontal
extension SizedBoxExtension on num {
  SizedBox get spacingHeight => SizedBox(height: toDouble());
  SizedBox get spacingWidth => SizedBox(width: toDouble());
}
