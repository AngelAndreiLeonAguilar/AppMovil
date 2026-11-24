import 'package:flutter/material.dart';

/// Logotipo de Bel·Aaktun (PNG con fondo transparente).
class BelLogo extends StatelessWidget {
  const BelLogo({super.key, this.size = 64});

  static const String asset = 'assets/brand/logo.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Logotipo de Bel·Aaktun',
    );
  }
}
