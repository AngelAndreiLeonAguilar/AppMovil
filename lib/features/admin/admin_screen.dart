import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_stat_tile.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/page_header.dart';
import '../../domain/artisan_application.dart';
import '../../domain/user_account.dart';
import 'admin_commissions_panel.dart';
import '../../domain/user.dart';
import 'admin_operations.dart';

/// Panel del administrador: verificación de talleres, usuarios y auditoría.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  /// 0 Solicitudes · 1 Usuarios · 2 Auditoría · 3 Comisiones · 4 Resumen ·
  /// 5 Pedidos · 6 Reservas · 7 Catálogo.
  int _tab = 4;

  /// Filtro de la pestaña Usuarios: `null` = todos.
  UserRole? _userRole;
  bool _loading = true;
  String? _error;

  Map<String, int> _summary = const {};
  List<ArtisanApplication> _applications = const [];
  List<UserAccount> _users = const [];
  List<Map<String, dynamic>> _audit = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final app = context.app;
    try {
      final summary = await app.adminSummary();
      final applications = await app.adminApplications();
      final users = await app.adminUsers();
      final audit = await app.adminAudit();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _applications = applications;
        _users = users;
        _audit = audit;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _review(ArtisanApplication application, String decision) async {
    String? motivo;
    if (decision == 'rechazada') {
      motivo = await _askReason(
        title: 'Rechazar solicitud',
        hint: 'Explica qué falta o por qué no se puede verificar',
      );
      if (motivo == null) return;
    }
    if (!mounted) return;

    try {
      await context.app.reviewApplication(
        application.id,
        decision: decision,
        motivo: motivo,
      );
      if (!mounted) return;
      _snack(
        decision == 'aprobada' ? 'Taller aprobado.' : 'Solicitud rechazada.',
      );
      await _load();
    } catch (error) {
      _snack(error.toString());
    }
  }

  Future<void> _suspend(UserAccount user) async {
    final motivo = await _askReason(
      title: 'Suspender cuenta',
      hint: 'Motivo de la suspensión',
    );
    if (motivo == null) return;
    if (!mounted) return;
    try {
      await context.app.suspendUser(user.id, motivo);
      if (!mounted) return;
      _snack('Cuenta suspendida.');
      await _load();
    } catch (error) {
      _snack(error.toString());
    }
  }

  Future<void> _reactivate(UserAccount user) async {
    try {
      await context.app.reactivateUser(user.id);
      if (!mounted) return;
      _snack('Cuenta reactivada.');
      await _load();
    } catch (error) {
      _snack(error.toString());
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _askReason({required String title, required String hint}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: dialogContext.texts.titleLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          cursorColor: dialogContext.colors.primary,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(dialogContext).pop(text.length >= 5 ? text : null);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              eyebrow: 'Administración general',
              title: 'Plataforma',
              subtitle: 'Verifica talleres, administra cuentas, comisiones y bitácora.',
              actions: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: app.signOut,
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),

          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.page),
                child: BelSurface(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No se pudo cargar el panel',
                        style: context.texts.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _error!,
                        style: context.texts.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      BelButton(
                        label: 'Reintentar',
                        variant: BelButtonVariant.outline,
                        compact: true,
                        onPressed: _load,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.page),
                child: Row(
                  children: [
                    Expanded(
                      child: BelStatTile(
                        label: 'Solicitudes pendientes',
                        value: '${_summary['solicitudes_pendientes'] ?? 0}',
                        icon: Icons.hourglass_top_rounded,
                        accent: context.colors.secondary,
                        onTap: () => setState(() => _tab = 0),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: BelStatTile(
                        label: 'Talleres aprobados',
                        value: '${_summary['talleres'] ?? 0}',
                        icon: Icons.storefront_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.page),
                child: Row(
                  children: [
                    Expanded(
                      child: BelStatTile(
                        label: 'Usuarios',
                        value: '${_summary['usuarios'] ?? 0}',
                        icon: Icons.groups_rounded,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: BelStatTile(
                        label: 'Solicitudes totales',
                        value: '${_summary['solicitudes_totales'] ?? 0}',
                        icon: Icons.fact_check_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  Insets.lg,
                  Insets.page,
                  0,
                ),
                child: Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    for (final (index, label) in const [
                      (4, 'Resumen'),
                      (0, 'Solicitudes'),
                      (1, 'Usuarios'),
                      (5, 'Pedidos'),
                      (6, 'Reservas'),
                      (7, 'Catálogo'),
                      (3, 'Comisiones'),
                      (2, 'Auditoría'),
                    ])
                      BelFilterChip(
                        label: label,
                        selected: _tab == index,
                        onTap: () => setState(() => _tab = index),
                      ),
                  ],
                ),
              ),
            ),

            if (_tab == 0) ..._applicationsSliver(context),
            if (_tab == 1) ..._usersSliver(context),
            if (_tab == 2) ..._auditSliver(context),
            if (_tab == 3)
              const SliverToBoxAdapter(child: AdminCommissionsPanel()),
            if (_tab == 4)
              SliverToBoxAdapter(
                child: AdminOverviewPanel(
                  users: {
                    'turista': _users
                        .where((user) => user.role == UserRole.tourist)
                        .length,
                    'artesano': _users
                        .where((user) => user.role == UserRole.artisan)
                        .length,
                  },
                ),
              ),
            if (_tab == 5) const SliverToBoxAdapter(child: AdminOrdersPanel()),
            if (_tab == 6)
              const SliverToBoxAdapter(child: AdminBookingsPanel()),
            if (_tab == 7) const SliverToBoxAdapter(child: AdminCatalogPanel()),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 132)),
        ],
      ),
    );
  }

  List<Widget> _applicationsSliver(BuildContext context) {
    final palette = context.palette;
    if (_loading) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(Insets.x3l),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ];
    }
    if (_applications.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(Insets.x3l),
            child: Column(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  size: 36,
                  color: palette.textFaint,
                ),
                const SizedBox(height: Insets.md),
                Text(
                  'Sin solicitudes pendientes',
                  style: context.texts.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: _applications.length,
        itemBuilder: (context, index) {
          final application = _applications[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.sm,
              Insets.page,
              0,
            ),
            child: BelSurface(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          application.nombreTaller,
                          style: context.texts.titleMedium,
                        ),
                      ),
                      BelPill(label: application.estado),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    application.creadoEn == null
                        ? 'Solicitud #${application.id}'
                        : 'Solicitud #${application.id} · '
                              '${formatShortDate(application.creadoEn!)}',
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      Expanded(
                        child: BelButton(
                          label: 'Rechazar',
                          variant: BelButtonVariant.outline,
                          compact: true,
                          onPressed: () => _review(application, 'rechazada'),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: BelButton(
                          label: 'Aprobar',
                          icon: Icons.check_rounded,
                          compact: true,
                          onPressed: () => _review(application, 'aprobada'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _usersSliver(BuildContext context) {
    final palette = context.palette;
    if (_loading) return const [];
    final users = [
      for (final user in _users)
        if (_userRole == null || user.role == _userRole) user,
    ];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.page,
            Insets.md,
            Insets.page,
            Insets.sm,
          ),
          child: Wrap(
            spacing: Insets.sm,
            children: [
              for (final (role, label) in const [
                (null, 'Todos'),
                (UserRole.tourist, 'Turistas'),
                (UserRole.artisan, 'Artesanos'),
                (UserRole.admin, 'Administración'),
              ])
                BelFilterChip(
                  label: label,
                  selected: _userRole == role,
                  onTap: () => setState(() => _userRole = role),
                ),
            ],
          ),
        ),
      ),
      SliverList.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.xs,
              Insets.page,
              0,
            ),
            child: BelSurface(
              padding: const EdgeInsets.all(Insets.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nombre,
                          style: context.texts.titleSmall?.copyWith(
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          '${user.email} · ${user.role.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodySmall?.copyWith(
                            color: palette.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  if (user.isSuspended)
                    BelButton(
                      label: 'Reactivar',
                      variant: BelButtonVariant.outline,
                      compact: true,
                      expand: false,
                      onPressed: () => _reactivate(user),
                    )
                  else if (user.role.name != 'admin')
                    BelButton(
                      label: 'Suspender',
                      variant: BelButtonVariant.outline,
                      compact: true,
                      expand: false,
                      onPressed: () => _suspend(user),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _auditSliver(BuildContext context) {
    final palette = context.palette;
    if (_loading) return const [];
    return [
      SliverList.builder(
        itemCount: _audit.length,
        itemBuilder: (context, index) {
          final entry = _audit[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.xs,
              Insets.page,
              0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 16,
                  color: palette.textFaint,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    '${entry['accion']} · ${entry['entidad']} '
                    '#${entry['entidad_id'] ?? '—'}',
                    style: context.texts.bodySmall?.copyWith(fontSize: 12),
                  ),
                ),
                Text(
                  entry['creado_en']?.toString().split(' ').first ?? '',
                  style: context.texts.labelSmall?.copyWith(
                    color: palette.textFaint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ];
  }
}
