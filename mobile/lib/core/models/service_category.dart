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
  blacksmith;

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
  };
}
