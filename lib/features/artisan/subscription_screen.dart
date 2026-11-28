import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/service_status_badge.dart';
import '../../data/models.dart';
import '../../domain/user.dart';

/// Abre la pantalla de la mensualidad.
Future<void> openSubscription(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
  );
}

const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String formatSubscriptionDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// Explica cómo funciona la mensualidad y, si entra un taller, muestra su
/// estado y le deja registrar su pago para que la administración lo active.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final isArtisan = app.user?.role == UserRole.artisan;
    final artisan = isArtisan ? app.artisan : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Mensualidad del taller')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.page,
          Insets.md,
          Insets.page,
          Insets.x5l,
        ),
        children: [
          if (isArtisan) ...[
            _StatusCard(artisan: artisan),
            const SizedBox(height: Insets.xl),
          ],
          Text('Cómo funciona', style: context.texts.titleLarge),
          const SizedBox(height: Insets.md),
          const _Step(
            number: 1,
            title: 'Paga \$${AppConfig.monthlyFee} al mes',
            body: AppConfig.subscriptionPaymentInstructions,
          ),
          const _Step(
            number: 2,
            title: 'Registra tu pago en la app',
            body:
                'Escribe la referencia de la transferencia o el folio del '
                'recibo para que podamos encontrarlo.',
          ),
          const _Step(
            number: 3,
            title: 'Tu taller aparece activo',
            body:
                'La administración confirma el pago y tu taller queda activo '
                '${AppConfig.subscriptionDays} días. Te llega un aviso al '
                'celular.',
          ),
          const SizedBox(height: Insets.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                child: _Compare(
                  active: true,
                  title: 'Mensualidad al día',
                  lines: [
                    'Aparece «Activo»',
                    'Sale primero en la lista',
                    'Recibe pedidos y reservas',
                  ],
                ),
              ),
              SizedBox(width: Insets.md),
              Expanded(
                child: _Compare(
                  active: false,
                  title: 'Sin mensualidad',
                  lines: [
                    'Aparece «Fuera de servicio»',
                    'Se sigue viendo',
                    'No recibe pedidos ni reservas',
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          BelSurface(
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: context.colors.secondary,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'La app no cobra en línea. Además de la mensualidad, '
                    'Bel-Aaktun cobra 10 % por pieza y 15 % por visita solo '
                    'cuando vendes. Precios con IVA incluido.',
                    style: context.texts.bodySmall?.copyWith(
                      color: context.palette.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.artisan});

  final Artisan? artisan;

  Future<void> _report(BuildContext context) async {
    final controller = TextEditingController();
    final reference = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar mi pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escribe la referencia de tu transferencia o el folio del '
              'recibo de tu pago en efectivo.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Referencia o folio',
                hintText: 'Ej. SPEI 0098123 o recibo 15',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (reference == null || !context.mounted) return;
    final error = await context.app.reportSubscriptionPayment(reference);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ??
                'Listo. La administración revisará tu pago y te avisará al '
                    'activar tu taller.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final current = artisan;
    if (current == null) {
      return const OutOfServiceNotice(
        message: 'Completa el perfil de tu taller para activar tu mensualidad.',
      );
    }
    final app = context.app;
    final active = app.isArtisanInService(current.id);
    final until = current.subscriptionUntil;
    final pending = current.subscriptionPendingRef;
    final color = active ? serviceActiveColor : serviceInactiveColor;

    final (title, body) = switch ((active, pending != null)) {
      (true, _) => (
        'Tu taller está activo',
        until == null
            ? 'Recibes pedidos y reservas.'
            : 'Mensualidad pagada hasta el ${formatSubscriptionDate(until)}.',
      ),
      (false, true) => (
        'Pago en revisión',
        'Registraste «$pending». La administración lo confirmará pronto.',
      ),
      (false, false) => (
        'Tu taller aparece fuera de servicio',
        'Paga tu mensualidad para recibir pedidos y reservas.',
      ),
    };

    return BelSurface(
      elevated: true,
      borderColor: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                active
                    ? Icons.check_circle_rounded
                    : (pending != null
                          ? Icons.hourglass_top_rounded
                          : Icons.pause_circle_rounded),
                color: color,
                size: 28,
              ),
              const SizedBox(width: Insets.md),
              Expanded(child: Text(title, style: context.texts.titleMedium)),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            body,
            style: context.texts.bodyMedium?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
          if (active && pending != null) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'Pago «$pending» en revisión para el siguiente mes.',
              style: context.texts.bodySmall,
            ),
          ],
          const SizedBox(height: Insets.lg),
          BelButton(
            label: active ? 'Registrar pago del siguiente mes' : 'Registrar mi pago',
            icon: Icons.receipt_long_rounded,
            onPressed: pending != null ? null : () => _report(context),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: context.colors.primary,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.texts.titleSmall),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: context.texts.bodyMedium?.copyWith(
                    color: context.palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Compare extends StatelessWidget {
  const _Compare({
    required this.active,
    required this.title,
    required this.lines,
  });

  final bool active;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final color = active ? serviceActiveColor : serviceInactiveColor;
    return BelSurface(
      padding: const EdgeInsets.all(Insets.md),
      borderColor: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            color: color,
          ),
          const SizedBox(height: Insets.sm),
          Text(title, style: context.texts.titleSmall),
          const SizedBox(height: Insets.xs),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '· $line',
                style: context.texts.bodySmall?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
