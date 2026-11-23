import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/bel_text_field.dart';
import '../../core/widgets/page_header.dart';
import '../../core/utils/contact_links.dart';
import '../../core/utils/maps_links.dart';

/// Contacto: canales directos y mensaje listo para enviar.
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key, this.presetMessage});

  final String? presetMessage;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final TextEditingController _messageController = TextEditingController(
    text: widget.presetMessage ?? '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copiado')));
  }

  void _prepareMessage() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final message = _messageController.text.trim();
    final body = 'Hola, soy $name.\n\n$message';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final palette = sheetContext.palette;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            Insets.page,
            Insets.sm,
            Insets.page,
            MediaQuery.viewInsetsOf(sheetContext).bottom + Insets.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mensaje listo', style: sheetContext.texts.headlineSmall),
              const SizedBox(height: Insets.sm),
              Text(
                'Se abrirá WhatsApp con este mensaje para '
                '${AppConfig.whatsapp}.',
                style: sheetContext.texts.bodyMedium,
              ),
              const SizedBox(height: Insets.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(body, style: sheetContext.texts.bodySmall),
              ),
              const SizedBox(height: Insets.xl),
              BelButton(
                label: 'Enviar por WhatsApp',
                icon: Icons.chat_rounded,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  ContactLinks.open(
                    context,
                    ContactLinks.whatsapp(AppConfig.whatsapp, message: body),
                  );
                },
              ),
              const SizedBox(height: Insets.sm),
              BelButton(
                label: 'Copiar mensaje',
                icon: Icons.copy_rounded,
                variant: BelButtonVariant.ghost,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _copy(body, 'Mensaje');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              showBack: true,
              eyebrow: 'Hablemos',
              title: 'Contacto',
              subtitle:
                  '¿Dudas sobre una pieza o una visita? Escríbenos y te '
                  'respondemos en horario de taller.',
              actions: [
                if (AppConfig.showDemoBadges)
                  const BelPill(label: 'Demo', icon: Icons.science_outlined),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              child: Column(
                children: [
                  _ContactRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'WhatsApp',
                    value: AppConfig.whatsapp,
                    onTap: () => ContactLinks.open(
                      context,
                      ContactLinks.whatsapp(AppConfig.whatsapp),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  _ContactRow(
                    icon: Icons.call_outlined,
                    label: 'Teléfono',
                    value: AppConfig.phone,
                    onTap: () => ContactLinks.open(
                      context,
                      ContactLinks.call(AppConfig.phone),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  _ContactRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Correo',
                    value: AppConfig.email,
                    onTap: () => ContactLinks.open(
                      context,
                      ContactLinks.email(
                        AppConfig.email,
                        subject: 'Contacto desde Bel-Aaktun',
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  _ContactRow(
                    icon: Icons.place_outlined,
                    label: 'Dirección',
                    value: AppConfig.address,
                    onTap: () => MapsLinks.openOrWarn(
                      context,
                      MapsLinks.point(
                        AppConfig.mapCenterLat,
                        AppConfig.mapCenterLng,
                        label: AppConfig.address,
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  _ContactRow(
                    icon: Icons.schedule_rounded,
                    label: 'Horario',
                    value: AppConfig.schedule,
                    onTap: null,
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.x3l,
                Insets.page,
                0,
              ),
              child: Text(
                'Envíanos un mensaje',
                style: context.texts.headlineSmall,
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BelTextField(
                      label: 'Tu nombre',
                      hint: 'Nombre y apellido',
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().length < 3) {
                          return 'Escribe tu nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Insets.lg),
                    BelTextField(
                      label: 'Mensaje',
                      hint: 'Cuéntanos qué necesitas',
                      controller: _messageController,
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().length < 8) {
                          return 'Escribe un mensaje un poco más largo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Insets.lg),
                    BelButton(
                      label: 'Preparar mensaje',
                      icon: Icons.send_rounded,
                      onPressed: _prepareMessage,
                    ),
                    const SizedBox(height: Insets.md),
                    Text(
                      'Sin formularios que se pierdan: preparamos el texto para '
                      'que lo envíes tú.',
                      textAlign: TextAlign.center,
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.x3l,
                Insets.page,
                Insets.x4l,
              ),
              child: BelSurface(
                padding: const EdgeInsets.all(Insets.lg),
                child: Row(
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 20,
                      color: context.colors.secondary,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Síguenos', style: context.texts.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            '${AppConfig.instagram} · ${AppConfig.facebook}',
                            style: context.texts.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return BelSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.primary.withValues(alpha: 0.10),
            ),
            child: Icon(icon, size: 19, color: context.colors.primary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: context.texts.labelSmall?.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    color: palette.textFaint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: context.texts.titleSmall),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.copy_rounded, size: 17, color: palette.textFaint),
        ],
      ),
    );
  }
}
