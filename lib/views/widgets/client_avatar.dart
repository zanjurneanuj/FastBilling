import 'package:flutter/material.dart';

/// Deterministic pastel initials avatar for a client/contact name.
/// Same name always gets the same color, no ID needed to key off of.
class ClientAvatar extends StatelessWidget {
  const ClientAvatar({super.key, required this.name, this.size = 42});

  final String name;
  final double size;

  static const _palettes = [
    (bg: Color(0xFFE8E4FF), fg: Color(0xFF6C5CE7)), // purple
    (bg: Color(0xFFE0F4FF), fg: Color(0xFF0984E3)), // blue
    (bg: Color(0xFFFFE8E8), fg: Color(0xFFE17055)), // red
    (bg: Color(0xFFE8FFE8), fg: Color(0xFF00B894)), // green
    (bg: Color(0xFFFFF3E0), fg: Color(0xFFF39C12)), // amber
    (bg: Color(0xFFFFE4F3), fg: Color(0xFFE84393)), // pink
  ];

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  ({Color bg, Color fg}) get _color {
    final idx = name.codeUnits.fold(0, (a, b) => a + b) % _palettes.length;
    return _palettes[idx];
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      width: size,
      height: size,
      decoration:
      BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Center(
        child: Text(_initials,
            style: TextStyle(
                color: c.fg,
                fontSize: size * 0.33,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
