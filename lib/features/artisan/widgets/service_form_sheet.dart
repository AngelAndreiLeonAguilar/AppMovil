import 'package:flutter/material.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/bel_artwork.dart';
import '../../../core/widgets/bel_text_field.dart';
import '../../../core/widgets/photo_picker.dart';
import '../../../data/models.dart';
import 'form_parts.dart';

/// Abre el formulario de experiencia. Devuelve `true` si se guardó.
Future<bool> showServiceForm(BuildContext context, {Experience? service}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ServiceFormScreen(service: service),
    ),
  );
  return saved ?? false;
}

class _Template {
  const _Template({
    required this.label,
    required this.title,
    required this.description,
    required this.minutes,
    required this.price,
    required this.includes,
    required this.capacity,
  });

  final String label;
  final String title;
  final String description;
  final int minutes;
  final int price;
  final List<String> includes;
  final int capacity;
}

const _templates = [
  _Template(
    label: 'Recorrido por la cueva',
    title: 'Recorrido por mi cueva de tejido',
    description:
        'Conoce la cueva donde tejemos el sombrero de jipi: por qué la palma '
        'necesita humedad, cómo se prepara la fibra y cómo se teje paso a '
        'paso.',
    minutes: 60,
    price: 150,
    includes: ['Guía', 'Agua fresca'],
    capacity: 10,
  ),
  _Template(
    label: 'Taller de tejido',
    title: 'Aprende a tejer palma',
    description:
        'Taller práctico: te enseñamos a preparar y tejer la palma de jipi. '
        'Te llevas la pieza que hagas.',
    minutes: 120,
    price: 400,
    includes: ['Material', 'Pieza para llevar', 'Agua fresca'],
    capacity: 6,
  ),
  _Template(
    label: 'Demostración',
    title: 'Demostración de tejido',
    description:
        'Mira de cerca cómo se teje un sombrero fino y platica con la '
        'familia artesana sobre la historia del oficio.',
    minutes: 45,
    price: 100,
    includes: ['Guía'],
    capacity: 15,
  ),
];

const _includeOptions = [
  'Guía',
  'Material',
  'Pieza para llevar',
  'Agua fresca',
  'Degustación',
  'Fotografías',
];

const _languageOptions = ['Español', 'Maya', 'Inglés'];

const _durationOptions = [30, 45, 60, 90, 120, 180];

class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({super.key, this.service});

  final Experience? service;

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title = TextEditingController(
    text: widget.service?.title ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.service?.description ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.service?.pricePerPerson.toString() ?? '',
  );
  late final TextEditingController _bring = TextEditingController(
    text: widget.service?.whatToBring ?? '',
  );
  late final TextEditingController _meeting = TextEditingController(
    text: widget.service?.meetingPoint ?? '',
  );

  late List<String> _photos = [...?widget.service?.photos];
  late int _duration = widget.service?.durationMinutes ?? 60;
  late int _deposit = widget.service?.depositPercent ?? 30;
  late int _capacity = widget.service?.maxParticipants ?? 10;
  late bool _isActive = widget.service?.isActive ?? true;
  late List<String> _includes = [...?widget.service?.includes];
  late List<String> _languages = widget.service == null
      ? ['Español']
      : [...widget.service!.languages];

  bool _dirty = false;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.service == null;

  @override
  void initState() {
    super.initState();
    for (final controller in [_title, _description, _price, _bring, _meeting]) {
      controller.addListener(_markDirty);
    }
    _price.addListener(() => setState(() {}));
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
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _bring.dispose();
    _meeting.dispose();
    super.dispose();
  }

  void _apply(_Template template) {
    _update(() {
      _title.text = template.title;
      _description.text = template.description;
      _price.text = template.price.toString();
      _duration = template.minutes;
      _includes = [...template.includes];
      _capacity = template.capacity;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plantilla aplicada. Ajusta el precio y los detalles.'),
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = 'Revisa los campos marcados en rojo.');
      return;
    }
    final price = int.tryParse(
      _price.text.trim().replaceAll(RegExp(r'[,\s$]'), ''),
    );
    if (price == null) {
      setState(() => _error = 'El precio debe ser un número sin centavos.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await context.app.upsertService(
      id: widget.service?.id,
      title: _title.text,
      description: _description.text,
      durationMinutes: _duration,
      pricePerPerson: price,
      depositPercent: _deposit,
      maxParticipants: _capacity,
      isActive: _isActive,
      photos: _photos,
      includes: _includes,
      whatToBring: _bring.text,
      languages: _languages,
      meetingPoint: _meeting.text,
    );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isNew
              ? 'Experiencia publicada: ya se puede reservar.'
              : 'Cambios guardados.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar experiencia'),
        content: Text(
          '"${widget.service!.title}" se borrará del catálogo. Las '
          'reservaciones que ya existen no se modifican.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: dialogContext.colors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final error = await context.app.deleteService(widget.service!.id);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final price = int.tryParse(_price.text.trim()) ?? 0;
    final exampleTotal = price * 2;
    final exampleDeposit = (exampleTotal * _deposit / 100).round();

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context)) navigator.pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isNew ? 'Nueva experiencia' : 'Editar experiencia',
            style: context.texts.titleLarge,
          ),
          actions: [
            if (!_isNew)
              IconButton(
                tooltip: 'Eliminar',
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
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
              if (_isNew)
                FormSection(
                  title: 'Empieza rápido',
                  subtitle:
                      'Elige una plantilla y solo ajusta lo que cambie en tu '
                      'taller.',
                  icon: Icons.bolt_rounded,
                  children: [
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      children: [
                        for (final template in _templates)
                          ActionChip(
                            avatar: const Icon(Icons.add_rounded, size: 18),
                            label: Text(template.label),
                            onPressed: () => _apply(template),
                          ),
                      ],
                    ),
                  ],
                ),

              FormSection(
                title: 'Fotos',
                subtitle: 'Muestra el lugar, a las personas tejiendo y lo '
                    'que se llevan los visitantes.',
                icon: Icons.photo_camera_outlined,
                children: [
                  PhotoGalleryEditor(
                    photos: _photos,
                    onChanged: (photos) => _update(() => _photos = photos),
                    variant: ArtworkVariant.cave,
                  ),
                ],
              ),

              FormSection(
                title: 'De qué se trata',
                icon: Icons.edit_note_rounded,
                children: [
                  BelTextField(
                    label: 'Nombre',
                    hint: 'Ej. Recorrido por las cuevas',
                    controller: _title,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    validator: (value) => (value ?? '').trim().length < 3
                        ? 'Escribe un nombre para la experiencia.'
                        : null,
                  ),
                  const SizedBox(height: Insets.md),
                  BelTextField(
                    label: 'Descripción',
                    hint: 'Qué van a ver, hacer y aprender',
                    controller: _description,
                    maxLines: 6,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: Insets.lg),
                  const FieldLabel('Duración'),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: [
                      for (final minutes in {..._durationOptions, _duration})
                        ChoiceChip(
                          label: Text(formatDuration(minutes)),
                          selected: _duration == minutes,
                          onSelected: (_) =>
                              _update(() => _duration = minutes),
                        ),
                    ],
                  ),
                ],
              ),

              FormSection(
                title: 'Precio y cupo',
                icon: Icons.payments_outlined,
                children: [
                  BelTextField(
                    label: 'Precio por persona',
                    hint: '0',
                    prefixText: r'$ ',
                    suffixText: 'MXN',
                    controller: _price,
                    keyboardType: TextInputType.number,
                    helper: 'Pon 0 si la visita es gratuita.',
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Escribe el precio (o 0 si es gratis).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Insets.lg),
                  NumberStepper(
                    label: 'Máximo de personas por visita',
                    value: _capacity,
                    min: 1,
                    max: 60,
                    onChanged: (value) => _update(() => _capacity = value),
                  ),
                  const SizedBox(height: Insets.lg),
                  FieldLabel('Anticipo: $_deposit %'),
                  Slider(
                    value: _deposit.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '$_deposit %',
                    onChanged: (value) =>
                        _update(() => _deposit = value.round()),
                  ),
                  Container(
                    padding: const EdgeInsets.all(Insets.md),
                    decoration: BoxDecoration(
                      color: palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text(
                      price <= 0
                          ? 'Visita gratuita: no se pide anticipo.'
                          : _deposit == 0
                          ? 'Sin anticipo: el turista paga todo al llegar.'
                          : 'Ejemplo para 2 personas: total '
                                '${formatPrice(exampleTotal)}, anticipo '
                                '${formatPrice(exampleDeposit)} y '
                                '${formatPrice(exampleTotal - exampleDeposit)} '
                                'al llegar.',
                      style: context.texts.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),

              FormSection(
                title: 'Detalles para el visitante',
                icon: Icons.checklist_rounded,
                children: [
                  const FieldLabel('¿Qué incluye?'),
                  ChipPicker(
                    options: _includeOptions,
                    selected: _includes,
                    customLabel: 'Otra cosa…',
                    onChanged: (value) => _update(() => _includes = value),
                  ),
                  const SizedBox(height: Insets.lg),
                  const FieldLabel('Idiomas'),
                  ChipPicker(
                    options: _languageOptions,
                    selected: _languages,
                    customLabel: 'Otro idioma…',
                    onChanged: (value) => _update(() => _languages = value),
                  ),
                  const SizedBox(height: Insets.lg),
                  BelTextField(
                    label: 'Qué traer (opcional)',
                    hint: 'Ej. Ropa cómoda y gorra',
                    controller: _bring,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: Insets.md),
                  BelTextField(
                    label: 'Punto de encuentro (opcional)',
                    hint: 'Si es distinto a tu taller',
                    controller: _meeting,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),

              FormSection(
                title: 'Publicación',
                icon: Icons.visibility_outlined,
                children: [
                  SwitchRow(
                    title: 'Disponible para reservar',
                    subtitle: _isActive
                        ? 'Aparece en la app del turista.'
                        : 'Queda guardada pero oculta.',
                    value: _isActive,
                    onChanged: (value) => _update(() => _isActive = value),
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
          label: _saving
              ? 'Guardando…'
              : (_isNew ? 'Publicar experiencia' : 'Guardar cambios'),
          onPressed: _saving ? null : _save,
        ),
      ),
    );
  }
}
