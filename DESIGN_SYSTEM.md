# 🎨 Guide de Style - Gestion Courses

## Palette de Couleurs Coordonnée

### Couleurs Principales
- **Teal Principal** : `#0F9E99` (AppColors.tropicalTeal)
- **Ivoire Principal** : `#EFE9E0` (AppColors.softIvory)
- **Or Principal** : `#F5B041` (AppColors.accentColor)
- **Texte Principal** : `#1F2937` (AppColors.textColor)

### Nuances Teal
- Teal Foncé : `#0A7A73` (AppColors.tealDark)
- Teal Clair : `#16B6AD` (AppColors.tealLight)
- Teal Très Clair : `#E8F8F7` (AppColors.tealVeryLight)

### Nuances Ivoire
- Ivoire Foncé : `#DED6CC` (AppColors.ivoryDark)
- Ivoire Clair : `#F5F1EB` (AppColors.ivoryLight)

### Nuances Or
- Or Foncé : `#D4941E` (AppColors.accentDark)
- Or Clair : `#FDD787` (AppColors.accentLight)

### Statuts
- ✅ Succès : `#10B981` (AppColors.successColor)
- ⚠️ Avertissement : `#F59E0B` (AppColors.warningColor)
- ❌ Erreur : `#EF4444` (AppColors.errorColor)
- ℹ️ Info : `#3B82F6` (AppColors.infoColor)

### Gris
- Gris Clair : `#F5F5F5` (AppColors.lightGrey)
- Gris Moyen : `#D1D5DB` (AppColors.mediumGrey)
- Gris Foncé : `#6B7280` (AppColors.darkGrey)
- Gris Très Foncé : `#4B5563` (AppColors.veryDarkGrey)

---

## Espacements Standardisés

```dart
AppTheme.spacing4  = 4.0    // Très petit
AppTheme.spacing8  = 8.0    // Petit
AppTheme.spacing12 = 12.0   // Petit-moyen
AppTheme.spacing16 = 16.0   // Standard
AppTheme.spacing20 = 20.0   // Moyen
AppTheme.spacing24 = 24.0   // Grand
AppTheme.spacing32 = 32.0   // Très grand
AppTheme.spacing40 = 40.0   // Énorme
```

---

## Rayons de Bordure

```dart
AppTheme.radiusSmall   = 8.0      // Boutons, petits éléments
AppTheme.radiusMedium  = 12.0     // Cards, inputs (PAR DÉFAUT)
AppTheme.radiusLarge   = 20.0     // Modals, sections
AppTheme.radiusXLarge  = 28.0     // Grands éléments
```

---

## Typographie

### Titres
```dart
Text('Très grand titre', style: Theme.of(context).textTheme.displayLarge)     // 32px, bold
Text('Grand titre', style: Theme.of(context).textTheme.displayMedium)         // 28px, bold
Text('Titre', style: Theme.of(context).textTheme.headlineLarge)               // 20px, bold
Text('Sous-titre', style: Theme.of(context).textTheme.headlineSmall)          // 16px, 600w
```

### Corps de Texte
```dart
Text('Corps large', style: Theme.of(context).textTheme.bodyLarge)             // 16px, normal
Text('Corps moyen', style: Theme.of(context).textTheme.bodyMedium)            // 14px, normal
Text('Corps petit', style: Theme.of(context).textTheme.bodySmall)             // 12px, gris
```

### Labels
```dart
Text('Label', style: Theme.of(context).textTheme.labelLarge)                  // 14px, 500w
Text('Petit label', style: Theme.of(context).textTheme.labelSmall)            // 11px, 500w
```

---

## Ombres Prédéfinies

### Subtiles (Cards légères)
```dart
AppShadows.subtle
// Blur: 4, Offset: (0, 2)
```

### Moyennes (Cards standards)
```dart
AppShadows.medium
// Blur: 12, Offset: (0, 4)
```

### Grandes (Modals, Popovers)
```dart
AppShadows.large
// Blur: 20, Spread: 4, Offset: (0, 8)
```

### Avec Couleur Personnalisée
```dart
AppShadows.coloredMedium(AppColors.tropicalTeal)
// Ombre en couleur teal moyen
```

---

## Gradients

### Principal vers Accent
```dart
Container(
  decoration: BoxDecoration(
    gradient: AppGradients.primaryToAccent,
  ),
)
```

### Teal (léger)
```dart
AppGradients.tealTint
```

### Arrière-plan
```dart
AppGradients.background
```

---

## Widgets Réutilisables

### ElegantCard
```dart
ElegantCard(
  child: Text('Contenu'),
  padding: const EdgeInsets.all(AppTheme.spacing16),
  onTap: () { },
  withShadow: true,
)
```

### AppButton
```dart
// Button simple
AppButton(
  label: 'Valider',
  onPressed: () { },
)

// Button avec icône
AppButton.icon(
  label: 'Ajouter',
  icon: Icons.add,
  onPressed: () { },
)

// Button outline
AppButton(
  label: 'Annuler',
  onPressed: () { },
  isOutlined: true,
)

// Avec chargement
AppButton(
  label: 'Charger',
  onPressed: () { },
  isLoading: true,
)
```

### StatusBadge
```dart
StatusBadge(
  label: 'En cours',
  backgroundColor: AppColors.warningColor,
  icon: Icons.hourglass_bottom,
)
```

### SectionHeader
```dart
SectionHeader(
  title: 'Boutiques Récentes',
  subtitle: '5 boutiques trouvées',
  actionButton: GestureDetector(
    onTap: () { },
    child: Text('Voir tout'),
  ),
)
```

### EmptyState
```dart
EmptyState(
  title: 'Aucun résultat',
  subtitle: 'Essayez une autre recherche',
  icon: Icons.search,
  action: AppButton(
    label: 'Nouvelle recherche',
    onPressed: () { },
  ),
)
```

### AppLoader
```dart
AppLoader(
  message: 'Chargement en cours...',
  color: AppColors.tropicalTeal,
)
```

---

## Animations

### Durées
```dart
AppAnimations.fast      = 200ms    // UI rapide
AppAnimations.normal    = 300ms    // Standard
AppAnimations.slow      = 500ms    // Contenu
AppAnimations.verySlow  = 800ms    // Entrées
```

### Courbes
```dart
AppCurves.smooth        = easeInOut // Standard
AppCurves.easeIn        = easeIn    // Entrée
AppCurves.easeOut       = easeOut   // Sortie
AppCurves.bouncy        = elasticOut // Rebond
```

---

## Snackbars

```dart
// Succès
showAppSnackBar(
  context,
  message: 'Opération réussie!',
  type: SnackBarType.success,
)

// Erreur
showAppSnackBar(
  context,
  message: 'Une erreur est survenue',
  type: SnackBarType.error,
)

// Avertissement
showAppSnackBar(
  context,
  message: 'Attention: Action irréversible',
  type: SnackBarType.warning,
)

// Info
showAppSnackBar(
  context,
  message: 'Information',
  type: SnackBarType.info,
)
```

---

## Bonnes Pratiques

### ✅ À Faire

1. **Utiliser les constantes de spacing**
   ```dart
   Padding(
     padding: const EdgeInsets.all(AppTheme.spacing16),
     child: ...
   )
   ```

2. **Utiliser les styles de texte du thème**
   ```dart
   Text(
     'Titre',
     style: Theme.of(context).textTheme.headlineMedium,
   )
   ```

3. **Utiliser les couleurs centralisées**
   ```dart
   Container(
     color: AppColors.tropicalTeal,
   )
   ```

4. **Utiliser les widgets réutilisables**
   ```dart
   ElegantCard(child: ...)
   StatusBadge(label: ...)
   ```

5. **Respecter les rayons de bordure standards**
   ```dart
   BorderRadius.circular(AppTheme.radiusMedium)
   ```

### ❌ À Éviter

1. ❌ Hardcoder des espacements
   ```dart
   // MAUVAIS
   Padding(padding: const EdgeInsets.all(16), ...)
   ```

2. ❌ Hardcoder des couleurs
   ```dart
   // MAUVAIS
   Container(color: Color(0xFF0F9E99), ...)
   ```

3. ❌ Créer de nouvelles TextStyles
   ```dart
   // MAUVAIS
   TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
   ```

4. ❌ Mélanger les rayons de bordure
   ```dart
   // MAUVAIS
   BorderRadius.circular(15)  // Utiliser radiusLarge
   ```

5. ❌ Dupliquer des designs de widgets

---

## Migration vers le Nouveau Design System

### Avant (❌ Ancien)
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
      ),
    ],
  ),
  child: Text(
    'Titre',
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1F2937),
    ),
  ),
)
```

### Après (✅ Nouveau)
```dart
ElegantCard(
  padding: const EdgeInsets.all(AppTheme.spacing16),
  withShadow: true,
  child: Text(
    'Titre',
    style: Theme.of(context).textTheme.headlineSmall,
  ),
)
```

---

## Fichiers Disponibles

- **`lib/constants/app_colors.dart`** - Toutes les couleurs
- **`lib/constants/app_theme.dart`** - Theme Flutter + styles
- **`lib/constants/app_widgets.dart`** - Widgets réutilisables

---

## Support

Pour toute question de design ou d'intégration, consulter les fichiers constants ou tester dans le projet.

**Design System Version**: 1.0.0
**Dernière mise à jour**: Décembre 2025
