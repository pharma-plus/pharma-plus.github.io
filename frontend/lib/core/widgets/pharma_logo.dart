import 'package:flutter/material.dart';

class PharmaPlusLogo extends StatelessWidget {
  final double size;
  final bool full;

  const PharmaPlusLogo({super.key, this.size = 64, this.full = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      full ? 'assets/logo/pharma_plus_logo.svg.png' : 'assets/logo/pharma_plus_mark.svg.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
