/// Version embarquée de l'application, affichée dans l'écran « À propos ».
///
/// Valeur par défaut = ligne \`version:\` du pubspec.yaml ; la CI la régénère
/// au moment du build (même valeur que celle écrite dans le pubspec, donc
/// dans la versionName/versionCode de l'APK : ex. \`0.2.0-pr8+25\` en PR,
/// \`0.2.0+25\` sur main).
const String kVersionApp = '0.3.4+7';