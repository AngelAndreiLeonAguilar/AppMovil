import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/user.dart';
import '../admin/admin_screen.dart';
import '../artisan/artisan_shell.dart';
import '../shell/app_shell.dart';
import 'application_status_screen.dart';
import 'login_screen.dart';

/// Decide qué mostrar según la sesión, el rol y el estado de verificación.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Permite al turista explorar mientras su solicitud está en revisión.
  bool _exploring = false;

  @override
  Widget build(BuildContext context) {
    final app = context.app;

    if (!app.isReady) return const _BootScreen();

    final user = app.user;
    if (user == null) return const LoginScreen();

    if (user.role == UserRole.admin) return const AdminScreen();
    if (user.role == UserRole.artisan) return const ArtisanShell();

    if (app.hasPendingApplication && !_exploring) {
      return ApplicationStatusScreen(
        onExplore: () => setState(() => _exploring = true),
      );
    }

    return const AppShell();
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bel·Aaktun',
              style: context.texts.displaySmall?.copyWith(fontSize: 34),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Preparando tu sesión…',
              style: context.texts.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
