import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

enum ServiceCategory {
  plumber,
  electrician,
  acRepair,
  cleaning,
  carpenter,
  mechanic,
  painter,
  aluminumWork,
  cameraInstallation,
  tvInstallation,
  satelliteInstallation,
  construction,
  blacksmith,
  housekeeping,
  homeTutoring;

  String get label => switch (this) {
    ServiceCategory.plumber => 'Plombier',
    ServiceCategory.electrician => 'Électricien',
    ServiceCategory.acRepair => 'Climatisation',
    ServiceCategory.cleaning => 'Nettoyage',
    ServiceCategory.carpenter => 'Menuisier',
    ServiceCategory.mechanic => 'Mécanicien',
    ServiceCategory.painter => 'Peintre',
    ServiceCategory.aluminumWork => 'Aluminium',
    ServiceCategory.cameraInstallation => 'Caméras',
    ServiceCategory.tvInstallation => 'Installation TV',
    ServiceCategory.satelliteInstallation => 'Satellite',
    ServiceCategory.construction => 'Construction',
    ServiceCategory.blacksmith => 'Forgeron',
    ServiceCategory.housekeeping => 'Femme de ménage',
    ServiceCategory.homeTutoring => 'Cours à domicile',
  };

  // Matches the backend's service_category_enum string values.
  String get wireValue => switch (this) {
    ServiceCategory.plumber => 'plumber',
    ServiceCategory.electrician => 'electrician',
    ServiceCategory.acRepair => 'ac_repair',
    ServiceCategory.cleaning => 'cleaning',
    ServiceCategory.carpenter => 'carpenter',
    ServiceCategory.mechanic => 'mechanic',
    ServiceCategory.painter => 'painter',
    ServiceCategory.aluminumWork => 'aluminum_work',
    ServiceCategory.cameraInstallation => 'camera_installation',
    ServiceCategory.tvInstallation => 'tv_installation',
    ServiceCategory.satelliteInstallation => 'satellite_installation',
    ServiceCategory.construction => 'construction',
    ServiceCategory.blacksmith => 'blacksmith',
    ServiceCategory.housekeeping => 'housekeeping',
    ServiceCategory.homeTutoring => 'home_tutoring',
  };

  String get description => switch (this) {
    ServiceCategory.plumber =>
      'Réparation de fuites, plomberie sanitaire, installation de robinetterie et de chauffe-eau.',
    ServiceCategory.electrician =>
      'Installation électrique, dépannage de pannes et mise aux normes des tableaux électriques.',
    ServiceCategory.acRepair =>
      'Installation, entretien et réparation de climatiseurs et systèmes de ventilation.',
    ServiceCategory.cleaning =>
      'Nettoyage résidentiel et professionnel, entretien régulier ou ménage en profondeur.',
    ServiceCategory.carpenter =>
      'Fabrication et réparation de meubles, portes, fenêtres et aménagements en bois.',
    ServiceCategory.mechanic =>
      'Entretien et réparation automobile, diagnostic de pannes et changement de pièces.',
    ServiceCategory.painter =>
      'Peinture intérieure et extérieure, enduits et finitions murales.',
    ServiceCategory.aluminumWork =>
      'Fabrication et pose de fenêtres, portes et structures en aluminium.',
    ServiceCategory.cameraInstallation =>
      'Installation et configuration de caméras de surveillance et systèmes de sécurité.',
    ServiceCategory.tvInstallation =>
      'Installation murale et configuration de téléviseurs et systèmes audio/vidéo.',
    ServiceCategory.satelliteInstallation =>
      "Installation et réglage d'antennes satellites et de récepteurs TV.",
    ServiceCategory.construction =>
      'Travaux de construction, maçonnerie et rénovation de bâtiments.',
    ServiceCategory.blacksmith =>
      'Fabrication et réparation de portails, grilles et structures métalliques.',
    ServiceCategory.housekeeping =>
      'Ménage à domicile, repassage et entretien courant du foyer.',
    ServiceCategory.homeTutoring =>
      'Cours particuliers à domicile pour tous niveaux et matières.',
  };

  IconData get icon => switch (this) {
    ServiceCategory.plumber => Icons.plumbing_rounded,
    ServiceCategory.electrician => Icons.electrical_services_rounded,
    ServiceCategory.acRepair => Icons.ac_unit_rounded,
    ServiceCategory.cleaning => Icons.cleaning_services_rounded,
    ServiceCategory.carpenter => Icons.carpenter_rounded,
    ServiceCategory.mechanic => Icons.car_repair_rounded,
    ServiceCategory.painter => Icons.format_paint_rounded,
    ServiceCategory.aluminumWork => Icons.window_rounded,
    ServiceCategory.cameraInstallation => Icons.videocam_rounded,
    ServiceCategory.tvInstallation => Icons.tv_rounded,
    ServiceCategory.satelliteInstallation => Icons.satellite_alt_rounded,
    ServiceCategory.construction => Icons.construction_rounded,
    ServiceCategory.blacksmith => Icons.hardware_rounded,
    ServiceCategory.housekeeping => Icons.local_laundry_service_rounded,
    ServiceCategory.homeTutoring => Icons.school_rounded,
  };
}

// Localized counterparts to .label/.description above — kept as a separate
// extension (rather than replacing those getters outright) since dozens of
// call sites across the app aren't migrated to AppLocalizations yet; each
// screen switches to these only as its own turn comes up. See registration
// screen migration notes for why .label/.description themselves stay as
// French literals in the meantime rather than becoming a half-measure.
extension ServiceCategoryLocalization on ServiceCategory {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    ServiceCategory.plumber => l10n.categoryPlumberLabel,
    ServiceCategory.electrician => l10n.categoryElectricianLabel,
    ServiceCategory.acRepair => l10n.categoryAcRepairLabel,
    ServiceCategory.cleaning => l10n.categoryCleaningLabel,
    ServiceCategory.carpenter => l10n.categoryCarpenterLabel,
    ServiceCategory.mechanic => l10n.categoryMechanicLabel,
    ServiceCategory.painter => l10n.categoryPainterLabel,
    ServiceCategory.aluminumWork => l10n.categoryAluminumWorkLabel,
    ServiceCategory.cameraInstallation => l10n.categoryCameraInstallationLabel,
    ServiceCategory.tvInstallation => l10n.categoryTvInstallationLabel,
    ServiceCategory.satelliteInstallation =>
      l10n.categorySatelliteInstallationLabel,
    ServiceCategory.construction => l10n.categoryConstructionLabel,
    ServiceCategory.blacksmith => l10n.categoryBlacksmithLabel,
    ServiceCategory.housekeeping => l10n.categoryHousekeepingLabel,
    ServiceCategory.homeTutoring => l10n.categoryHomeTutoringLabel,
  };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
    ServiceCategory.plumber => l10n.categoryPlumberDescription,
    ServiceCategory.electrician => l10n.categoryElectricianDescription,
    ServiceCategory.acRepair => l10n.categoryAcRepairDescription,
    ServiceCategory.cleaning => l10n.categoryCleaningDescription,
    ServiceCategory.carpenter => l10n.categoryCarpenterDescription,
    ServiceCategory.mechanic => l10n.categoryMechanicDescription,
    ServiceCategory.painter => l10n.categoryPainterDescription,
    ServiceCategory.aluminumWork => l10n.categoryAluminumWorkDescription,
    ServiceCategory.cameraInstallation =>
      l10n.categoryCameraInstallationDescription,
    ServiceCategory.tvInstallation => l10n.categoryTvInstallationDescription,
    ServiceCategory.satelliteInstallation =>
      l10n.categorySatelliteInstallationDescription,
    ServiceCategory.construction => l10n.categoryConstructionDescription,
    ServiceCategory.blacksmith => l10n.categoryBlacksmithDescription,
    ServiceCategory.housekeeping => l10n.categoryHousekeepingDescription,
    ServiceCategory.homeTutoring => l10n.categoryHomeTutoringDescription,
  };
}
