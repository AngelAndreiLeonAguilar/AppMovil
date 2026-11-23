import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'booking_screen.dart';

/// Pantalla empujada con el formulario de reserva.
class BookingFlowScreen extends StatelessWidget {
  const BookingFlowScreen({super.key, this.initialServiceId});

  final String? initialServiceId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nueva reserva', style: context.texts.titleLarge),
        centerTitle: false,
      ),
      body: BookingScreen(initialServiceId: initialServiceId),
    );
  }
}
