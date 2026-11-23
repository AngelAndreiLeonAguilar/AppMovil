import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../domain/finance.dart';
import 'admin_operations.dart';

/// Comisiones de la plataforma: tasas, totales y movimientos.
class AdminCommissionsPanel extends StatefulWidget {
  const AdminCommissionsPanel({super.key});

  @override
  State<AdminCommissionsPanel> createState() => _AdminCommissionsPanelState();
}

class _AdminCommissionsPanelState extends State<AdminCommissionsPanel> {
  /// `null` = todo; o solo ventas / solo visitas.
  LedgerSource? _source;

  /// 0 = este mes, 1 = 30 días, 2 = todo.
  int _period = 2;

  DateTime? get _since {
    final now = DateTime.now();
    return switch (_period) {
      0 => DateTime(now.year, now.month),
      1 => now.subtract(const Duration(days: 30)),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final settings = app.commissionSettings;
    final since = _since;
    final summary = app.financeSummary(source: _source, since: since);
    final entries = [
      for (final entry in app.ledgerEntries)
        if ((_source == null || entry.source == _source) &&
            (since == null ||
                !(entry.earnedAt ?? entry.createdAt).isBefore(since)))
          entry,
    ];
    final months = monthlyPerformance(
      app.ledgerEntries.where(
        (entry) => _source == null || entry.source == _source,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.page,
        Insets.md,
        Insets.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RatesCard(settings: settings),
          const SizedBox(height: Insets.lg),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              BelFilterChip(
                label: 'Todo',
                selected: _source == null,
                onTap: () => setState(() => _source = null),
              ),
              BelFilterChip(
                label: 'Ventas',
                selected: _source == LedgerSource.sale,
                onTap: () => setState(() => _source = LedgerSource.sale),
              ),
              BelFilterChip(
                label: 'Visitas',
                selected: _source == LedgerSource.visit,
                onTap: () => setState(() => _source = LedgerSource.visit),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          const SizedBox(height: Insets.xs),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (final (index, label) in const [
                (0, 'Este mes'),
                (1, '30 días'),
                (2, 'Todo el tiempo'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _period == index,
                  onSelected: (_) => setState(() => _period = index),
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          _SummaryGrid(summary: summary),
          const SizedBox(height: Insets.md),
          MonthlyPerformanceTable(months: months),
          const SizedBox(height: Insets.md),
          Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: palette.textMuted,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'Solo cuenta como ingreso la comisión de operaciones '
                    'completadas. La app aún no procesa pagos: el cliente '
                    'paga en el taller y la comisión queda por liquidar hasta '
                    'registrar su pago con una referencia.',
                    style: context.texts.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            'MOVIMIENTOS',
            style: context.texts.labelSmall?.copyWith(
              color: palette.textMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: Insets.sm),
          if (entries.isEmpty)
            BelSurface(
              padding: const EdgeInsets.all(Insets.lg),
              child: Text(
                'Todavía no hay operaciones aceptadas. Cada pedido o visita '
                'aceptada por un taller aparecerá aquí con su comisión.',
                textAlign: TextAlign.center,
                style: context.texts.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: LedgerEntryTile(
                  entry: entry,
                  artisanName: app.artisanById(entry.artisanId)?.name,
                  onTap: () => showLedgerEntry(context, entry.id),
                ),
              ),
        ],
      ),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard({required this.settings});

  final CommissionSettings settings;

  Future<void> _edit(BuildContext context, LedgerSource source) async {
    final app = context.app;
    final messenger = ScaffoldMessenger.of(context);
    final current = settings.rateFor(source);
    final controller = TextEditingController(
      text: formatRate(current).replaceAll(' %', ''),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Comisión por ${source == LedgerSource.sale ? 'venta' : 'visita'}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                suffixText: '%',
                helperText: 'Entre 0 y 50. Ej. 10 o 12.5',
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'Se aplica a las operaciones que se acepten desde ahora. Las '
              'anteriores conservan la tasa con que se registraron.',
              style: dialogContext.texts.bodySmall,
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
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (value == null) return;
    final parsed = double.tryParse(value.replaceAll(',', '.').trim());
    if (parsed == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Escribe un porcentaje válido.')),
      );
      return;
    }
    final bps = (parsed * 100).round();
    final error = source == LedgerSource.sale
        ? await app.setCommissionRates(saleRateBps: bps)
        : await app.setCommissionRates(visitRateBps: bps);
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Comisión actualizada a ${formatRate(bps)}.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return BelSurface(
      padding: const EdgeInsets.all(Insets.lg),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tasas de comisión', style: context.texts.titleMedium),
          const SizedBox(height: Insets.md),
          _RateRow(
            icon: Icons.shopping_bag_outlined,
            label: 'Venta de piezas',
            rate: settings.saleRateBps,
            onEdit: () => _edit(context, LedgerSource.sale),
          ),
          const Divider(height: Insets.lg),
          _RateRow(
            icon: Icons.event_available_outlined,
            label: 'Visitas y experiencias',
            rate: settings.visitRateBps,
            onEdit: () => _edit(context, LedgerSource.visit),
          ),
          if (settings.updatedAt != null) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'Último cambio: ${formatRelative(settings.updatedAt!)}'
              '${settings.updatedBy == null ? '' : ' · ${settings.updatedBy}'}',
              style: context.texts.bodySmall?.copyWith(
                color: palette.textFaint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.icon,
    required this.label,
    required this.rate,
    required this.onEdit,
  });

  final IconData icon;
  final String label;
  final int rate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.palette.textMuted),
        const SizedBox(width: Insets.sm),
        Expanded(child: Text(label, style: context.texts.bodyMedium)),
        Text(
          formatRate(rate),
          style: context.texts.titleMedium?.copyWith(
            color: context.colors.primary,
          ),
        ),
        const SizedBox(width: Insets.xs),
        IconButton(
          tooltip: 'Cambiar',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Figure(
        label: 'Ingreso de Bel-Aaktun',
        value: formatPrice(summary.commissionEarned),
        hint: 'Comisión de ${summary.completedCount} operaciones completadas',
        highlight: true,
      ),
      _Figure(
        label: 'Por confirmar',
        value: formatPrice(summary.commissionPending),
        hint: '${summary.pendingCount} aceptadas sin completar (no es ingreso)',
      ),
      _Figure(
        label: 'Por liquidar',
        value: formatPrice(summary.commissionToSettle),
        hint: 'Devengada, el taller aún no la paga',
      ),
      _Figure(
        label: 'Liquidado',
        value: formatPrice(summary.commissionSettled),
        hint: 'Con pago registrado',
      ),
      _Figure(
        label: 'Ventas y visitas completadas',
        value: formatPrice(summary.grossEarned),
        hint: 'Importe total cobrado por los talleres',
      ),
      _Figure(
        label: 'Corresponde a artesanos',
        value: formatPrice(summary.artisanNetEarned),
        hint: 'Total menos comisión',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - Insets.sm) / 2;
        return Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.hint,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String hint;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = highlight ? context.colors.onPrimary : palette.text;
    final muted = highlight
        ? context.colors.onPrimary.withValues(alpha: 0.85)
        : palette.textMuted;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: highlight ? context.colors.primary : palette.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: highlight ? null : Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.texts.labelMedium?.copyWith(color: muted)),
          const SizedBox(height: 4),
          Text(value, style: context.texts.titleLarge?.copyWith(color: fg)),
          const SizedBox(height: 2),
          Text(
            hint,
            style: context.texts.bodySmall?.copyWith(
              color: muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta del estado contable.
class LedgerStatusPill extends StatelessWidget {
  const LedgerStatusPill({super.key, required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final (label, color) = switch (entry.status) {
      LedgerStatus.pending => (entry.status.label, scheme.secondary),
      LedgerStatus.voided => (entry.status.label, scheme.error),
      LedgerStatus.earned =>
        entry.isSettled
            ? ('Liquidada', const Color(0xFF4E7A5A))
            : ('Por liquidar', scheme.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: context.texts.labelSmall?.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

/// Fila de un movimiento financiero.
class LedgerEntryTile extends StatelessWidget {
  const LedgerEntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.artisanName,
  });

  final LedgerEntry entry;
  final String? artisanName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final voided = entry.status == LedgerStatus.voided;
    return Opacity(
      opacity: voided ? 0.6 : 1,
      child: BelSurface(
        onTap: onTap,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Icon(
              entry.source == LedgerSource.sale
                  ? Icons.shopping_bag_outlined
                  : Icons.event_available_outlined,
              color: palette.textMuted,
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${entry.folio} · ${artisanName ?? entry.artisanId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.titleSmall?.copyWith(
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      LedgerStatusPill(entry: entry),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.description} · ${entry.customerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total ${formatPrice(entry.gross)} · Comisión '
                    '${formatPrice(entry.commission)} (${formatRate(entry.rateBps)}) · '
                    'Taller ${formatPrice(entry.artisanNet)}',
                    style: context.texts.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalle de un movimiento con su historial y, para la administración, el
/// registro del pago de la comisión.
Future<void> showLedgerEntry(BuildContext context, String entryId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final app = sheetContext.app;
      final entry = app.ledgerEntries.where((e) => e.id == entryId).firstOrNull;
      if (entry == null) return const SizedBox(height: 120);
      final palette = sheetContext.palette;
      final canSettle = app.isAdmin && entry.isPendingSettlement;

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Insets.page,
            0,
            Insets.page,
            Insets.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.source.label} · ${entry.folio}',
                      style: sheetContext.texts.titleLarge,
                    ),
                  ),
                  LedgerStatusPill(entry: entry),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Text(
                '${app.artisanById(entry.artisanId)?.name ?? entry.artisanId} · '
                '${entry.customerName}',
                style: sheetContext.texts.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: Insets.lg),
              _BreakdownRow(
                label: 'Total de la operación',
                value: formatPrice(entry.gross),
              ),
              _BreakdownRow(
                label: 'Comisión Bel-Aaktun (${formatRate(entry.rateBps)})',
                value: formatPrice(entry.commission),
              ),
              _BreakdownRow(
                label: 'Corresponde al taller',
                value: formatPrice(entry.artisanNet),
                bold: true,
              ),
              if (entry.isSettled) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  'Liquidada ${formatRelative(entry.settledAt!)} · Ref. ${entry.settlementRef}',
                  style: sheetContext.texts.bodySmall,
                ),
              ],
              if (canSettle) ...[
                const SizedBox(height: Insets.lg),
                BelButton(
                  label: 'Registrar pago de la comisión',
                  icon: Icons.receipt_long_outlined,
                  onPressed: () async {
                    final ref = await _askReference(sheetContext);
                    if (ref == null || !sheetContext.mounted) return;
                    final messenger = ScaffoldMessenger.of(sheetContext);
                    final error = await app.registerSettlement(entry.id, ref);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(error ?? 'Liquidación registrada.'),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: Insets.lg),
              Text(
                'HISTORIAL',
                style: sheetContext.texts.labelSmall?.copyWith(
                  color: palette.textMuted,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: Insets.sm),
              for (final event in entry.history.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.xs),
                  child: Text(
                    '${formatRelative(event.at)} · ${event.status.label}'
                    '${event.note == null ? '' : ' — ${event.note}'}',
                    style: sheetContext.texts.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> _askReference(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Registrar pago de comisión'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Referencia del pago',
          hintText: 'Recibo, folio de transferencia…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Registrar'),
        ),
      ],
    ),
  );
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? context.texts.titleSmall : context.texts.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
