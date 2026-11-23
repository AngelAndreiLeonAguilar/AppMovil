import 'package:flutter/material.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bel_artwork.dart';
import '../../../core/widgets/bel_tag.dart';
import '../../../core/widgets/bel_text_field.dart';
import '../../../core/widgets/photo_picker.dart';
import '../../../data/demo_content.dart';
import '../../../data/models.dart';
import 'form_parts.dart';

/// Abre el formulario de pieza. Devuelve `true` si se guardó.
Future<bool> showProductForm(BuildContext context, {Product? product}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProductFormScreen(product: product),
    ),
  );
  return saved ?? false;
}

const _materialOptions = [
  'Palma de jipi',
  'Tinte natural',
  'Hilo de algodón',
  'Henequén',
  'Manta',
  'Madera',
];

const _techniqueOptions = [
  'Tejido fino',
  'Tejido abierto',
  'Remate a mano',
  'Tinte natural',
  'Bloqueado en madera',
  'Miniatura',
];

/// Plantillas de descripción para quien no sabe por dónde empezar.
String _descriptionTemplate(String category) => switch (category) {
  'Sombreros' =>
    'Sombrero tejido a mano con palma de jipi en las cuevas de Bécal. '
        'Ala de __ cm y copa __. Fresco, ligero y se puede enrollar sin '
        'perder la forma. Talla __.',
  'Bolsos' =>
    'Bolso tejido a mano con palma de jipi. Mide __ x __ cm, con asa de '
        '__ y forro de __. Ideal para el día a día.',
  'Decoración' =>
    'Pieza decorativa tejida a mano en Bécal. Mide __ cm. Aprovecha la '
        'palma de jipi para dar luz y textura a cualquier espacio.',
  'Miniaturas' =>
    'Miniatura tejida a mano con fibras finas de palma de jipi. Mide __ '
        'cm. Un recuerdo pequeño hecho con mucha paciencia.',
  _ =>
    'Pieza hecha a mano en Bécal, Campeche. Material: __. Medidas: __. '
        'Cuidados: guardar en lugar seco.',
};

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name = TextEditingController(
    text: widget.product?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late final TextEditingController _technique = TextEditingController(
    text: widget.product?.technique ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.product?.price?.toString() ?? '',
  );
  late final TextEditingController _dimensions = TextEditingController(
    text: widget.product?.dimensions ?? '',
  );

  late List<String> _photos = [...?widget.product?.photos];
  late String _category =
      widget.product?.category ?? DemoContent.categories[1];
  late bool _madeToOrder = widget.product?.madeToOrder ?? false;
  late bool _isActive = widget.product?.isActive ?? true;
  late bool _askPrice =
      widget.product != null && widget.product!.price == null;
  late bool _trackStock = widget.product?.stock != null;
  late int _stock = widget.product?.stock ?? 1;
  late int _productionDays = widget.product?.productionDays ?? 7;
  late List<String> _materials = [...?widget.product?.materials];

  bool _dirty = false;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.product == null;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _name,
      _description,
      _technique,
      _price,
      _dimensions,
    ]) {
      controller.addListener(_markDirty);
    }
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
    _name.dispose();
    _description.dispose();
    _technique.dispose();
    _price.dispose();
    _dimensions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = 'Revisa los campos marcados en rojo.');
      return;
    }

    final priceText = _price.text.trim().replaceAll(RegExp(r'[,\s$]'), '');
    final price = _askPrice || priceText.isEmpty ? null : int.tryParse(priceText);
    if (!_askPrice && priceText.isNotEmpty && price == null) {
      setState(() => _error = 'El precio debe ser un número sin centavos.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await context.app.upsertProduct(
      id: widget.product?.id,
      name: _name.text,
      category: _category,
      description: _description.text,
      technique: _technique.text,
      price: price,
      madeToOrder: _madeToOrder,
      isActive: _isActive,
      photos: _photos,
      stock: !_madeToOrder && _trackStock ? _stock : null,
      productionDays: _madeToOrder ? _productionDays : null,
      dimensions: _dimensions.text,
      materials: _materials,
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
          _isNew ? 'Pieza publicada en tu catálogo.' : 'Cambios guardados.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar pieza'),
        content: Text(
          '"${widget.product!.name}" se borrará del catálogo junto con sus '
          'fotos. Si solo quieres ocultarla, apaga "Visible en el catálogo".',
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
    final error = await context.app.deleteProduct(widget.product!.id);
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

  Future<void> _duplicate() async {
    final error = await context.app.duplicateProduct(widget.product!.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'Se creó una copia oculta. Agrégale fotos y actívala cuando '
                  'esté lista.',
        ),
      ),
    );
    if (error == null) Navigator.of(context).pop(true);
  }

  void _useTemplate() {
    final template = _descriptionTemplate(_category);
    if (_description.text.trim().isEmpty) {
      _description.text = template;
    } else {
      _description.text = '${_description.text.trim()}\n\n$template';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cambia los "__" por los datos de tu pieza.'),
      ),
    );
  }

  void _addTechnique(String value) {
    final current = _technique.text.trim();
    if (current.toLowerCase().contains(value.toLowerCase())) return;
    _technique.text = current.isEmpty ? value : '$current · $value';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final categories = [
      for (final category in DemoContent.categories)
        if (category != DemoContent.categories.first) category,
    ];

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
            _isNew ? 'Nueva pieza' : 'Editar pieza',
            style: context.texts.titleLarge,
          ),
          actions: [
            if (!_isNew)
              PopupMenuButton<String>(
                tooltip: 'Más opciones',
                onSelected: (value) {
                  if (value == 'duplicate') _duplicate();
                  if (value == 'delete') _delete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicar pieza'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
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
              FormSection(
                title: 'Fotos de la pieza',
                subtitle:
                    'Las piezas con buenas fotos reciben muchas más visitas. '
                    'Sube varias: de frente, de lado y un detalle del tejido.',
                icon: Icons.photo_camera_outlined,
                children: [
                  PhotoGalleryEditor(
                    photos: _photos,
                    onChanged: (photos) => _update(() => _photos = photos),
                    variant: ArtworkVariant.craft,
                  ),
                ],
              ),

              FormSection(
                title: 'Lo básico',
                icon: Icons.edit_note_rounded,
                children: [
                  BelTextField(
                    label: 'Nombre de la pieza',
                    hint: 'Ej. Sombrero Brisa de Bécal',
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 60,
                    validator: (value) => (value ?? '').trim().length < 2
                        ? 'Escribe un nombre para la pieza.'
                        : null,
                  ),
                  const SizedBox(height: Insets.md),
                  const FieldLabel('Categoría'),
                  ChipPicker(
                    options: categories,
                    selected: [_category],
                    multiple: false,
                    customLabel: 'Otra categoría…',
                    customHint: 'Ej. Abanicos',
                    onChanged: (value) =>
                        _update(() => _category = value.first),
                  ),
                ],
              ),

              FormSection(
                title: 'Precio y disponibilidad',
                icon: Icons.sell_outlined,
                children: [
                  SwitchRow(
                    title: 'Precio a consultar',
                    subtitle: 'El turista te pregunta antes de comprar.',
                    value: _askPrice,
                    onChanged: (value) => _update(() => _askPrice = value),
                  ),
                  if (!_askPrice) ...[
                    const SizedBox(height: Insets.sm),
                    BelTextField(
                      label: 'Precio',
                      hint: '0',
                      prefixText: r'$ ',
                      suffixText: 'MXN',
                      controller: _price,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (_askPrice) return null;
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return 'Escribe el precio o activa "Precio a '
                              'consultar".';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: Insets.lg),
                  const FieldLabel('¿Cómo se vende?'),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Lista para entregar'),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Por encargo'),
                        icon: Icon(Icons.timer_outlined),
                      ),
                    ],
                    selected: {_madeToOrder},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        _update(() => _madeToOrder = value.first),
                  ),
                  const SizedBox(height: Insets.md),
                  if (_madeToOrder)
                    NumberStepper(
                      label: 'Días para tenerla lista',
                      value: _productionDays,
                      min: 1,
                      max: 120,
                      unit: _productionDays == 1 ? 'día' : 'días',
                      onChanged: (value) =>
                          _update(() => _productionDays = value),
                    )
                  else ...[
                    SwitchRow(
                      title: 'Llevar conteo de piezas',
                      subtitle: 'Avisa "Agotada" cuando llegue a cero.',
                      value: _trackStock,
                      onChanged: (value) => _update(() => _trackStock = value),
                    ),
                    if (_trackStock)
                      NumberStepper(
                        label: 'Piezas disponibles',
                        value: _stock,
                        min: 0,
                        max: 999,
                        onChanged: (value) => _update(() => _stock = value),
                      ),
                  ],
                ],
              ),

              FormSection(
                title: 'Descripción',
                subtitle:
                    'Cuenta cómo está hecha, medidas y cuidados. Si no sabes '
                    'qué poner, usa la plantilla.',
                icon: Icons.notes_rounded,
                children: [
                  BelTextField(
                    label: 'Descripción',
                    hint: 'Materiales, medidas, cuidados y su historia',
                    controller: _description,
                    maxLines: 6,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _useTemplate,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('Ayúdame a escribirla'),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  BelTextField(
                    label: 'Medidas o talla (opcional)',
                    hint: 'Ej. Talla 57 · ala 9 cm',
                    controller: _dimensions,
                  ),
                ],
              ),

              FormSection(
                title: 'Técnica y materiales',
                icon: Icons.grass_rounded,
                children: [
                  BelTextField(
                    label: 'Técnica',
                    hint: 'Ej. Tejido fino · 18 vueltas',
                    controller: _technique,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    'Toca para agregar:',
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textFaint,
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Wrap(
                    spacing: Insets.xs,
                    runSpacing: Insets.xs,
                    children: [
                      for (final option in _techniqueOptions)
                        ActionChip(
                          label: Text(option),
                          onPressed: () => _addTechnique(option),
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  const FieldLabel('Materiales'),
                  ChipPicker(
                    options: _materialOptions,
                    selected: _materials,
                    customLabel: 'Otro material…',
                    onChanged: (value) => _update(() => _materials = value),
                  ),
                ],
              ),

              FormSection(
                title: 'Publicación',
                icon: Icons.visibility_outlined,
                children: [
                  SwitchRow(
                    title: 'Visible en el catálogo',
                    subtitle: _isActive
                        ? 'Los turistas pueden verla.'
                        : 'Queda guardada pero oculta.',
                    value: _isActive,
                    onChanged: (value) => _update(() => _isActive = value),
                  ),
                  if (_photos.isEmpty) ...[
                    const SizedBox(height: Insets.sm),
                    const BelPill(
                      label: 'Consejo: agrega al menos una foto',
                      icon: Icons.lightbulb_outline_rounded,
                    ),
                  ],
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
              : (_isNew ? 'Publicar pieza' : 'Guardar cambios'),
          onPressed: _saving ? null : _save,
        ),
      ),
    );
  }
}
