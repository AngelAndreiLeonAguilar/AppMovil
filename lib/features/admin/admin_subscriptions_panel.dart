import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/service_status_badge.dart';
import '../../data/models.dart';
import '../artisan/subscription_screen.dart';

/// Mensualidades de los talleres: confirmar pagos, activar o poner fuera de
/// servicio.
class AdminSubscriptionsPanel extends StatefulWidget {
  const AdminSubscriptionsPanel({super.key});

  @override
  State<AdminSubscriptionsPanel> createState() =>
      _AdminSubscriptionsPanelState();
}

class _AdminSubscriptionsPanelState extends State<AdminSubscriptionsPanel> {
  int _filter = 0;

  static const _filters = [
    'Por confirmar',
    'Activos',
    'Fuera de servicio',
    'Todos',
  ];

  Future<void> _run(BuildContext context, Future<String?> action) async {
    final error = await action;
    if (!context.mounted || error == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<String?> _askReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Rechazar el pago?'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Motivo para el taller (opcional)',
            hintText: 'Ej. No encontramos la transferencia',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final all = app.allArtisans;
    final list = [
      for (final artisan in all)
        if (switch (_filter) {
          0 => artisan.hasPendingPayment,
          1 => app.isArtisanInService(artisan.id),
          2 => !app.isArtisanInService(artisan.id),
          _ => true,
        })
          artisan,
    ];
    final active = all.where((a) => app.isArtisanInService(a.id)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.page, Insets.md, Insets.page, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$active de ${all.length} talleres activos · '
            '${app.pendingSubscriptionCount} pagos por confirmar · '
            'mensualidad \$${AppConfig.monthlyFee}',
            style: context.texts.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (final (index, label) in _filters.indexed)
                BelFilterChip(
                  label: label,
                  selected: _filter == index,
                  onTap: () => setState(() => _filter = index),
                ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.x3l),
              child: Text(
                _filter == 0
                    ? 'No hay pagos por confirmar.'
                    : 'No hay talleres en esta lista.',
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
            )
          else
            for (final artisan in list)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: _SubscriptionTile(
                  artisan: artisan,
                  onConfirm: () => _run(
                    context,
                    app.adminConfirmSubscription(artisan.id),
                  ),
                  onReject: () async {
                    final reason = await _askReason(context);
                    if (reason == null || !context.mounted) return;
                    await _run(
                      context,
                      app.adminRejectSubscription(artisan.id, reason: reason),
                    );
                  },
                  onSuspend: () =>
                      _run(context, app.adminSetOutOfService(artisan.id)),
                ),
              ),
        ],
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({
    required this.artisan,
    required this.onConfirm,
    required this.onReject,
    required this.onSuspend,
  });

  final Artisan artisan;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onSuspend;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final active = app.isArtisanInService(artisan.id);
    final until = artisan.subscriptionUntil;
    final pending = artisan.subscriptionPendingRef;

    return BelSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(artisan.name, style: context.texts.titleSmall),
              ),
              ServiceStatusBadge(artisanId: artisan.id),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(
            active && until != null
                ? 'Pagado hasta el ${formatSubscriptionDate(until)}'
                : (until != null
                      ? 'Venció el ${formatSubscriptionDate(until)}'
                      : 'Sin mensualidad registrada'),
            style: context.texts.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
          if (artisan.isShowcase) ...[
            const SizedBox(height: Insets.sm),
            const BelPill(label: 'Ejemplo', icon: Icons.science_outlined),
          ],
          if (pending != null) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'Pago avisado: «$pending»',
              style: context.texts.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              if (pending != null) ...[
                BelButton(
                  label: 'Confirmar pago',
                  icon: Icons.check_rounded,
                  expand: false,
                  compact: true,
                  onPressed: onConfirm,
                ),
                BelButton(
                  label: 'Rechazar',
                  variant: BelButtonVariant.outline,
                  expand: false,
                  compact: true,
                  onPressed: onReject,
                ),
              ] else
                BelButton(
                  label: active
                      ? 'Sumar ${AppConfig.subscriptionDays} días'
                      : 'Activar ${AppConfig.subscriptionDays} días',
                  icon: Icons.verified_rounded,
                  variant: BelButtonVariant.outline,
                  expand: false,
                  compact: true,
                  onPressed: onConfirm,
                ),
              if (active)
                BelButton(
                  label: 'Poner fuera de servicio',
                  variant: BelButtonVariant.ghost,
                  expand: false,
                  compact: true,
                  onPressed: onSuspend,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
