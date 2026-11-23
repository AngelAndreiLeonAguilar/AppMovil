import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_links.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/bel_text_field.dart';
import '../../core/widgets/photo_picker.dart';
import '../../data/models.dart';
import 'widgets/form_parts.dart';

const _craftOptions = [
  'Tejedora de Jipi Japa',
  'Sombrerero tradicional',
  'Bolsos y fibras',
  'Miniaturas y decoración',
];

const _techniqueOptions = [
  'Tejido fino',
  'Tejido abierto',
  'Remate a mano',
  'Tintes naturales',
  'Bloqueado en madera',
  'Miniatura',
];

const _paymentOptions = ['Efectivo', 'Transferencia', 'Tarjeta'];
const _languageOptions = ['Español', 'Maya', 'Inglés'];

/// Edición de la ficha pública del taller.
class ArtisanProfileEditScreen extends StatefulWidget {
  const ArtisanProfileEditScreen({super.key, required this.artisan});

  final Artisan artisan;

  @override
  State<ArtisanProfileEditScreen> createState() =>
      _ArtisanProfileEditScreenState();
}

class _ArtisanProfileEditScreenState extends State<ArtisanProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _name = TextEditingController(text: widget.artisan.name);
  late final _cave = TextEditingController(text: widget.artisan.cave);
  late final _bio = TextEditingController(text: widget.artisan.bio);
  late final _phone = TextEditingController(text: widget.artisan.phone ?? '');
  late final _whatsapp = TextEditingController(
    text: widget.artisan.whatsapp ?? '',
  );
  late final _email = TextEditingController(text: widget.artisan.email ?? '');
  late final _address = TextEditingController(
    text: widget.artisan.address ?? '',
  );

  late String? _imagePath = widget.artisan.imagePath;
  late String? _coverPath = widget.artisan.coverPath;
  late List<String> _craft = [
    if (widget.artisan.craft.isNotEmpty) widget.artisan.craft,
  ];
  late List<String> _techniques = [...widget.artisan.techniques];
  late int _years = widget.artisan.yearsOfCraft;
  late final List<int> _days = [...widget.artisan.openDays];
  late String _open = widget.artisan.openTime ?? '09:00';
  late String _close = widget.artisan.closeTime ?? '18:00';
  late List<String> _payments = [...widget.artisan.paymentMethods];
  late List<String> _languages = widget.artisan.languages.isEmpty
      ? ['Español']
      : [...widget.artisan.languages];
  late bool _published = widget.artisan.isPublished;
  late bool _sameWhatsapp =
      (widget.artisan.whatsapp ?? '') == (widget.artisan.phone ?? '');

  bool _dirty = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _name,
      _cave,
      _bio,
      _phone,
      _whatsapp,
      _email,
      _address,
    ]) {
      controller.addListener(_markDirty);
    }
    _bio.addListener(() => setState(() {}));
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _cave,
      _bio,
      _phone,
      _whatsapp,
      _email,
      _address,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime(bool opening) async {
    final current = opening ? _open : _close;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: int.tryParse(parts.last) ?? 0,
      ),
      helpText: opening ? 'Hora de apertura' : 'Hora de cierre',
    );
    if (picked == null) return;
    final text =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    _update(() => opening ? _open = text : _close = text);
  }

  void _bioHelp() {
    const template =
        'Somos una familia de tejedores de Bécal. Aprendí el oficio de __ '
        'cuando tenía __ años. En nuestra cueva tejemos __ y recibimos a '
        'visitantes para enseñarles cómo se trabaja la palma de jipi.';
    _bio.text = _bio.text.trim().isEmpty
        ? template
        : '${_bio.text.trim()}\n\n$template';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cambia los "__" por tu propia historia.')),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = 'Revisa los campos marcados en rojo.');
      return;
    }
    if (_days.isNotEmpty && _open.compareTo(_close) >= 0) {
      setState(() => _error = 'La hora de cierre debe ser después de abrir.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final phone = _phone.text.trim();
    final updated = widget.artisan.copyWith(
      name: _name.text.trim(),
      craft: _craft.isEmpty ? 'Artesanía de Bécal' : _craft.first,
      cave: _cave.text.trim(),
      bio: _bio.text.trim(),
      techniques: _techniques,
      yearsOfCraft: _years,
      imagePath: _imagePath,
      clearImage: _imagePath == null,
      coverPath: _coverPath,
      clearCover: _coverPath == null,
      phone: phone,
      whatsapp: _sameWhatsapp ? phone : _whatsapp.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      openDays: _days..sort(),
      openTime: _open,
      closeTime: _close,
      paymentMethods: _payments,
      languages: _languages,
      isPublished: _published,
    );

    final error = await context.app.updateArtisanProfile(updated);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil del taller actualizado.')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bioLength = _bio.text.trim().length;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context)) navigator.pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Perfil del taller', style: context.texts.titleLarge),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.sm,
              Insets.page,
              Insets.x3l,
            ),
            children: [
              FormSection(
                title: 'Fotos',
                subtitle:
                    'La portada es lo primero que ve el turista. Una foto '
                    'tuya tejiendo genera confianza.',
                icon: Icons.photo_camera_outlined,
                children: [
                  _CoverPicker(
                    path: _coverPath,
                    onChanged: (path) => _update(() => _coverPath = path),
                  ),
                  const SizedBox(height: Insets.lg),
                  Row(
                    children: [
                      AvatarEditor(
                        path: _imagePath,
                        size: 84,
                        onChanged: (path) => _update(() => _imagePath = path),
                      ),
                      const SizedBox(width: Insets.lg),
                      Expanded(
                        child: Text(
                          'Foto de perfil: tu cara o el logo del taller.',
                          style: context.texts.bodySmall?.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              FormSection(
                title: 'Tu taller',
                icon: Icons.storefront_outlined,
                children: [
                  BelTextField(
                    label: 'Nombre del taller o artesano',
                    hint: 'Ej. Cueva La Esperanza',
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => (value ?? '').trim().length < 3
                        ? 'Escribe el nombre del taller.'
                        : null,
                  ),
                  const SizedBox(height: Insets.md),
                  const FieldLabel('Oficio principal'),
                  ChipPicker(
                    options: _craftOptions,
                    selected: _craft,
                    multiple: false,
                    customLabel: 'Otro oficio…',
                    onChanged: (value) => _update(() => _craft = value),
                  ),
                  const SizedBox(height: Insets.lg),
                  BelTextField(
                    label: 'Cueva o lugar del taller',
                    hint: 'Ej. Cueva El Rosario',
                    controller: _cave,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: Insets.lg),
                  NumberStepper(
                    label: 'Años en el oficio',
                    value: _years,
                    min: 0,
                    max: 90,
                    onChanged: (value) => _update(() => _years = value),
                  ),
                ],
              ),

              FormSection(
                title: 'Tu historia',
                subtitle:
                    'Los turistas quieren conocer a quien hace las piezas. '
                    'Cuenta cómo aprendiste y qué hace especial tu trabajo.',
                icon: Icons.auto_stories_outlined,
                children: [
                  BelTextField(
                    label: 'Historia',
                    hint: 'Aprendí a tejer con mi abuela…',
                    controller: _bio,
                    maxLines: 8,
                    minLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    helper: bioLength < 80
                        ? 'Te faltan ${80 - bioLength} letras para una '
                              'historia completa.'
                        : '¡Muy bien! $bioLength letras.',
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _bioHelp,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('Ayúdame a escribirla'),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  const FieldLabel('Técnicas que dominas'),
                  ChipPicker(
                    options: _techniqueOptions,
                    selected: _techniques,
                    customLabel: 'Otra técnica…',
                    onChanged: (value) => _update(() => _techniques = value),
                  ),
                ],
              ),

              FormSection(
                title: 'Contacto',
                subtitle:
                    'Se muestra en tu ficha para que te escriban o llamen.',
                icon: Icons.call_outlined,
                children: [
                  BelTextField(
                    label: 'Teléfono',
                    hint: '981 123 4567',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                    validator: (value) {
                      final digits = (value ?? '').replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      if (digits.isNotEmpty && digits.length < 10) {
                        return 'El teléfono debe tener 10 dígitos.';
                      }
                      return null;
                    },
                  ),
                  SwitchRow(
                    title: 'Mi WhatsApp es el mismo número',
                    value: _sameWhatsapp,
                    onChanged: (value) => _update(() => _sameWhatsapp = value),
                  ),
                  if (!_sameWhatsapp) ...[
                    const SizedBox(height: Insets.sm),
                    BelTextField(
                      label: 'WhatsApp',
                      hint: '981 123 4567',
                      controller: _whatsapp,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.chat_outlined,
                    ),
                  ],
                  const SizedBox(height: Insets.md),
                  BelTextField(
                    label: 'Correo (opcional)',
                    hint: 'taller@correo.mx',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline_rounded,
                  ),
                  const SizedBox(height: Insets.md),
                  BelTextField(
                    label: 'Dirección o cómo llegar',
                    hint: 'Calle 20 x 15, a un lado de la iglesia',
                    controller: _address,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    prefixIcon: Icons.place_outlined,
                  ),
                ],
              ),

              FormSection(
                title: 'Horario de atención',
                subtitle: 'Toca los días que abres.',
                icon: Icons.schedule_rounded,
                children: [
                  Wrap(
                    spacing: Insets.xs,
                    runSpacing: Insets.xs,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(weekdayShort[day - 1]),
                          selected: _days.contains(day),
                          onSelected: (selected) => _update(
                            () => selected ? _days.add(day) : _days.remove(day),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeButton(
                          label: 'Abre',
                          value: _open,
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: _TimeButton(
                          label: 'Cierra',
                          value: _close,
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              FormSection(
                title: 'Pagos e idiomas',
                icon: Icons.payments_outlined,
                children: [
                  const FieldLabel('Formas de pago que aceptas'),
                  ChipPicker(
                    options: _paymentOptions,
                    selected: _payments,
                    customLabel: 'Otra…',
                    onChanged: (value) => _update(() => _payments = value),
                  ),
                  const SizedBox(height: Insets.lg),
                  const FieldLabel('Idiomas en los que atiendes'),
                  ChipPicker(
                    options: _languageOptions,
                    selected: _languages,
                    customLabel: 'Otro idioma…',
                    onChanged: (value) => _update(() => _languages = value),
                  ),
                ],
              ),

              FormSection(
                title: 'Visibilidad',
                icon: Icons.visibility_outlined,
                children: [
                  SwitchRow(
                    title: 'Mostrar mi taller a los turistas',
                    subtitle: _published
                        ? 'Tu ficha aparece en Artesanos y en el mapa.'
                        : 'Tu ficha está oculta (por ejemplo, de vacaciones).',
                    value: _published,
                    onChanged: (value) => _update(() => _published = value),
                  ),
                ],
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.md),
                  child: Text(
                    _error!,
                    style: context.texts.bodyMedium?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: FormSaveBar(
          label: _saving ? 'Guardando…' : 'Guardar perfil',
          onPressed: _saving ? null : _save,
        ),
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({required this.path, required this.onChanged});

  final String? path;
  final ValueChanged<String?> onChanged;

  Future<void> _change(BuildContext context) async {
    final picked = await pickSinglePhoto(
      context,
      allowRemove: path != null,
      onRemove: () => onChanged(null),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cambiar foto de portada',
      child: GestureDetector(
        onTap: () => _change(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                BelArtwork(
                  imagePath: path,
                  variant: ArtworkVariant.cave,
                  icon: path == null ? Icons.add_photo_alternate_outlined : null,
                ),
                Positioned(
                  right: Insets.sm,
                  bottom: Insets.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.xs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xAA000000),
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_camera_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          path == null ? 'Agregar portada' : 'Cambiar portada',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: palette.border, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: palette.textMuted),
            const SizedBox(width: Insets.sm),
            Text('$label ', style: context.texts.bodySmall),
            Text(value, style: context.texts.titleMedium),
          ],
        ),
      ),
    );
  }
}
