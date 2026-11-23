import 'package:flutter/material.dart';

import '../../../core/state/app_controller.dart';
import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bel_surface.dart';
import '../profile_edit_screen.dart';
import 'product_form_sheet.dart';
import 'service_form_sheet.dart';

/// "Completa tu taller": guía paso a paso con acceso directo a cada tarea.
class ProfileProgressCard extends StatelessWidget {
  const ProfileProgressCard({super.key, this.hideWhenComplete = true});

  final bool hideWhenComplete;

  Future<void> _open(BuildContext context, ProfileTask task) async {
    final artisan = context.app.artisan;
    switch (task.kind) {
      case ProfileTaskKind.product:
        await showProductForm(context);
      case ProfileTaskKind.service:
        await showServiceForm(context);
      case ProfileTaskKind.photo:
      case ProfileTaskKind.cover:
      case ProfileTaskKind.story:
      case ProfileTaskKind.contact:
      case ProfileTaskKind.schedule:
        if (artisan == null) return;
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => ArtisanProfileEditScreen(artisan: artisan),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.app.profileTasks;
    if (tasks.isEmpty) return const SizedBox.shrink();
    final done = tasks.where((task) => task.done).length;
    if (hideWhenComplete && done == tasks.length) {
      return const SizedBox.shrink();
    }
    final palette = context.palette;
    final progress = done / tasks.length;
    final pending = tasks.where((task) => !task.done).toList();

    return BelSurface(
      padding: const EdgeInsets.all(Insets.lg),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                done == tasks.length
                    ? Icons.verified_rounded
                    : Icons.checklist_rounded,
                color: context.colors.primary,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  done == tasks.length
                      ? '¡Tu taller está completo!'
                      : 'Completa tu taller',
                  style: context.texts.titleMedium,
                ),
              ),
              Text(
                '$done de ${tasks.length}',
                style: context.texts.labelMedium?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: palette.surfaceMuted,
              color: context.colors.primary,
            ),
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'Los talleres completos reciben más reservas. Toca un paso:',
              style: context.texts.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: Insets.xs),
            for (final task in pending.take(3))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.radio_button_unchecked_rounded,
                  color: context.colors.primary,
                  size: 20,
                ),
                title: Text(task.label, style: context.texts.bodyMedium),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(context, task),
              ),
          ],
        ],
      ),
    );
  }
}
