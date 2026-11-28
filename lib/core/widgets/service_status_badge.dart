import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import 'bel_tag.dart';

/// Verde para «activo», ámbar oscuro para «fuera de servicio».
const Color serviceActiveColor = Color(0xFF3F7A39);
const Color serviceInactiveColor = AppColors.terracotaOscuro;

/// Etiqueta con el estado del taller según su mensualidad.
class ServiceStatusBadge extends StatelessWidget {
  const ServiceStatusBadge({super.key, required this.artisanId});

  final String artisanId;

  @override
  Widget build(BuildContext context) {
    final active = context.app.isArtisanInService(artisanId);
    return BelPill(
      label: active ? 'Activo' : 'Fuera de servicio',
      icon: active ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
      color: active ? serviceActiveColor : serviceInactiveColor,
    );
  }
}

/// Aviso grande para la ficha de un taller fuera de servicio.
class OutOfServiceNotice extends StatelessWidget {
  const OutOfServiceNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: serviceInactiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: serviceInactiveColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.pause_circle_rounded, color: serviceInactiveColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
