import 'package:flutter/material.dart';

import '../../data/services/local_store.dart';

/// Controla el modo de color de la aplicación.
///
/// La app arranca siempre en modo claro; si el usuario elige el modo oscuro
/// se recuerda su preferencia en el teléfono.
class ThemeController extends ChangeNotifier {
  ThemeController([ThemeMode initial = ThemeMode.light]) : _mode = initial;

  static const _key = 'theme.mode';

  ThemeMode _mode;
  LocalStore? _store;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  /// Lee la preferencia guardada y la conserva en adelante.
  void attach(LocalStore store) {
    _store = store;
    final saved = store.read(_key);
    final mode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    if (mode != _mode) {
      _mode = mode;
      notifyListeners();
    }
  }

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _store?.write(_key, mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  void toggle() {
    setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// Expone el [ThemeController] a todo el árbol de widgets.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope no encontrado en el árbol de widgets.');
    return scope!.notifier!;
  }

  /// Igual que [of] pero sin registrar dependencia (para callbacks).
  static ThemeController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope no encontrado en el árbol de widgets.');
    return scope!.notifier!;
  }
}
