import 'package:flutter/material.dart';

import '../app.dart';

/// Capa / ícone da rádio com cantos arredondados e um ícone padrão se a imagem falhar.
class StationArt extends StatelessWidget {
  const StationArt({super.key, this.url, this.size = 52, this.radius = 12});

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.surfaceHigh,
      child: Icon(Icons.radio_rounded, color: AppColors.accent, size: size * 0.5),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
            ),
    );
  }
}
