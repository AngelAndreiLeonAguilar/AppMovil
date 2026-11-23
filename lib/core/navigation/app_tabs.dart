/// Identificadores de las pestañas del shell.
abstract final class AppTabs {
  static const int home = 0;
  static const int catalog = 1;
  static const int map = 2;
  static const int artisans = 3;
  static const int booking = 4;
}

/// Cambia de pestaña desde cualquier pantalla hija.
typedef SelectTab = void Function(int index);
