import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/bel_text_field.dart';
import '../../core/widgets/page_header.dart';
import '../../data/demo_content.dart';
import '../../data/models.dart';
import '../../domain/booking.dart';
import '../../domain/booking_rules.dart';

/// Reserva de una experiencia en las cuevas de Bécal.
///
/// Se usa como pantalla empujada ("Nueva reserva") desde Actividad.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, this.initialServiceId});

  /// Experiencia preseleccionada (cuando se reserva desde un taller).
  final String? initialServiceId;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  late final List<DateTime> _days = DemoContent.nextDays(14);
  late String _experienceId = widget.initialServiceId ?? '';
  late DateTime _date = _days[1];
  String _timeSlot = AppConfig.bookingTimeSlots.first;
  int _people = 2;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_experienceId.isEmpty) {
      final services = context.app.activeServices;
      if (services.isNotEmpty) _experienceId = services.first.id;
      // Rellena con los datos de la cuenta para no escribirlos cada vez.
      final user = context.app.user;
      if (user != null) {
        if (_nameController.text.isEmpty) _nameController.text = user.name;
        if (_phoneController.text.isEmpty && user.phone != null) {
          _phoneController.text = user.phone!;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Experiencias activas publicadas por los talleres.
  List<Experience> get _services => context.app.activeServices;

  bool _selectionReady = false;

  /// Lleva día, horario y personas a una combinación disponible.
  void _syncSelection() {
    if (_services.isEmpty) return;
    final app = context.app;
    final experience = _experience;
    if (app.slotsFor(experience, _date).isEmpty) {
      for (final day in _days) {
        if (app.slotsFor(experience, day).isNotEmpty) {
          _date = day;
          break;
        }
      }
    }
    final slots = app.slotsFor(experience, _date);
    final withRoom = [
      for (final slot in slots)
        if (app.spotsLeft(experience, _date, slot) > 0) slot,
    ];
    if (!withRoom.contains(_timeSlot)) {
      _timeSlot = withRoom.isNotEmpty
          ? withRoom.first
          : (slots.isNotEmpty ? slots.first : _timeSlot);
    }
    final max = _maxPeople;
    if (_people > max) _people = max < 1 ? 1 : max;
  }

  /// Máximo de personas: lugares libres del horario y tope por reserva.
  int get _maxPeople {
    final left = context.app.spotsLeft(_experience, _date, _timeSlot);
    return left < AppConfig.maxPeoplePerBooking
        ? left
        : AppConfig.maxPeoplePerBooking;
  }

  Experience get _experience {
    for (final service in _services) {
      if (service.id == _experienceId) return service;
    }
    return _services.first;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);

    final messenger = ScaffoldMessenger.of(context);
    final Booking booking;
    try {
      booking = await context.app.requestBooking(
        service: _experience,
        date: _date,
        timeSlot: _timeSlot,
        people: _people,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
    } on BookingRuleError catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _syncSelection();
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    if (!mounted) return;
    setState(() => _sending = false);
    await _showConfirmation(booking);
  }

  Future<void> _showConfirmation(Booking booking) {
    return showModalBottomSheet<void>(
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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sheetContext.colors.primary.withValues(
                        alpha: 0.12,
                      ),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: sheetContext.colors.primary,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      'Solicitud enviada',
                      style: sheetContext.texts.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              Text(
                '${booking.folio} · ${booking.serviceTitle}',
                style: sheetContext.texts.titleMedium,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                '${formatLongDate(booking.date)} · ${booking.timeSlot}\n'
                '${booking.people} ${booking.people == 1 ? 'persona' : 'personas'} · ${booking.touristName}',
                style: sheetContext.texts.bodyMedium,
              ),
              const SizedBox(height: Insets.md),
              Text(
                'Total ${formatPrice(booking.totalAmount)}'
                '${booking.hasDeposit ? ' · anticipo ${formatPrice(booking.depositAmount)}' : ''}',
                style: sheetContext.texts.titleSmall,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'El taller revisará tu solicitud y te avisaremos en la app. '
                'La app todavía no cobra en línea: el anticipo y el resto se '
                'pagan directo al taller.',
                style: sheetContext.texts.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: Insets.xl),
              BelButton(
                label: 'Ver mis visitas',
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).maybePop();
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
    final scheme = context.colors;
    final app = context.app;
    if (!_selectionReady && _services.isNotEmpty) {
      _selectionReady = true;
      _syncSelection();
    }
    final slots = _services.isEmpty
        ? const <String>[]
        : app.slotsFor(_experience, _date);
    final canSubmit =
        slots.contains(_timeSlot) &&
        _services.isNotEmpty &&
        app.spotsLeft(_experience, _date, _timeSlot) >= _people;

    if (_services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.x3l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_busy_outlined,
                size: 38,
                color: palette.textFaint,
              ),
              const SizedBox(height: Insets.md),
              Text(
                'No hay experiencias disponibles',
                style: context.texts.titleMedium,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Los talleres no tienen visitas publicadas en este momento.',
                textAlign: TextAlign.center,
                style: context.texts.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              eyebrow: 'Reserva tu visita',
              title: 'Reservas',
              subtitle:
                  'Elige experiencia, día y horario. El taller confirma tu '
                  'visita en la app.',
            ),
          ),

          // Experiencia
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepLabel(number: '01', label: 'Experiencia'),
                  const SizedBox(height: Insets.md),
                  for (final experience in _services) ...[
                    _ExperienceOption(
                      experience: experience,
                      selected: experience.id == _experienceId,
                      onTap: () => setState(() {
                        _experienceId = experience.id;
                        _syncSelection();
                      }),
                    ),
                    const SizedBox(height: Insets.sm),
                  ],
                  _ExperienceDetails(experience: _experience),
                ],
              ),
            ),
          ),

          // Fecha
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.xl,
                Insets.page,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepLabel(number: '02', label: 'Fecha'),
                  const SizedBox(height: Insets.md),
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: _days.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: Insets.sm),
                      itemBuilder: (context, index) {
                        final day = _days[index];
                        final selected = _isSameDay(day, _date);
                        final open = app.isWorkshopOpenOn(_experience, day);
                        final available = app
                            .slotsFor(_experience, day)
                            .isNotEmpty;
                        return _DayChip(
                          day: day,
                          selected: selected,
                          enabled: available,
                          note: available
                              ? null
                              : (open ? 'Sin horario' : 'Cerrado'),
                          onTap: () => setState(() {
                            _date = day;
                            _syncSelection();
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Horario
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.xl,
                Insets.page,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepLabel(number: '03', label: 'Horario'),
                  const SizedBox(height: Insets.md),
                  if (slots.isEmpty)
                    Text(
                      'No hay horarios disponibles este día. Elige otra fecha.',
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    )
                  else
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      children: [
                        for (final slot in slots)
                          Builder(
                            builder: (context) {
                              final left = app.spotsLeft(
                                _experience,
                                _date,
                                slot,
                              );
                              final full = left <= 0;
                              return Opacity(
                                opacity: full ? 0.45 : 1,
                                child: BelFilterChip(
                                  label: full
                                      ? '$slot · Lleno'
                                      : '$slot · $left '
                                            '${left == 1 ? 'lugar' : 'lugares'}',
                                  selected: slot == _timeSlot && !full,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Insets.md,
                                    vertical: Insets.sm + 2,
                                  ),
                                  onTap: full
                                      ? () {}
                                      : () => setState(() {
                                          _timeSlot = slot;
                                          _syncSelection();
                                        }),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Personas
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.xl,
                Insets.page,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepLabel(number: '04', label: 'Personas'),
                  const SizedBox(height: Insets.md),
                  BelSurface(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Visitantes',
                            style: context.texts.titleMedium,
                          ),
                        ),
                        _StepperButton(
                          icon: Icons.remove_rounded,
                          enabled: _people > 1,
                          onTap: () => setState(() => _people--),
                        ),
                        SizedBox(
                          width: 48,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Text(
                              '$_people',
                              key: ValueKey(_people),
                              textAlign: TextAlign.center,
                              style: context.texts.titleLarge?.copyWith(
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        _StepperButton(
                          icon: Icons.add_rounded,
                          enabled: _people < _maxPeople,
                          onTap: () => setState(() => _people++),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Datos
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.xl,
                Insets.page,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepLabel(number: '05', label: 'Tus datos'),
                  const SizedBox(height: Insets.md),
                  BelTextField(
                    label: 'Nombre completo',
                    hint: 'Como quieres que te llamemos',
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return 'Escribe tu nombre completo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Insets.lg),
                  BelTextField(
                    label: 'Teléfono / WhatsApp',
                    hint: '10 dígitos',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: (value) {
                      final digits = (value ?? '').replaceAll(
                        RegExp(r'\D'),
                        '',
                      );
                      if (digits.length < 10) {
                        return 'Escribe un teléfono de 10 dígitos';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Insets.lg),
                  BelTextField(
                    label: 'Notas (opcional)',
                    hint: 'Idioma, movilidad, número de niños…',
                    controller: _notesController,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                ],
              ),
            ),
          ),

          // Resumen
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.xl,
                Insets.page,
                0,
              ),
              child: Container(
                padding: const EdgeInsets.all(Insets.lg),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TU RESERVA',
                      style: context.texts.labelSmall?.copyWith(
                        color: scheme.primary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(_experience.title, style: context.texts.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${formatLongDate(_date)} · $_timeSlot\n'
                      '$_people ${_people == 1 ? 'persona' : 'personas'} · '
                      '${formatDuration(_experience.durationMinutes)}',
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      'Total ${formatPrice(_experience.totalFor(_people))}'
                      '${_experience.depositPercent > 0 ? ' · anticipo ${formatPrice(_experience.depositFor(_people))} (${_experience.depositPercent} %)' : ' · sin anticipo'}',
                      style: context.texts.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontSize: 13,
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
                Insets.xl,
                Insets.page,
                0,
              ),
              child: BelButton(
                label: _sending ? 'Enviando…' : 'Solicitar reserva',
                icon: Icons.send_rounded,
                onPressed: _sending || !canSubmit ? null : _submit,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.md,
                Insets.page,
                132,
              ),
              child: Text(
                'La app todavía no cobra en línea: el anticipo se acuerda y se '
                'paga directo al taller. Sigue tu solicitud en Actividad → '
                'Visitas.',
                textAlign: TextAlign.center,
                style: context.texts.bodySmall?.copyWith(
                  color: palette.textFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          number,
          style: context.texts.labelSmall?.copyWith(
            color: context.colors.secondary,
            letterSpacing: 1.2,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: Insets.sm),
        Text(
          label.toUpperCase(),
          style: context.texts.labelSmall?.copyWith(
            color: context.palette.textMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(child: Container(height: 1, color: context.palette.border)),
      ],
    );
  }
}

class _ExperienceOption extends StatelessWidget {
  const _ExperienceOption({
    required this.experience,
    required this.selected,
    required this.onTap,
  });

  final Experience experience;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final palette = context.palette;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: selected ? scheme.primary : palette.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: BelArtwork(
                    imagePath: experience.coverImage,
                    variant: ArtworkVariant.weave,
                    seed: experience.id.hashCode,
                    label: experience.title,
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(experience.title, style: context.texts.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      formatDuration(experience.durationMinutes),
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.primary : palette.border,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.note,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  /// "Cerrado" o "Sin horario" cuando no se puede reservar.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final palette = context.palette;

    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 64,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : palette.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? scheme.primary : palette.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayShort(day),
                    style: context.texts.labelSmall?.copyWith(
                      fontSize: 8.5,
                      letterSpacing: 1,
                      color: selected
                          ? scheme.onPrimary.withValues(alpha: 0.8)
                          : palette.textFaint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: context.texts.headlineSmall?.copyWith(
                      fontSize: 22,
                      color: selected ? scheme.onPrimary : palette.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note ?? monthLong(day).substring(0, 3),
                    style: context.texts.bodySmall?.copyWith(
                      fontSize: 10,
                      color: selected
                          ? scheme.onPrimary.withValues(alpha: 0.8)
                          : palette.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? context.colors.primary.withValues(alpha: 0.10)
          : context.palette.surfaceMuted,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? context.colors.primary : context.palette.textFaint,
          ),
        ),
      ),
    );
  }
}

/// Lo que incluye la experiencia elegida, para decidir antes de reservar.
class _ExperienceDetails extends StatelessWidget {
  const _ExperienceDetails({required this.experience});

  final Experience experience;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final artisan = context.app.artisanById(experience.artisanId);
    final lines = <(IconData, String)>[
      if (artisan != null) (Icons.storefront_outlined, artisan.name),
      (
        Icons.payments_outlined,
        '${formatPrice(experience.pricePerPerson)} por persona · '
            '${formatDuration(experience.durationMinutes)} · hasta '
            '${experience.maxParticipants} personas',
      ),
      if (experience.includes.isNotEmpty)
        (
          Icons.check_circle_outline_rounded,
          'Incluye: ${experience.includes.join(', ')}',
        ),
      if (experience.languages.isNotEmpty)
        (Icons.translate_rounded, experience.languages.join(', ')),
      if ((experience.whatToBring ?? '').isNotEmpty)
        (Icons.backpack_outlined, 'Trae: ${experience.whatToBring}'),
      if ((experience.meetingPoint ?? '').isNotEmpty)
        (
          Icons.place_outlined,
          'Punto de encuentro: ${experience.meetingPoint}',
        ),
    ];
    return Container(
      margin: const EdgeInsets.only(top: Insets.xs),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (experience.description.isNotEmpty) ...[
            Text(experience.description, style: context.texts.bodySmall),
            const SizedBox(height: Insets.sm),
          ],
          for (final (icon, text) in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: palette.textMuted),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      text,
                      style: context.texts.bodySmall?.copyWith(fontSize: 12.5),
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
