import 'dart:async';

import 'package:flutter/material.dart';

import 'core/state/app_controller.dart';
import 'core/state/app_scope.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/services/auth_api.dart';
import 'data/services/device_notifications.dart';
import 'data/services/local_store.dart';
import 'features/auth/auth_gate.dart';
import 'features/notifications/notifications_screen.dart';

class BelAaktunApp extends StatefulWidget {
  const BelAaktunApp({
    super.key,
    this.authApi,
    this.deviceNotifications,
    this.initialThemeMode,
  });

  /// Permite inyectar una API falsa en pruebas y en desarrollo sin backend.
  final AuthApi? authApi;

  final DeviceNotifications? deviceNotifications;

  /// Fija el modo de color (pruebas). Por defecto se usa el claro o el que
  /// haya elegido el usuario.
  final ThemeMode? initialThemeMode;

  @override
  State<BelAaktunApp> createState() => _BelAaktunAppState();
}

class _BelAaktunAppState extends State<BelAaktunApp> {
  late final ThemeController _themeController = ThemeController(
    widget.initialThemeMode ?? ThemeMode.light,
  );
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  AppController? _controller;
  StreamSubscription<String?>? _opens;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final store = await LocalStore.open();
    if (widget.initialThemeMode == null) _themeController.attach(store);
    final controller = await AppController.load(
      authApi: widget.authApi,
      deviceNotifications: widget.deviceNotifications,
      store: store,
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    // Al tocar una notificación del sistema se abre el centro de avisos.
    _opens = controller.notificationOpens.listen((_) {
      final navigator = _navigatorKey.currentState;
      if (navigator == null || !controller.isSignedIn) return;
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
      );
    });
    controller.onRestartRequested = _restart;
    setState(() => _controller = controller);
  }

  /// Vuelve a cargar todo (por ejemplo, al conectar el servidor de pruebas).
  Future<void> _restart() async {
    final old = _controller;
    await _opens?.cancel();
    _opens = null;
    setState(() => _controller = null);
    // Se libera después del cuadro para no romper widgets que aún lo leen.
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    await _boot();
  }

  @override
  void dispose() {
    _opens?.cancel();
    _controller?.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return MaterialApp(
        title: 'Bel-Aaktun',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeController.mode,
        home: const _BootScreen(),
      );
    }

    return AppScope(
      controller: controller,
      child: ThemeScope(
        controller: _themeController,
        child: AnimatedBuilder(
          animation: _themeController,
          builder: (context, _) {
            return MaterialApp(
              navigatorKey: _navigatorKey,
              title: 'Bel-Aaktun',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: _themeController.mode,
              themeAnimationDuration: const Duration(milliseconds: 320),
              themeAnimationCurve: Curves.easeOutCubic,
              home: const AuthGate(),
              builder: (context, child) {
                // Limita el tamaño del texto del sistema para no romper el ritmo
                // tipográfico en pantallas pequeñas.
                final scaler = MediaQuery.textScalerOf(context)
                    .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: scaler),
                  child: _SyncBanner(child: child ?? const SizedBox.shrink()),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bel·Aaktun',
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Franja de aviso cuando el servidor de pruebas no responde.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final offline = app.isSharedMode && !app.syncOnline;
    if (!offline) return child;
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.error,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin conexión con el servidor de pruebas. Revisa el WiFi.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
