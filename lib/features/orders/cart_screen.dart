import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_text_field.dart';
import '../../data/models.dart';
import '../artisan/widgets/form_parts.dart';
import 'widgets/order_detail_sheet.dart';
import '../../core/widgets/bel_empty_state.dart';

/// Abre el carrito.
Future<void> openCart(BuildContext context) => Navigator.of(context).push<void>(
  MaterialPageRoute(builder: (_) => const CartScreen()),
);

/// Agrega una pieza al carrito y avisa con un acceso directo al carrito.
Future<void> addToCartWithFeedback(
  BuildContext context,
  Product product, {
  int quantity = 1,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await context.app.addToCart(product, quantity: quantity);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(error ?? '“${product.name}” se agregó a tu carrito.'),
        action: error != null || !context.mounted
            ? null
            : SnackBarAction(
                label: 'Ver carrito',
                onPressed: () => openCart(context),
              ),
      ),
    );
}

/// Botón con la bolsa de compras y el número de piezas en el carrito.
///
/// Solo aparece para cuentas de visitante.
class CartButton extends StatelessWidget {
  const CartButton({super.key, this.filled = false});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isSignedIn || app.isArtisan || app.isAdmin) {
      return const SizedBox.shrink();
    }
    final count = app.cartCount;
    final palette = context.palette;

    return Semantics(
      button: true,
      label: count == 0 ? 'Carrito vacío' : 'Carrito, $count piezas',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: filled ? palette.surface : Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => openCart(context),
                child: Center(
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: filled ? palette.text : palette.textMuted,
                    size: 22,
                  ),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(color: palette.background, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.onPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carrito: piezas agrupadas por taller, cantidades, resumen y confirmación.
///
/// Bel-Aaktun no hace envíos: cada pedido se recoge en su taller y se paga al
/// recogerlo.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  bool _prefilled = false;
  bool _sending = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final user = context.app.user;
    if (user != null) {
      _name.text = user.name;
      _phone.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = 'Revisa tus datos de contacto.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await context.app.checkout(
      name: _name.text,
      phone: _phone.text,
      notes: _notes.text,
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _sending = false;
        _error = result.error;
      });
      return;
    }
    final orders = result.orders;
    final navigator = Navigator.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.check_circle_rounded,
          color: dialogContext.colors.primary,
          size: 40,
        ),
        title: Text(
          orders.length == 1 ? '¡Pedido enviado!' : '¡Pedidos enviados!',
        ),
        content: Text(
          orders.length == 1
              ? 'Folio ${orders.first.folio}. El taller lo revisará y te '
                    'avisaremos la fecha y hora para recogerlo. Lo encuentras '
                    'en Actividad → Compras.'
              : 'Se generaron ${orders.length} pedidos, uno por taller '
                    '(${orders.map((order) => order.folio).join(', ')}). Cada '
                    'taller te avisará cuándo recoger el suyo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    navigator.pop();
    if (orders.length == 1) showOrderDetail(context, orders.first);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final items = app.cartItems;

    // Agrupa por taller: cada grupo será un pedido.
    final groups = <String, List<({Product product, int quantity})>>{};
    for (final item in items) {
      groups.putIfAbsent(item.product.artisanId, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Mi carrito', style: context.texts.titleLarge),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: _sending
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('¿Vaciar el carrito?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('Vaciar'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) await app.clearCart();
                    },
              child: const Text('Vaciar'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyCart()
          : Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  Insets.sm,
                  Insets.page,
                  Insets.x3l,
                ),
                children: [
                  _PickupBanner(groups: groups.length),
                  const SizedBox(height: Insets.lg),
                  for (final entry in groups.entries) ...[
                    _ArtisanGroup(
                      artisanId: entry.key,
                      items: entry.value,
                      enabled: !_sending,
                    ),
                    const SizedBox(height: Insets.lg),
                  ],
                  FormSection(
                    title: 'Tus datos',
                    subtitle: 'El taller los usará para coordinar la recogida.',
                    icon: Icons.person_outline_rounded,
                    children: [
                      BelTextField(
                        label: 'Nombre',
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => (value ?? '').trim().length < 3
                            ? 'Escribe tu nombre completo.'
                            : null,
                      ),
                      const SizedBox(height: Insets.md),
                      BelTextField(
                        label: 'Teléfono o WhatsApp',
                        hint: '981 123 4567',
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            (value ?? '')
                                    .replaceAll(RegExp(r'[^0-9]'), '')
                                    .length <
                                10
                            ? 'Escribe un teléfono de 10 dígitos.'
                            : null,
                      ),
                      const SizedBox(height: Insets.md),
                      BelTextField(
                        label: 'Indicaciones (opcional)',
                        hint: 'Talla, color, dedicatoria…',
                        controller: _notes,
                        maxLines: 3,
                        minLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                  _Summary(total: app.cartTotal, pieces: app.cartCount),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Insets.md),
                      child: Text(
                        _error!,
                        style: context.texts.bodyMedium?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: Insets.md),
                  Text(
                    'Al confirmar, el pedido queda como “Pendiente de '
                    'aceptación” hasta que el taller lo acepte y te indique '
                    'cuándo recogerlo.',
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textFaint,
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : FormSaveBar(
              label: _sending
                  ? 'Enviando…'
                  : 'Confirmar pedido · ${formatPrice(app.cartTotal)}',
              onPressed: _sending ? null : _checkout,
            ),
    );
  }
}

class _PickupBanner extends StatelessWidget {
  const _PickupBanner({required this.groups});

  final int groups;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront_rounded, color: context.colors.primary),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              groups > 1
                  ? 'Compras en $groups talleres: se generará un pedido por '
                        'taller. Recoges cada uno en su taller y pagas al '
                        'recoger.'
                  : 'Recoges tu pedido en el taller y pagas al recogerlo. '
                        'No hacemos envíos.',
              style: context.texts.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtisanGroup extends StatelessWidget {
  const _ArtisanGroup({
    required this.artisanId,
    required this.items,
    required this.enabled,
  });

  final String artisanId;
  final List<({Product product, int quantity})> items;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final artisan = app.artisanById(artisanId);
    final subtotal = items.fold(
      0,
      (sum, item) => sum + (item.product.price ?? 0) * item.quantity,
    );

    return BelSurface(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.home_work_outlined, size: 18, color: palette.textMuted),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  artisan?.name ?? 'Taller',
                  style: context.texts.titleSmall,
                ),
              ),
              Text(
                'Recoger en el taller',
                style: context.texts.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
          const Divider(height: Insets.xl),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: _CartRow(
                product: item.product,
                quantity: item.quantity,
                enabled: enabled,
              ),
            ),
          Row(
            children: [
              Text(
                'Subtotal del taller',
                style: context.texts.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
              const Spacer(),
              Text(formatPrice(subtotal), style: context.texts.titleSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.product,
    required this.quantity,
    required this.enabled,
  });

  final Product product;
  final int quantity;
  final bool enabled;

  Future<void> _set(BuildContext context, int value) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.app.setCartQuantity(product.id, value);
    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final max = context.app.maxQuantityOf(product);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: SizedBox(
            width: 64,
            height: 64,
            child: BelArtwork(
              imagePath: product.coverImage,
              variant: ArtworkVariant.craft,
              seed: product.id.hashCode,
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.titleSmall?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatPrice(product.price)} c/u'
                '${product.madeToOrder ? ' · por encargo' : ''}',
                style: context.texts.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Row(
                children: [
                  _QtyButton(
                    icon: quantity <= 1
                        ? Icons.delete_outline_rounded
                        : Icons.remove_rounded,
                    tooltip: quantity <= 1 ? 'Quitar' : 'Menos',
                    onTap: enabled ? () => _set(context, quantity - 1) : null,
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: context.texts.titleSmall,
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Más',
                    onTap: enabled && quantity < max
                        ? () => _set(context, quantity + 1)
                        : null,
                  ),
                  const Spacer(),
                  Text(
                    formatPrice((product.price ?? 0) * quantity),
                    style: context.texts.titleSmall?.copyWith(
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? context.colors.primary.withValues(alpha: 0.12)
            : context.palette.surfaceMuted,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? context.colors.primary
                  : context.palette.textFaint,
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.pieces});

  final int total;
  final int pieces;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Resumen', style: context.texts.titleMedium),
          const SizedBox(height: Insets.sm),
          _SummaryRow(
            label: '$pieces ${pieces == 1 ? 'pieza' : 'piezas'}',
            value: formatPrice(total),
          ),
          const _SummaryRow(label: 'Entrega', value: 'Recoger en el taller'),
          const _SummaryRow(label: 'Pago', value: 'Al recoger, en el taller'),
          const Divider(height: Insets.xl),
          Row(
            children: [
              Text('Total', style: context.texts.titleMedium),
              const Spacer(),
              Text(
                formatPrice(total),
                style: context.texts.titleLarge?.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xs),
      child: Row(
        children: [
          Text(
            label,
            style: context.texts.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
          const Spacer(),
          Text(value, style: context.texts.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return BelEmptyState(
      framed: false,
      icon: Icons.shopping_bag_outlined,
      title: 'Tu carrito está vacío',
      message: 'Explora el catálogo y agrega piezas hechas a mano en Bécal.',
      actionLabel: 'Ver catálogo',
      actionIcon: Icons.grid_view_rounded,
      onAction: () => Navigator.of(context).maybePop(),
    );
  }
}
