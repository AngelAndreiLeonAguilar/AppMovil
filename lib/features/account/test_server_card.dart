import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_surface.dart';
import '../../data/services/sync_store.dart';

/// Estado y configuración del servidor de pruebas en la red local.
///
/// Solo aparece en la versión sin backend real.
class TestServerCard extends StatelessWidget {
  const TestServerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isLocalMode && !app.isSharedMode) return const SizedBox.shrink();
    final palette = context.palette;
    final shared = app.isSharedMode;
    final online = app.syncOnline;
    final color = !shared
        ? palette.textMuted
        : (online ? const Color(0xFF4E7A5A) : context.colors.error);

    return BelSurface(
      padding: const EdgeInsets.all(Insets.md),
      onTap: () => showTestServerDialog(context),
      child: Row(
        children: [
          Icon(
            shared
                ? (online ? Icons.wifi_rounded : Icons.wifi_off_rounded)
                : Icons.phone_android_rounded,
            color: color,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SERVIDOR DE PRUEBAS',
                  style: context.texts.labelSmall?.copyWith(
                    color: palette.textFaint,
                    letterSpacing: 1.6,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shared
                      ? (online
                            ? 'Conectado · ${app.syncUrl}'
                            : 'Sin conexión · ${app.syncUrl}')
                      : (app.syncError != null
                            ? 'No se pudo conectar. Toca para revisar.'
                            : 'Sin servidor: los datos se quedan en este '
                                  'teléfono'),
                  style: context.texts.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Text(
            shared ? 'Cambiar' : 'Conectar',
            style: context.texts.labelLarge?.copyWith(
              color: context.colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo para escribir, probar y guardar la IP del servidor.
Future<void> showTestServerDialog(BuildContext context) async {
  final app = context.app;
  final controller = TextEditingController(
    text: (app.syncUrl ?? '')
        .replaceFirst('http://', '')
        .replaceFirst(':8787', ''),
  );
  String? message = app.syncError;
  var ok = false;
  var working = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Servidor de pruebas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Para probar con varios teléfonos a la vez:\n'
                '1. En la computadora abre el servidor '
                '(tools/servidor_pruebas).\n'
                '2. Conecta todos los teléfonos al mismo WiFi que la '
                'computadora.\n'
                '3. Escribe aquí la dirección que muestra el servidor.',
                style: dialogContext.texts.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  hintText: '192.168.1.50',
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  message!,
                  style: dialogContext.texts.bodySmall?.copyWith(
                    color: ok
                        ? const Color(0xFF4E7A5A)
                        : dialogContext.colors.error,
                  ),
                ),
              ],
              const SizedBox(height: Insets.sm),
              Text(
                'Al conectar, la app se reinicia y usa los datos del servidor '
                '(los de este teléfono quedan guardados por si lo quitas).',
                style: dialogContext.texts.bodySmall?.copyWith(
                  color: dialogContext.palette.textFaint,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (app.isSharedMode)
            TextButton(
              onPressed: working
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();
                      await app.setSyncServer(null);
                    },
              child: const Text('Desconectar'),
            ),
          TextButton(
            onPressed: working
                ? null
                : () async {
                    setState(() {
                      working = true;
                      message = 'Probando…';
                      ok = false;
                    });
                    final error = await SyncStore.check(controller.text);
                    if (!dialogContext.mounted) return;
                    setState(() {
                      working = false;
                      ok = error == null;
                      message = error ?? '¡Conexión correcta!';
                    });
                  },
            child: const Text('Probar'),
          ),
          TextButton(
            onPressed: working
                ? null
                : () async {
                    setState(() {
                      working = true;
                      message = 'Conectando…';
                      ok = false;
                    });
                    final error = await app.setSyncServer(controller.text);
                    if (!dialogContext.mounted) return;
                    if (error != null) {
                      setState(() {
                        working = false;
                        message = error;
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                  },
            child: const Text('Conectar'),
          ),
        ],
      ),
    ),
  );
}
