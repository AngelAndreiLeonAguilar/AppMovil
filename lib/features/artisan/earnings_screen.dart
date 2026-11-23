import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/page_header.dart';
import '../../domain/finance.dart';
import '../admin/admin_commissions_panel.dart';

enum _Period {
  month('Este mes'),
  last30('30 días'),
  all('Todo');

  const _Period(this.label);

  final String label;

  DateTime? get since {
    final now = DateTime.now();
    return switch (this) {
      _Period.month => DateTime(now.year, now.month),
      _Period.last30 => now.subtract(const Duration(days: 30)),
      _Period.all => null,
    };
  }
}

/// Ventas, ingresos netos, comisiones y estadísticas del taller.
///
/// Todo sale del registro financiero: solo cuenta lo entregado o realizado,
/// y la comisión de Bel-Aaktun se muestra aparte del ingreso del taller.
class ArtisanEarningsScreen extends StatefulWidget {
  const ArtisanEarningsScreen({super.key});

  @override
  State<ArtisanEarningsScreen> createState() => _ArtisanEarningsScreenState();
}

class _ArtisanEarningsScreenState extends State<ArtisanEarningsScreen> {
  _Period _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final since = _period.since;
    final total = app.financeSummary(since: since);
    final sales = app.financeSummary(source: LedgerSource.sale, since: since);
    final visits = app.financeSummary(source: LedgerSource.visit, since: since);
    final allTime = app.financeSummary();
    final weeks = app.netIncomeByWeek;
    final topProducts = app.topProductsSold;
    final topServices = app.topServicesByVisits;
    final history = [
      for (final entry in app.ledgerEntries)
        if (since == null ||
            !(entry.earnedAt ?? entry.createdAt).isBefore(since))
          entry,
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        const SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: 'Tu negocio',
            title: 'Ventas e ingresos',
            subtitle: 'Solo cuenta lo entregado o la visita realizada.',
          ),
        ),

        // Periodo
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.page),
            child: Wrap(
              spacing: Insets.sm,
              children: [
                for (final period in _Period.values)
                  BelFilterChip(
                    label: period.label,
                    selected: _period == period,
                    onTap: () => setState(() => _period = period),
                  ),
              ],
            ),
          ),
        ),

        // Ingreso neto
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.lg,
              Insets.page,
              0,
            ),
            child: BelSurface(
              padding: const EdgeInsets.all(Insets.lg),
              elevated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TU INGRESO NETO',
                    style: context.texts.labelSmall?.copyWith(
                      color: palette.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    formatPrice(total.artisanNetEarned),
                    style: context.texts.displaySmall?.copyWith(
                      color: context.colors.primary,
                      fontSize: 34,
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      _Figure(
                        label: 'Vendido',
                        value: formatPrice(total.grossEarned),
                      ),
                      _Figure(
                        label: 'Comisión Bel-Aaktun',
                        value: formatPrice(total.commissionEarned),
                      ),
                      _Figure(
                        label: 'Operaciones',
                        value: '${total.completedCount}',
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  Text(
                    'Vendido = lo que pagaron tus clientes en pedidos '
                    'entregados y visitas realizadas. Tu ingreso neto ya '
                    'descuenta la comisión de la plataforma.',
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textFaint,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Por confirmar y por pagar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.md,
              Insets.page,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _InfoCard(
                    icon: Icons.hourglass_top_rounded,
                    title: 'Por confirmar',
                    value: formatPrice(allTime.artisanNetPending),
                    hint:
                        '${allTime.pendingCount} aceptadas sin entregar o '
                        'realizar',
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: _InfoCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Comisión por pagar',
                    value: formatPrice(allTime.commissionToSettle),
                    hint: 'Lo que debes a Bel-Aaktun de lo ya cobrado',
                    alert: allTime.commissionToSettle > 0,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Piezas vs visitas
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.lg,
              Insets.page,
              0,
            ),
            child: BelSurface(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle('DE DÓNDE VIENE TU INGRESO'),
                  const SizedBox(height: Insets.md),
                  _SourceRow(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Venta de piezas',
                    summary: sales,
                    total: total.artisanNetEarned,
                  ),
                  const SizedBox(height: Insets.md),
                  _SourceRow(
                    icon: Icons.event_available_outlined,
                    label: 'Visitas y experiencias',
                    summary: visits,
                    total: total.artisanNetEarned,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Semanas
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.lg,
              Insets.page,
              0,
            ),
            child: BelSurface(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('INGRESO NETO · ÚLTIMAS 4 SEMANAS'),
                  const SizedBox(height: Insets.lg),
                  _WeekBars(weeks: weeks),
                ],
              ),
            ),
          ),
        ),

        // Lo más vendido
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.lg,
              Insets.page,
              0,
            ),
            child: BelSurface(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle('LO MÁS VENDIDO'),
                  const SizedBox(height: Insets.sm),
                  if (topProducts.isEmpty && topServices.isEmpty)
                    Text(
                      'Cuando entregues pedidos o completes visitas verás '
                      'aquí tus piezas y experiencias más solicitadas.',
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  for (final product in topProducts)
                    _RankRow(
                      icon: Icons.shopping_bag_outlined,
                      title: product.name,
                      detail:
                          '${product.pieces} '
                          '${product.pieces == 1 ? 'pieza' : 'piezas'} · '
                          '${formatPrice(product.gross)}',
                    ),
                  for (final service in topServices)
                    _RankRow(
                      icon: Icons.event_available_outlined,
                      title: service.serviceTitle,
                      detail:
                          '${service.visits} '
                          '${service.visits == 1 ? 'visita' : 'visitas'} · '
                          '${service.people} personas',
                    ),
                ],
              ),
            ),
          ),
        ),

        // Historial
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.xl,
              Insets.page,
              Insets.sm,
            ),
            child: Row(
              children: [
                const _SectionTitle('HISTORIAL DE VENTAS Y VISITAS'),
                const Spacer(),
                Text(
                  '${history.length}',
                  style: context.texts.labelSmall?.copyWith(
                    color: palette.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (history.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              child: BelSurface(
                padding: const EdgeInsets.all(Insets.lg),
                child: Text(
                  'Sin movimientos en este periodo. Cada pedido o visita que '
                  'aceptes aparecerá aquí con su desglose.',
                  textAlign: TextAlign.center,
                  style: context.texts.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: history.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                0,
                Insets.page,
                Insets.sm,
              ),
              child: LedgerEntryTile(
                entry: history[index],
                artisanName: history[index].source.label,
                onTap: () => showLedgerEntry(context, history[index].id),
              ),
            ),
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.md,
              Insets.page,
              0,
            ),
            child: Text(
              'Los anticipos de visitas todavía son simulados (no hay pasarela '
              'de pagos), por eso no se muestran como dinero cobrado.',
              style: context.texts.bodySmall?.copyWith(
                color: palette.textFaint,
                fontSize: 11,
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 132)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.texts.labelSmall?.copyWith(
        color: context.palette.textMuted,
        letterSpacing: 2,
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.texts.labelSmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: context.texts.titleSmall),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
    this.alert = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String hint;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = alert ? context.colors.primary : palette.textMuted;
    return BelSurface(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: Insets.sm),
          Text(
            title,
            style: context.texts.labelMedium?.copyWith(
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: context.texts.titleLarge),
          const SizedBox(height: 2),
          Text(
            hint,
            style: context.texts.bodySmall?.copyWith(
              color: palette.textFaint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.summary,
    required this.total,
  });

  final IconData icon;
  final String label;
  final FinanceSummary summary;
  final int total;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final share = total <= 0 ? 0.0 : summary.artisanNetEarned / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: palette.textMuted),
            const SizedBox(width: Insets.sm),
            Expanded(child: Text(label, style: context.texts.bodyMedium)),
            Text(
              formatPrice(summary.artisanNetEarned),
              style: context.texts.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 6,
            backgroundColor: palette.surfaceMuted,
            color: context.colors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${summary.completedCount} completadas · vendido '
          '${formatPrice(summary.grossEarned)} · comisión '
          '${formatPrice(summary.commissionEarned)}',
          style: context.texts.bodySmall?.copyWith(
            color: palette.textFaint,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.palette.textMuted),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodyMedium,
            ),
          ),
          Text(
            detail,
            style: context.texts.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.weeks});

  final List<FinanceWeek> weeks;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxValue = weeks.fold<int>(
      1,
      (max, week) => week.amount > max ? week.amount : max,
    );

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final week in weeks)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      week.amount == 0 ? '—' : formatPrice(week.amount),
                      textAlign: TextAlign.center,
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 9,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 8 + (84 * (week.amount / maxValue)),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(
                          alpha: week.amount == 0 ? 0.18 : 0.85,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(Radii.xs),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      week.label,
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 9.5,
                        color: palette.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
